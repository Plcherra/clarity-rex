{{flutter_js}}
{{flutter_build_config}}

(function () {
  function hideBootLoader() {
    document.getElementById('clarity-boot-loader')?.remove();
  }

  function showBootError(error) {
    const loader = document.getElementById('clarity-boot-loader');
    if (!loader) return;
    const detail =
      error instanceof Error ? error.message : String(error ?? 'Unknown boot error');
    loader.innerHTML =
      '<p>Could not start Clarity</p>' +
      '<p style="font-size:13px;opacity:.8;max-width:380px;text-align:center;line-height:1.45;margin:0">' +
      'The app assets failed to load. Refresh this page, or try again later. ' +
      'If this keeps happening after a deploy, the site may be serving the wrong files.' +
      '</p>' +
      '<p style="font-size:11px;opacity:.55;max-width:380px;text-align:center;line-height:1.4;margin:0;word-break:break-word">' +
      detail +
      '</p>';
  }

  // Custom domains can keep caching main.dart.js for hours even after Pages
  // deploys. Append a build stamp so each release uses a fresh cache key.
  try {
    const builds = window._flutter?.buildConfig?.builds;
    if (Array.isArray(builds)) {
      const stamp =
        document.querySelector('meta[name="clarity-web-build"]')?.content ||
        window._flutter.buildConfig.engineRevision ||
        String(Date.now());
      for (const build of builds) {
        if (
          typeof build.mainJsPath === 'string' &&
          !build.mainJsPath.includes('?')
        ) {
          build.mainJsPath = `${build.mainJsPath}?v=${encodeURIComponent(stamp)}`;
        }
      }
    }
  } catch (_) {
    // Boot must continue even if cache-bust patching fails.
  }

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const appRunner = await engineInitializer.initializeEngine();
        hideBootLoader();
        await appRunner.runApp();
      } catch (error) {
        console.error('[Clarity] Flutter boot failed', error);
        showBootError(error);
      }
    },
  });
})();
