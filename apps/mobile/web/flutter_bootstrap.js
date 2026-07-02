{{flutter_js}}
{{flutter_build_config}}

(function () {
  function hideBootLoader() {
    document.getElementById('clarity-boot-loader')?.remove();
  }

  function showBootError(error) {
    const loader = document.getElementById('clarity-boot-loader');
    if (!loader) return;
    const message =
      error instanceof Error ? error.message : String(error ?? 'Unknown boot error');
    loader.innerHTML =
      '<p>Could not start Clarity</p>' +
      '<p style="font-size:12px;opacity:.75;max-width:360px;text-align:center;line-height:1.4">' +
      message +
      '</p>';
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
