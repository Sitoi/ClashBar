/**
 * ESM entry — always a real default function export.
 * Mirrors CJS shim used by hast-util-to-estree parseStyle().
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
export default function styleToJs(style, options) {
  if (!style || typeof style !== 'string') {
    return {};
  }

  const output = {};
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

export { styleToJs };
