/**
 * CJS bridge for fumadocs-mdx ESM webpack loaders.
 * Next.js Turbopack's loader-runner only dynamic-imports loaders when
 * loader.type === "module"; otherwise it require()s them and fails on
 * package.json "type": "module". These bridges are CJS and re-export the
 * real ESM loaders via dynamic import().
 */

'use strict';

function createBridge(specifier) {
  let loadPromise;

  function load() {
    if (!loadPromise) {
      loadPromise = import(specifier).then((mod) => mod.default);
    }
    return loadPromise;
  }

  function bridge(source) {
    const callback = this.async();
    load()
      .then((loader) => {
        try {
          loader.call(this, source);
        } catch (error) {
          callback(error);
        }
      })
      .catch(callback);
  }

  return bridge;
}

module.exports.mdx = createBridge('fumadocs-mdx/webpack/mdx');
module.exports.meta = createBridge('fumadocs-mdx/webpack/meta');
