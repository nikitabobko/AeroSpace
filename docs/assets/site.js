/* FlightDeck documentation — search and keyboard nav */
(function () {
  'use strict';

  var overlay = null;
  var input = null;
  var results = null;
  var pagefindLoaded = false;
  var pagefind = null;

  function buildDialog() {
    overlay = document.createElement('div');
    overlay.id = 'search-overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Search documentation');

    var box = document.createElement('div');
    box.id = 'search-box';

    input = document.createElement('input');
    input.id = 'search-input';
    input.type = 'search';
    input.placeholder = 'Search documentation…';
    input.setAttribute('aria-label', 'Search query');
    input.setAttribute('autocomplete', 'off');
    input.setAttribute('autocorrect', 'off');
    input.setAttribute('autocapitalize', 'off');

    results = document.createElement('div');
    results.id = 'search-results';
    results.setAttribute('aria-live', 'polite');

    box.appendChild(input);
    box.appendChild(results);
    overlay.appendChild(box);
    document.body.appendChild(overlay);

    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) closeSearch();
    });
    input.addEventListener('input', onInput);
  }

  function loadPagefind() {
    if (pagefindLoaded) return Promise.resolve();
    pagefindLoaded = true;
    return import('./pagefind/pagefind.js')
      .then(function (pf) { pagefind = pf; pagefind.init(); })
      .catch(function () { pagefind = null; });
  }

  function onInput() {
    var query = input.value.trim();
    if (!query || !pagefind) {
      results.innerHTML = '';
      return;
    }
    pagefind.debouncedSearch(query).then(function (res) {
      if (!res) return;
      results.innerHTML = '';
      if (res.results.length === 0) {
        results.innerHTML = '<p style="padding:.5rem .75rem;color:var(--fd-muted);font-size:.85rem">No results</p>';
        return;
      }
      res.results.slice(0, 8).forEach(function (r) {
        r.data().then(function (d) {
          var item = document.createElement('a');
          item.href = d.url;
          item.className = 'pagefind-ui__result';
          item.style.display = 'block';
          item.style.textDecoration = 'none';

          var title = document.createElement('div');
          title.className = 'pagefind-ui__result-title';
          title.textContent = d.meta.title || '';

          var excerpt = document.createElement('div');
          excerpt.className = 'pagefind-ui__result-excerpt';
          excerpt.innerHTML = d.excerpt;

          item.appendChild(title);
          item.appendChild(excerpt);
          results.appendChild(item);

          item.addEventListener('click', closeSearch);
        });
      });
    });
  }

  window.openSearch = function () {
    if (!overlay) buildDialog();
    loadPagefind();
    overlay.classList.add('open');
    setTimeout(function () { input.focus(); input.select(); }, 50);
  };

  function closeSearch() {
    if (overlay) {
      overlay.classList.remove('open');
      results.innerHTML = '';
      input.value = '';
    }
  }

  document.addEventListener('keydown', function (e) {
    var metaOrCtrl = e.metaKey || e.ctrlKey;
    if (metaOrCtrl && e.key === 'k') { e.preventDefault(); window.openSearch(); }
    if (e.key === 'Escape' && overlay && overlay.classList.contains('open')) closeSearch();
  });
})();
