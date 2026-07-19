'use strict';

/**
 * Minimal style-to-js compatible with hast-util-to-estree / hast-util-to-jsx-runtime.
 * Always exports a callable function (CJS + synthetic default) so Turbopack/ESM
 * interop cannot surface `styleToJs is not a function`.
 */

const CUSTOM_PROPERTY = /^--[a-zA-Z0-9_-]+$/;
const HYPHEN = /-([a-z])/g;
const NO_HYPHEN = /^[^-]+$/;
const VENDOR = /^-(webkit|moz|ms|o|khtml)-/;
const MS_VENDOR = /^-(ms)-/;

function skipCamelCase(property) {
  return !property || NO_HYPHEN.test(property) || CUSTOM_PROPERTY.test(property);
}

function camelCase(property, options) {
  if (skipCamelCase(property)) return property;
  let value = property.toLowerCase();
  if (options && options.reactCompat) {
    value = value.replace(MS_VENDOR, (_, prefix) => `${prefix}-`);
  } else {
    value = value.replace(VENDOR, (_, prefix) => `${prefix}-`);
  }
  return value.replace(HYPHEN, (_, ch) => ch.toUpperCase());
}

/**
 * @param {string} style
 * @param {{ reactCompat?: boolean }} [options]
 * @returns {Record<string, string>}
 */
function styleToJs(style, options) {
  if (!style || typeof style !== 'string') {
    return {};
  }

  const output = {};
  // Split on top-level `;` (Shiki styles are simple `prop:value;prop:value`)
  const parts = style.split(';');
  for (const part of parts) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    const colon = trimmed.indexOf(':');
    if (colon === -1) continue;
    const property = trimmed.slice(0, colon).trim();
    const value = trimmed.slice(colon + 1).trim();
    if (!property || !value) continue;
    output[camelCase(property, options)] = value;
  }
  return output;
}

module.exports = styleToJs;
module.exports.default = styleToJs;
module.exports.styleToJs = styleToJs;
