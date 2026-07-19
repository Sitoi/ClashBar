import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createMDX } from 'fumadocs-mdx/next';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const mdxBridge = path.join(__dirname, 'loaders/fumadocs-mdx-mdx.cjs');
const metaBridge = path.join(__dirname, 'loaders/fumadocs-mdx-meta.cjs');

const withMDX = createMDX();

/** LAN / phone preview hosts for Next.js dev HMR (comma-separated override). */
const allowedDevOrigins = [
  '192.168.1.9',
  ...(process.env.NEXT_ALLOWED_DEV_ORIGINS?.split(',')
    .map((host) => host.trim())
    .filter(Boolean) ?? []),
];

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  allowedDevOrigins,
};

function mapLoader(loader) {
  if (typeof loader === 'string') {
    if (loader.includes('fumadocs-mdx/webpack/mdx') || /[/\\]webpack[/\\]mdx(?:\.js)?$/.test(loader)) {
      return mdxBridge;
    }
    if (loader.includes('fumadocs-mdx/webpack/meta') || /[/\\]webpack[/\\]meta(?:\.js)?$/.test(loader)) {
      return metaBridge;
    }
    return loader;
  }

  if (loader && typeof loader === 'object' && typeof loader.loader === 'string') {
    loader.loader = mapLoader(loader.loader);
  }

  return loader;
}

function rewriteRule(rule) {
  if (!rule || typeof rule !== 'object') return;

  if (Array.isArray(rule)) {
    for (const item of rule) rewriteRule(item);
    return;
  }

  if (Array.isArray(rule.loaders)) {
    for (let i = 0; i < rule.loaders.length; i += 1) {
      rule.loaders[i] = mapLoader(rule.loaders[i]);
    }
  }

  if (typeof rule.loader === 'string') {
    rule.loader = mapLoader(rule.loader);
  }

  if (Array.isArray(rule.use)) {
    for (let i = 0; i < rule.use.length; i += 1) {
      rule.use[i] = mapLoader(rule.use[i]);
    }
  } else if (rule.use) {
    rule.use = mapLoader(rule.use);
  }

  if (Array.isArray(rule.oneOf)) {
    for (const item of rule.oneOf) rewriteRule(item);
  }

  if (Array.isArray(rule.rules)) {
    for (const item of rule.rules) rewriteRule(item);
  }
}

/**
 * fumadocs-mdx registers ESM-only webpack loaders. Next 16 Turbopack's
 * loader-runner require()s them and fails. Rewrite loader paths to local
 * CJS bridges that dynamic-import the real loaders.
 */
function rewriteFumadocsLoaders(nextConfig) {
  const turbopack = nextConfig.turbopack
    ? {
        ...nextConfig.turbopack,
        rules: nextConfig.turbopack.rules
          ? Object.fromEntries(
              Object.entries(nextConfig.turbopack.rules).map(([key, value]) => {
                const cloned = structuredClone(value);
                rewriteRule(cloned);
                return [key, cloned];
              }),
            )
          : nextConfig.turbopack.rules,
      }
    : nextConfig.turbopack;

  const originalWebpack = nextConfig.webpack;

  return {
    ...nextConfig,
    turbopack,
    webpack: (webpackConfig, options) => {
      const cfg = originalWebpack ? originalWebpack(webpackConfig, options) : webpackConfig;
      for (const rule of cfg.module?.rules ?? []) {
        rewriteRule(rule);
      }
      return cfg;
    },
  };
}

export default rewriteFumadocsLoaders(withMDX(config));
