/* Lumette theme JS - vanilla, no dependencies. */
(function () {
  'use strict';
  var L = window.lumette || {};
  var S = L.strings || {};
  var qs = function (s, r) { return (r || document).querySelector(s); };
  var qsa = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var FOCUSABLE = 'a[href],button:not([disabled]),input:not([disabled]):not([type=hidden]),select:not([disabled]),textarea:not([disabled]),[tabindex]:not([tabindex="-1"])';

  /* ---------- Dialog helper: focus trap, Esc, restore focus ---------- */
  function trapFocus(container, e) {
    if (e.key !== 'Tab') return;
    var f = qsa(FOCUSABLE, container).filter(function (el) { return el.offsetParent !== null; });
    if (!f.length) return;
    var first = f[0], last = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  }

  /* ---------- Mobile menu ---------- */
  function initMenu() {
    var toggle = qs('[data-menu-toggle]'), menu = qs('[data-mobile-menu]');
    if (!toggle || !menu) return;
    function open() { menu.hidden = false; toggle.setAttribute('aria-expanded', 'true'); document.body.style.overflow = 'hidden'; var c = qs('[data-menu-close]', menu); if (c) c.focus(); }
    function close() { menu.hidden = true; toggle.setAttribute('aria-expanded', 'false'); document.body.style.overflow = ''; toggle.focus(); }
    toggle.addEventListener('click', open);
    qsa('[data-menu-close]', menu).forEach(function (b) { b.addEventListener('click', close); });
    menu.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); else trapFocus(menu, e); });
  }

  /* ---------- Cart drawer ---------- */
  var drawerOpener = null;
  function drawerEls() { return { root: qs('[data-cart-drawer]'), overlay: qs('[data-drawer-overlay]') }; }
  function openDrawer(opener) {
    var d = drawerEls(); if (!d.root) return false;
    drawerOpener = opener || document.activeElement;
    d.root.classList.add('is-open'); d.overlay.classList.add('is-open');
    d.root.removeAttribute('aria-hidden'); document.body.style.overflow = 'hidden';
    var c = qs('[data-drawer-close]', d.root); if (c) c.focus();
    return true;
  }
  function closeDrawer() {
    var d = drawerEls(); if (!d.root) return;
    d.root.classList.remove('is-open'); d.overlay.classList.remove('is-open');
    d.root.setAttribute('aria-hidden', 'true'); document.body.style.overflow = '';
    if (drawerOpener && drawerOpener.focus) drawerOpener.focus();
  }
  function renderDrawer(sections) {
    var html = sections && sections['cart-drawer']; if (!html) return;
    var doc = new DOMParser().parseFromString(html, 'text/html');
    var fresh = qs('[data-drawer-inner]', doc), cur = qs('[data-drawer-inner]');
    if (fresh && cur) cur.innerHTML = fresh.innerHTML;
    var count = qs('[data-cart-count-source]', doc);
    updateCount(count ? parseInt(count.getAttribute('data-cart-count-source'), 10) : null);
  }
  function updateCount(n) {
    if (n === null || isNaN(n)) return;
    qsa('[data-cart-count]').forEach(function (b) { b.textContent = n; b.hidden = n < 1; });
  }
  function cartRequest(url, body) {
    body.sections = 'cart-drawer';
    return fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }, body: JSON.stringify(body) })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, status: r.status, json: j }; }); });
  }
  function initCart() {
    document.addEventListener('click', function (e) {
      var t = e.target.closest('[data-cart-open]');
      if (t && L.cartDrawer && qs('[data-cart-drawer]')) { e.preventDefault(); openDrawer(t); return; }
      if (e.target.closest('[data-drawer-close]') || e.target.closest('[data-drawer-overlay]')) { closeDrawer(); return; }
      var rm = e.target.closest('[data-line-remove]');
      if (rm) { e.preventDefault(); changeLine(rm.getAttribute('data-line-key'), 0, rm); return; }
      var step = e.target.closest('[data-qty-step]');
      if (step && step.closest('[data-line]')) {
        var line = step.closest('[data-line]'), input = qs('input', line);
        var next = Math.max(0, parseInt(input.value, 10) + parseInt(step.getAttribute('data-qty-step'), 10));
        changeLine(line.getAttribute('data-line-key'), next, step);
      }
    });
    document.addEventListener('change', function (e) {
      var input = e.target.closest('[data-line] input[type=number]');
      if (input) changeLine(input.closest('[data-line]').getAttribute('data-line-key'), Math.max(0, parseInt(input.value, 10) || 0), input);
    });
    document.addEventListener('keydown', function (e) {
      var d = drawerEls(); if (!d.root || !d.root.classList.contains('is-open')) return;
      if (e.key === 'Escape') closeDrawer(); else trapFocus(d.root, e);
    });
  }
  function changeLine(key, qty, el) {
    var host = el.closest('[data-cart-region]') || document;
    var err = qs('[data-cart-error]', host);
    cartRequest(L.routes.cartChange, { id: key, quantity: qty }).then(function (res) {
      if (!res.ok) throw new Error(res.json && res.json.description);
      if (res.json.sections) renderDrawer(res.json.sections);
      if (document.body.classList.contains('template-cart')) { window.location.reload(); }
      var d = drawerEls(); if (d.root && d.root.classList.contains('is-open')) { var f = qs('[data-drawer-close]', d.root); if (f) f.focus(); }
    }).catch(function () { if (err) { err.hidden = false; err.textContent = S.cartError; } });
  }

  /* ---------- Add to cart ---------- */
  function initProductForms() {
    document.addEventListener('submit', function (e) {
      var form = e.target.closest('[data-product-form]');
      if (!form) return;
      e.preventDefault();
      var btns = qsa('[data-add-button]'), err = qs('[data-form-error]', form.parentNode);
      var fd = new FormData(form);
      var body = { id: parseInt(fd.get('id'), 10), quantity: parseInt(fd.get('quantity') || '1', 10), sections: 'cart-drawer' };
      var props = {}; fd.forEach(function (v, k) { var m = k.match(/^properties\[(.+)\]$/); if (m) props[m[1]] = v; });
      if (Object.keys(props).length) body.properties = props;
      btns.forEach(function (b) { b.setAttribute('aria-disabled', 'true'); b.dataset.label = b.textContent; b.textContent = S.adding; });
      if (err) err.hidden = true;
      fetch(L.routes.cartAdd, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }, body: JSON.stringify(body) })
        .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, json: j }; }); })
        .then(function (res) {
          if (!res.ok) throw new Error(res.json.description || S.cartError);
          if (window.gtag && window.lumetteTracking) {
            var v = res.json, val = (v.final_price || 0) / 100 * (v.quantity || 1);
            gtag('event', 'add_to_cart', { currency: L.currency, value: val, items: [{ item_id: v.sku || v.variant_id, item_name: v.product_title, quantity: v.quantity, price: (v.final_price || 0) / 100 }] });
            var t = window.lumetteTracking;
            if (t.gadsId && t.gadsAddToCartLabel) gtag('event', 'conversion', { send_to: t.gadsId + '/' + t.gadsAddToCartLabel, value: val, currency: L.currency });
          }
          if (L.cartDrawer && qs('[data-cart-drawer]')) {
            if (res.json.sections) renderDrawer(res.json.sections);
            else fetch(L.routes.root + '?sections=cart-drawer').then(function (r) { return r.json(); }).then(renderDrawer);
            openDrawer(btns[0]);
          } else { window.location.href = L.routes.cart; }
        })
        .catch(function (ex) { if (err) { err.hidden = false; err.textContent = ex.message || S.cartError; } })
        .then(function () { btns.forEach(function (b) { b.removeAttribute('aria-disabled'); if (b.dataset.label) b.textContent = b.dataset.label; }); });
    });
    // quantity stepper on product page
    document.addEventListener('click', function (e) {
      var s = e.target.closest('[data-qty-step]'); if (!s || s.closest('[data-line]')) return;
      var input = qs('input', s.parentNode); if (!input) return;
      input.value = Math.max(1, (parseInt(input.value, 10) || 1) + parseInt(s.getAttribute('data-qty-step'), 10));
    });
  }

  /* ---------- Product page: variants, gallery, sticky bar, delivery estimate ---------- */
  function addBusinessDays(d, n) {
    var r = new Date(d.getTime()), added = 0;
    while (added < n) { r.setDate(r.getDate() + 1); var w = r.getDay(); if (w !== 0 && w !== 6) added++; }
    return r;
  }
  function initEstimate(root) {
    qsa('[data-estimate]', root).forEach(function (el) {
      var min = parseInt(el.getAttribute('data-min'), 10), max = parseInt(el.getAttribute('data-max'), 10);
      if (isNaN(min) || isNaN(max)) return;
      var f = new Intl.DateTimeFormat(L.locale || undefined, { month: 'short', day: 'numeric' });
      el.textContent = S.estimateFmt.replace('__FROM__', f.format(addBusinessDays(new Date(), min))).replace('__TO__', f.format(addBusinessDays(new Date(), max)));
    });
  }
  function initProduct() {
    var section = qs('[data-product-section]'); if (!section) return;
    var dataEl = qs('[data-variants]', section), variants = dataEl ? JSON.parse(dataEl.textContent) : [];
    var form = qs('[data-product-form]', section), idInput = form && qs('[name=id]', form);
    var slides = qs('[data-gallery-slides]', section), thumbs = qsa('[data-thumb]', section);

    function selectedOptions() { return qsa('[data-option-group]', section).map(function (g) { var c = qs('input:checked', g); return c ? c.value : null; }); }
    function findVariant() { var o = selectedOptions(); return variants.filter(function (v) { return v.options.every(function (x, i) { return x === o[i]; }); })[0]; }
    function showMedia(id) {
      if (!slides || !id) return;
      var s = qs('[data-media-id="' + id + '"]', slides); if (!s) return;
      slides.scrollTo({ left: s.offsetLeft - slides.offsetLeft, behavior: 'smooth' });
    }
    function setButtons(v) {
      qsa('[data-add-button]', section).concat(qsa('[data-add-button]', document)).forEach(function (b) {
        var ok = v && v.available; b.disabled = !ok; b.setAttribute('aria-disabled', ok ? 'false' : 'true');
        b.textContent = !v ? S.unavailable : (ok ? S.addToCart : S.soldOut); b.dataset.label = '';
      });
    }
    function onVariant() {
      var v = findVariant();
      if (idInput && v) idInput.value = v.id;
      setButtons(v);
      if (v) {
        history.replaceState(null, '', '?variant=' + v.id);
        showMedia(v.featured_media_id);
        var url = (qs('[data-product-url]', section) || {}).value;
        fetch(url + '?variant=' + v.id + '&section_id=' + section.getAttribute('data-section-id'))
          .then(function (r) { return r.text(); }).then(function (t) {
            var doc = new DOMParser().parseFromString(t, 'text/html');
            ['[data-price]', '[data-sticky-price]', '[data-sku]'].forEach(function (sel) { var a = qs(sel, doc), b = qs(sel); if (a && b) b.innerHTML = a.innerHTML; });
          });
      }
    }
    qsa('[data-option-group] input', section).forEach(function (i) { i.addEventListener('change', onVariant); });

    thumbs.forEach(function (t, idx) {
      t.addEventListener('click', function () { var s = qsa('[data-media-id]', slides)[idx]; if (s) slides.scrollTo({ left: s.offsetLeft - slides.offsetLeft, behavior: 'smooth' }); });
    });
    if (slides && 'IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (en) { if (en.isIntersecting) { var idx = qsa('[data-media-id]', slides).indexOf(en.target); thumbs.forEach(function (t, i) { t.setAttribute('aria-current', i === idx ? 'true' : 'false'); }); } });
      }, { root: slides, threshold: 0.6 });
      qsa('[data-media-id]', slides).forEach(function (s) { io.observe(s); });
    }

    // Sticky add-to-cart (mobile): show when main button leaves viewport
    var sticky = qs('[data-sticky-atc]'), main = qs('[data-main-add]', section);
    if (sticky && main && 'IntersectionObserver' in window) {
      document.body.classList.add('has-sticky-atc');
      new IntersectionObserver(function (en) { sticky.classList.toggle('is-visible', !en[0].isIntersecting && en[0].boundingClientRect.top < 0); }, { threshold: 0 }).observe(main);
      var sb = qs('[data-sticky-button]', sticky);
      if (sb) sb.addEventListener('click', function () { if (form) form.requestSubmit(); });
    }
    initEstimate(section);
  }

  /* ---------- Collection filters ---------- */
  function initFilters() {
    var f = qs('[data-filter-form]'); if (!f) return;
    qsa('input[type=checkbox],select', f).forEach(function (el) { el.addEventListener('change', function () { f.requestSubmit(); }); });
    qsa('[data-price-input]', f).forEach(function (el) { el.addEventListener('change', function () { f.requestSubmit(); }); });
    f.addEventListener('submit', function () { qsa('input', f).forEach(function (i) { if (i.value === '' && i.type !== 'checkbox') i.disabled = true; }); });
  }

  /* ---------- Related products ---------- */
  function initRecommendations() {
    qsa('[data-recommendations]').forEach(function (el) {
      var url = el.getAttribute('data-url'); if (!url) return;
      var run = function () {
        fetch(url).then(function (r) { return r.text(); }).then(function (t) {
          var doc = new DOMParser().parseFromString(t, 'text/html'), fresh = qs('[data-recommendations]', doc);
          if (fresh && fresh.querySelector('.card')) { el.innerHTML = fresh.innerHTML; el.hidden = false; }
        }).catch(function () {});
      };
      if ('IntersectionObserver' in window) {
        new IntersectionObserver(function (en, ob) { if (en[0].isIntersecting) { ob.disconnect(); run(); } }, { rootMargin: '300px' }).observe(el);
      } else run();
    });
  }

  /* ---------- Email popup ---------- */
  function initPopup() {
    var p = qs('[data-popup]'); if (!p) return;
    var KEY = 'lumette_popup_until', opener = null;
    function blocked() { try { return parseInt(localStorage.getItem(KEY) || '0', 10) > Date.now(); } catch (e) { return false; } }
    function snooze(days) { try { localStorage.setItem(KEY, String(Date.now() + days * 864e5)); } catch (e) {} }
    var cool = parseInt(p.getAttribute('data-cooldown'), 10) || 14;
    function open() { opener = document.activeElement; p.hidden = false; var c = qs('[data-popup-close]', p); if (c) c.focus(); }
    function close() { p.hidden = true; snooze(cool); if (opener && opener.focus) opener.focus(); }
    p.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); else trapFocus(p, e); });
    p.addEventListener('click', function (e) { if (e.target === p || e.target.closest('[data-popup-close]')) close(); });
    var form = qs('form', p), msg = qs('[data-popup-message]', p);
    if (form) form.addEventListener('submit', function (e) {
      e.preventDefault();
      var btn = qs('button[type=submit]', form); btn.setAttribute('aria-disabled', 'true');
      fetch(form.action, { method: 'POST', body: new FormData(form), headers: { 'Accept': 'text/html' } })
        .then(function (r) { return r.text(); })
        .then(function (t) {
          var doc = new DOMParser().parseFromString(t, 'text/html');
          if (qs('[data-popup-success]', doc)) {
            msg.className = 'form-message form-message--success'; msg.textContent = p.getAttribute('data-success'); msg.hidden = false; form.hidden = true; snooze(90);
            if (window.gtag && window.lumetteTracking) gtag('event', 'generate_lead', { method: 'popup' });
          } else { msg.className = 'form-message form-message--error'; msg.textContent = p.getAttribute('data-error'); msg.hidden = false; btn.removeAttribute('aria-disabled'); }
        })
        .catch(function () { form.submit(); });
    });
    if (blocked() || /^\/(cart|checkout|account|password)/.test(location.pathname)) return;
    setTimeout(function () { if (!blocked() && !qs('[data-cart-drawer].is-open')) open(); }, (parseInt(p.getAttribute('data-delay'), 10) || 12) * 1000);
  }

  function init() {
    initMenu(); initCart(); initProductForms(); initProduct(); initFilters(); initRecommendations(); initPopup();
    qsa('[data-estimate]').forEach(function (el) { if (!el.closest('[data-product-section]')) initEstimate(el.parentNode); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
