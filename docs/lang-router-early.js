// docs/lang-router-early.js
//
// Phase 1 of the lang-router. Runs synchronously in <head>, *before*
// the browser paints anything. Its only job is the redirect decision:
// if the user's desired language doesn't match the language directory
// in the current URL, replace() to the equivalent per-language file.
//
// Why this is its own file:
//   * The browser blocks parsing until a non-defer <script> runs. So
//     when we call window.location.replace() here, the browser abandons
//     rendering the current document and navigates to the target.
//     There is no flash, no race with paint, no flicker.
//   * This script intentionally does not touch the DOM. It does not
//     rewrite links or read <a href> values. It only inspects the
//     URL.
//   * Phase 2 (link rewriting + markActive) lives in lang-router.js,
//     loaded with `defer` at the end of <body>.
//
// Inputs read:
//   * window.location.href           (URL — ?lang=, pathname)
//   * localStorage['lha-lang']       (user's prior choice)
//   * navigator.languages / language (browser hint; only used as a
//                                    fallback when both URL and
//                                    localStorage are silent)
//
// Outputs written:
//   * localStorage['lha-lang']       (cached choice, set whenever ?lang=
//                                    or localStorage is consulted)
//   * window.location                (replace() if redirect needed)
//
// Site layout (no Jekyll — .html files served raw by gh-pages):
//   /<repo>/<file>.html                      legacy top-level (5 pages)
//   /<repo>/<lang>/<file>.html               per-language pages
//   where <repo> is the GitHub Pages repo name, and <lang> ∈
//   SUPPORTED = ['en', 'zh-CN', 'zh-TW', 'ja'].

(function () {
    'use strict';

    var SUPPORTED = ['en', 'zh-CN', 'zh-TW', 'ja'];
    var STORAGE_KEY = 'lha-lang';
    var URL_PARAM = 'lang';
    var REPO = 'lha';

    function getDesired() {
        try {
            var u = new URL(window.location.href);
            var fromUrl = u.searchParams.get(URL_PARAM);
            if (fromUrl && SUPPORTED.indexOf(fromUrl) !== -1) {
                try { localStorage.setItem(STORAGE_KEY, fromUrl); } catch (e) {}
                return fromUrl;
            }
        } catch (e) {}
        try {
            var fromStorage = localStorage.getItem(STORAGE_KEY);
            if (fromStorage && SUPPORTED.indexOf(fromStorage) !== -1) return fromStorage;
        } catch (e) {}
        var langs = (navigator.languages || [navigator.language || 'en']);
        for (var i = 0; i < langs.length; i++) {
            var l = String(langs[i] || '').toLowerCase();
            if (l.indexOf('zh-tw') === 0 || l.indexOf('zh-hk') === 0) return 'zh-TW';
            if (l.indexOf('zh') === 0) return 'zh-CN';
            if (l.indexOf('ja') === 0) return 'ja';
            if (l.indexOf('en') === 0) return 'en';
        }
        return 'en';
    }

    // Read the language directory from the current URL, if any.
    function currentLangOf(pathname) {
        var parts = pathname.split('/').filter(Boolean);
        var i = (parts[0] === REPO) ? 1 : 0;
        return (parts[i] && SUPPORTED.indexOf(parts[i]) !== -1) ? parts[i] : null;
    }

    // Compute target URL: always /<repo>/<lang>/<file>, with ?lang= set.
    function toLang(pathname, lang) {
        var parts = pathname.split('/').filter(Boolean);
        var drop = (parts[0] === REPO) ? 1 : 0;
        if (parts[drop] && SUPPORTED.indexOf(parts[drop]) !== -1) drop++;
        var rest = parts.slice(drop).join('/');
        var file = rest === '' ? 'index.html' : rest;
        return '/' + REPO + '/' + lang + '/' + file;
    }

    // Phase 1: redirect off legacy top-level pages, and off pages whose
    // /<lang>/ doesn't match the desired language.
    var desired = getDesired();
    var current = currentLangOf(window.location.pathname);
    if (current !== desired) {
        var target = toLang(window.location.pathname, desired);
        var u2 = new URL(window.location.href);
        u2.pathname = target;
        u2.searchParams.set(URL_PARAM, desired);
        // Replace, not assign, so the back button works correctly and
        // the legacy page does not stay in history.
        window.location.replace(u2.pathname + u2.search + u2.hash);
    }
})();
