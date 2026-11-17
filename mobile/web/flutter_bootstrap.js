{{flutter_js}}
{{flutter_build_config}}

const startup = document.getElementById('startup');
const message = document.getElementById('startup-message');
const retry = document.getElementById('startup-retry');
let started = false;
function showStartupError() {
  if (started) return;
  message.textContent = 'FixNow could not start. Check your connection and try again.';
  retry.hidden = false;
}
window.addEventListener('flutter-first-frame', () => {
  started = true;
  startup.remove();
});
window.addEventListener('error', showStartupError);
window.addEventListener('unhandledrejection', showStartupError);
setTimeout(showStartupError, 20000);

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (error) {
      showStartupError();
    }
  },
});
