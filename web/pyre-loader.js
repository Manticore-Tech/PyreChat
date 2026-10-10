(() => {
  const loader = document.getElementById("pyre-web-loader");
  const copy = document.getElementById("pyre-load-copy");
  let finished = false;

  const finishLoading = () => {
    if (finished || !loader) return;
    finished = true;
    loader.classList.add("is-ready");
    window.setTimeout(() => loader.remove(), 220);
  };

  window.addEventListener("flutter-first-frame", finishLoading, { once: true });

  window.setTimeout(() => {
    if (!finished && copy) {
      copy.textContent = "Still loading… first launch can take a moment.";
    }
  }, 8000);

  window.setTimeout(() => {
    if (!finished && copy) {
      copy.textContent = "Taking longer than expected. Check your connection if this persists.";
    }
  }, 20000);
})();
