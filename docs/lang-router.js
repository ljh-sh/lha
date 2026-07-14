// docs/lang-router.js
//
// Phase 2 of the lang-router. Runs deferred at the end of <body>,
// after DOMContentLoaded.
//
// What it does:
//   1. Reads the EXPLICIT ?lang=X from the URL. (No localStorage,
//      no navigator.)
//   2. For each <a> in .lang-switch: rewrite the href to an
//      absolute /<repo>/<lang>/<file>?lang=<lang> URL, where <lang>
//      is the language that switcher item targets. Clicking the
//      switcher carries the new language in the URL, and phase 1
//      honors it on the next page load.
//   3. For each other internal <a>: append or update ?lang=<current>
//      so subsequent intra-site navigation preserves the explicit
//      choice.
//   4. Mark the active language in the switcher with
//      aria-current="true" — based on the URL's current /<lang>/
//      directory (or 'en' for top-level pages).
//
// Phase 1 (redirect, no DOM access) lives in lang-router-early.js,
// loaded as a non-defer <script> in <head>. This file only runs if
// phase 1 decided not to redirect — i.e. we're already on the
// correct per-language URL for the explicit ?lang=X.

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
        var parts = pathname.split('/').filter(Boolean);
        if (parts.length === 0) return 'en';
        var i = (parts[0] === REPO) ? 1 : 0;
        var lang = parts[i];
        return (lang && SUPPORTED.indexOf(lang) !== -1) ? lang : 'en';
    }

    function currentFile() {
        var parts = window.location.pathname.split('/').filter(Boolean);
        var drop = (parts[0] === REPO) ? 1 : 0;
        if (parts[drop] && SUPPORTED.indexOf(parts[drop]) !== -1) drop++;
        var rest = parts.slice(drop).join('/');
        return rest === '' ? 'index.html' : rest;
    }

    // Reads the language that a switcher item's href points at, if
    // any. The href can be relative ("../security.html"), absolute
    // ("/lha/en/security.html"), or already per-language
    // ("zh-CN/...").
    function targetLangOf(href) {
        var segs = String(href || '').split('/').filter(Boolean);
        for (var i = 0; i < segs.length; i++) {
            if (SUPPORTED.indexOf(segs[i]) !== -1) return segs[i];
        }
        return null;
    }

    function targetFileOf(href, fallback) {
        var segs = String(href || '').split('/').filter(Boolean);
        for (var i = 0; i < segs.length; i++) {
            var s = segs[i];
            if (SUPPORTED.indexOf(s) !== -1) continue;
            if (s === REPO) continue;
            if (/\.html?$/.test(s)) return s;
        }
        return fallback;
    }

    // Build the absolute per-language URL for a switcher item.
    // For lang='en' (English lives at top level, no /en/ subdir):
    //   /<repo>/<file>?lang=en
    // For other langs:
    //   /<repo>/<lang>/<file>?lang=<lang>
    function absoluteLangHref(switcherHref, fallbackFile) {
        var lang = targetLangOf(switcherHref);
        if (!lang) lang = 'en';
        var file = targetFileOf(switcherHref, fallbackFile);
        if (lang === 'en') return '/' + REPO + '/' + file + '?lang=en';
        return '/' + REPO + '/' + lang + '/' + file + '?lang=' + lang;
    }

    function isInternal(href) {
        if (!href) return false;
        if (href[0] === '#') return false;
        if (/^[a-z]+:\/\//i.test(href)) {
            try {
                var u = new URL(href);
                return u.origin === window.location.origin;
            } catch (e) { return false; }
        }
        return true;
    }

    // Append or update ?lang= on an internal href. Preserves the
    // path the author wrote — relative or absolute — and only tweaks
    // the query string.
    function withLang(href, lang) {
        if (/(\?|&)lang=[^&#]*/.test(href)) {
            return href.replace(/([?&])lang=[^&#]*/, '$1lang=' + lang);
        }
        if (href.indexOf('?') === -1) return href + '?lang=' + lang;
        return href + '&lang=' + lang;
    }

    function rewriteLinks(lang) {
        var file = currentFile();
        var anchors = document.querySelectorAll('a[href]');
        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.getAttribute('href');
            if (!isInternal(href)) continue;
            var inSwitcher = a.parentNode && a.parentNode.classList &&
                             a.parentNode.classList.contains('lang-switch');
            if (inSwitcher) {
                a.setAttribute('href', absoluteLangHref(href, file));
            } else {
                a.setAttribute('href', withLang(href, lang));
            }
        }
    }

    // Mark the switcher item for the language the user is currently
    // sitting on (read from URL pathname, NOT from a preference).
    function markActive(currentLang) {
        var anchors = document.querySelectorAll('.lang-switch a[href]');
        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.getAttribute('href') || '';
            var segs = href.split('/').filter(Boolean);
            var langInHref = null;
            for (var j = 0; j < segs.length; j++) {
                if (SUPPORTED.indexOf(segs[j]) !== -1) { langInHref = segs[j]; break; }
            }
            // Match either by absolute Lang-in-href or by ?lang=X param.
            var queryLangMatch = (href.indexOf('?lang=' + currentLang) !== -1) ||
                                 (href.indexOf('&lang=' + currentLang) !== -1);
            var match = (langInHref === currentLang) ||
                        (langInHref === null && currentLang === 'en' && queryLangMatch);
            if (match) a.setAttribute('aria-current', 'true');
            else a.removeAttribute('aria-current');
        }
    }

    function init() {
        // Use the EXPLICIT ?lang=X for body-link preservation. Default
        // to 'en' if none given so body links still carry a marker.
        var lang = explicitDesired() || currentLangOf(window.location.pathname);
        rewriteLinks(lang);
        markActive(lang);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
