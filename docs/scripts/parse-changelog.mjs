#!/usr/bin/env node
/**
 * Parse repo-root CHANGELOG.md → docs/src/data/changelog.generated.json
 *
 * Soft-fail: always writes a JSON file so the docs build can proceed.
 * On parse/IO failure: { ok: false, error, releases: [] }.
 */
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const docsRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(docsRoot, '..');
const sourcePath = path.join(repoRoot, 'CHANGELOG.md');
const outDir = path.join(docsRoot, 'src', 'data');
const outPath = path.join(outDir, 'changelog.generated.json');

/** @typedef {'feature' | 'improve' | 'fix'} CategoryKey */

const CATEGORY_HEADINGS = [
  {
    key: /** @type {CategoryKey} */ ('feature'),
    re: /^\*\*[^*]*新增功能/,
  },
  {
    key: /** @type {CategoryKey} */ ('improve'),
    re: /^\*\*[^*]*优化改进/,
  },
  {
    key: /** @type {CategoryKey} */ ('fix'),
    re: /^\*\*[^*]*修复问题/,
  },
];

const VERSION_RE = /^##\s+(v?\d+\.\d+\.\d+)\s*$/;
const BADGE_RE = /!\[[^\]]*\]\(https?:\/\/[^)]+\)\s*/g;
const EMPTY_ITEM_RE = /暂无内容/;

/**
 * @param {string} markdown
 * @returns {import('../src/lib/changelog').ChangelogData}
 */
function parseChangelog(markdown) {
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  /** @type {import('../src/lib/changelog').ChangelogRelease[]} */
  const releases = [];

  /** @type {import('../src/lib/changelog').ChangelogRelease | null} */
  let current = null;
  /** @type {CategoryKey | null} */
  let category = null;
  /** @type {string[]} */
  let summaryLines = [];
  let inSummary = false;

  const flushSummary = () => {
    if (!current) return;
    // Only apply when we actually collected quote lines; never clobber an
    // already-written summary with an empty re-flush (e.g. on ### headings).
    if (summaryLines.length === 0) {
      inSummary = false;
      return;
    }
    const text = summaryLines
      .map((line) => line.replace(/^>\s?/, '').trim())
      .filter(Boolean)
      .join(' ')
      .trim();
    if (text) current.summary = text;
    summaryLines = [];
    inSummary = false;
  };

  const startRelease = (version) => {
    flushSummary();
    current = {
      version: version.startsWith('v') ? version : `v${version}`,
      summary: '',
      categories: {
        feature: [],
        improve: [],
        fix: [],
      },
    };
    category = null;
    releases.push(current);
  };

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();
    const trimmed = line.trim();

    const versionMatch = trimmed.match(VERSION_RE);
    if (versionMatch) {
      startRelease(versionMatch[1]);
      continue;
    }

    if (!current) continue;

    // Horizontal rule / section chrome — ignore
    if (trimmed === '---' || trimmed.startsWith('###')) {
      flushSummary();
      category = null;
      continue;
    }

    // Badges row under version heading
    if (/^!\[/.test(trimmed) && /shields\.io|img\.shields\.io/.test(trimmed)) {
      continue;
    }

    // Blockquote summary
    if (trimmed.startsWith('>')) {
      // summary only before categories start
      if (!category && current.categories.feature.length === 0) {
        inSummary = true;
        summaryLines.push(trimmed);
      }
      continue;
    }

    if (inSummary && trimmed === '') {
      flushSummary();
      continue;
    }

    if (inSummary && trimmed !== '') {
      // non-quote content ends summary
      flushSummary();
    }

    // Category heading
    let matchedCategory = false;
    for (const heading of CATEGORY_HEADINGS) {
      if (heading.re.test(trimmed)) {
        flushSummary();
        category = heading.key;
        matchedCategory = true;
        break;
      }
    }
    if (matchedCategory) continue;

    // List item under a category
    if (category && trimmed.startsWith('-')) {
      const itemText = cleanItemText(trimmed.replace(/^-\s*/, ''));
      if (!itemText || EMPTY_ITEM_RE.test(itemText)) continue;
      current.categories[category].push({ text: itemText });
    }
  }

  flushSummary();

  // Drop releases that somehow have no content at all
  const nonEmpty = releases.filter((release) => {
    const { feature, improve, fix } = release.categories;
    return (
      release.summary.length > 0 ||
      feature.length > 0 ||
      improve.length > 0 ||
      fix.length > 0
    );
  });

  return {
    ok: true,
    releases: nonEmpty,
    generatedAt: new Date().toISOString(),
    source: 'CHANGELOG.md',
  };
}

/**
 * Strip shields badges and collapse whitespace; keep markdown emphasis.
 * @param {string} text
 */
function cleanItemText(text) {
  return text
    .replace(BADGE_RE, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * @param {unknown} error
 */
function errorMessage(error) {
  if (error instanceof Error) return error.message;
  return String(error);
}

/**
 * @param {import('../src/lib/changelog').ChangelogData} data
 */
async function writeOutput(data) {
  await mkdir(outDir, { recursive: true });
  await writeFile(outPath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

async function main() {
  try {
    const markdown = await readFile(sourcePath, 'utf8');
    const data = parseChangelog(markdown);

    if (data.releases.length === 0) {
      await writeOutput({
        ok: false,
        error: 'CHANGELOG.md 未解析到任何版本条目',
        releases: [],
        generatedAt: new Date().toISOString(),
        source: 'CHANGELOG.md',
      });
      console.warn(
        `[parse-changelog] warning: no releases parsed from ${sourcePath}`,
      );
      return;
    }

    await writeOutput(data);
    console.log(
      `[parse-changelog] wrote ${data.releases.length} releases → ${path.relative(docsRoot, outPath)}`,
    );
  } catch (error) {
    const message = errorMessage(error);
    await writeOutput({
      ok: false,
      error: message,
      releases: [],
      generatedAt: new Date().toISOString(),
      source: 'CHANGELOG.md',
    });
    console.warn(`[parse-changelog] soft-fail: ${message}`);
  }
}

await main();
