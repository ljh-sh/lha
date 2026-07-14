// docs/lang-router-early.js
//
// Phase 1 of the lang-router. Runs synchronously in <head>, BEFORE
// the browser paints anything. Its only job is the redirect
// decision, and it ONLY honors an explicit `?lang=X` in the URL.
//
// What this file does NOT do:
//   * Read localStorage.
//   * Read navigator.language / navigator.languages.
//   * Auto-switch the user's language based on prior preference.
//
// Why: the user controls when language switches. A switcher click
// places `?lang=X` into a URL. That's the only signal we honor.
// If the URL has no `?lang=X`, this script does nothing and the
// page renders as the URL says.
//
// When it DOES redirect:
//   * URL has explicit ?lang=X (one of the SUPPORTED codes).
//   * The current pathname's /<lang>/ dir (if any) doesn't match X.
//   * Action: location.replace() to /<repo>/<lang>/<file> for X,
//     preserving the rest of the URL. Browser aborts parsing the
//     current document; no flash.
//
// File layout assumed (no /en/ subdir — English lives at top level):
//   /<repo>/<file>.html                 legacy English pages
//   /<repo>/<lang>/<file>.html          zh-CN, zh-TW, ja
//
// So for explicit='en' the target is /<repo>/<file> (no /en/ prefix).
// For other langs the target is /<repo>/<lang>/<file>.

(function () {
    'use strict';

    var SUPPORTED = ['en', 'zh-CN', 'zh-TW', 'ja'];
    var REPO = 'lha';

    function explicitDesired() {
        try {
            var u = new URL(window.location.href);
            var v = u.searchParams.get('lang');
            if (v && SUPPORTED.indexOf(v) !== -1) return v;
        } catch (e) {}
        return null;
    }

    function currentLangOf(pathname) {
        // Returns the /<lang>/ directory if present; otherwise 'en'.
        // Top-level legacy pages count as English — there's no /en/
        // subdir on disk because English lives at the top level.
        var parts = pathname.split('/').filter(Boolean);
        if (parts.length === 0) return 'en';
        var i = (parts[0] === REPO) ? 1 : 0;
        var lang = parts[i];
        return (lang && SUPPORTED.indexOf(lang) !== -1) ? lang : 'en';
    }

    function toLang(pathname, lang) {
        var parts = pathname.split('/').filter(Boolean);
        var drop = (parts[0] === REPO) ? 1 : 0;
        if (parts[drop] && SUPPORTED.indexOf(parts[drop]) !== -1) drop++;
        var rest = parts.slice(drop).join('/');
        var file = rest === '' ? 'index.html' : rest;
        if (lang === 'en') return '/' + REPO + '/' + file;
        return '/' + REPO + '/' + lang + '/' + file;
    }

    var explicit = explicitDesired();
    if (explicit) {
        var current = currentLangOf(window.location.pathname);
        if (current !== explicit) {
            var u = new URL(window.location.href);
            u.pathname = toLang(window.location.pathname, explicit);
            u.searchParams.set('lang', explicit);
            window.location.replace(u.pathname + u.search + u.hash);
        }
    }
})();
