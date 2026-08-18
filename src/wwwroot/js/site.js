// Meridian Mutual — Claims Triage Console (presentation-only client behavior)

(function () {
  "use strict";

  // --- Submit loading state for "Generate triage briefing" ------------------
  // Keeps the normal full-page POST; just gives the ~15-30s wait a clear state.
  document.querySelectorAll("form[data-mm-loading]").forEach(function (form) {
    form.addEventListener("submit", function () {
      var btn = form.querySelector('button[type="submit"]');
      if (!btn || btn.disabled) { return; }
      var busyLabel = btn.getAttribute("data-mm-busy-label") || "Working…";
      btn.dataset.mmOriginal = btn.innerHTML;
      btn.disabled = true;
      btn.setAttribute("aria-busy", "true");
      btn.innerHTML =
        '<span class="mm-spinner" aria-hidden="true"></span>' +
        '<span>' + busyLabel + '</span>';
    });
  });

  // --- Collapsible agent audit trail ("What the agent did & why") -----------
  document.querySelectorAll(".trace-toggle").forEach(function (toggle) {
    var panelId = toggle.getAttribute("aria-controls");
    var panel = panelId ? document.getElementById(panelId) : null;
    if (!panel) { return; }
    toggle.addEventListener("click", function () {
      var expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", String(!expanded));
      panel.hidden = expanded;
    });
  });
})();
