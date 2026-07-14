// docs/lang-router.js
// Persistent language router for the ljh-sh/lha Pages site.
// Reads ?lang= from the URL, falls back to localStorage['lha-lang'],
// then navigator.language. If the current page's lang dir doesn't
// match the resolved choice, redirects to the equivalent file in the
// right language. Rewrites all internal <a href> links to carry
// ?lang=X so subsequent navigation stays in the chosen language.
// Updates the lang-switcher's aria-current.
//
// Expected file layout:
//   /lha/{en,zh-CN,zh-TW,ja}/index.html
//   /lha/{en,zh-CN,zh-TW,ja}/{security,perf,...}.html
// Plus a flat /lha/{index,security,perf,...}.html that's just an
// en alias (legacy URLs from before the per-lang split).
(function () {
    'use strict';

    var SUPPORTED = ['en', 'zh-CN', 'zh-TW', 'ja'];
    var LANG_DISPLAY = { 'en': 'en', 'zh-CN': 'zh-CN', 'zh-TW': 'zh-TW', 'ja': 'ja' };
    var STORAGE_KEY = 'lha-lang';
    var URL_PARAM = 'lang';

    // 1. Determine desired language
    function getDesired() {
        var url = new URL(window.location.href);
        var fromUrl = url.searchParams.get(URL_PARAM);
        if (fromUrl && SUPPORTED.indexOf(fromUrl) !== -1) {
            localStorage.setItem(STORAGE_KEY, fromUrl);
            return fromUrl;
        }
        var fromStorage = localStorage.getItem(STORAGE_KEY);
        if (fromStorage && SUPPORTED.indexOf(fromStorage) !== -1) return fromStorage;
        var browserLangs = (navigator.languages || [navigator.language || 'en'])
            .map(function (l) { return l.toLowerCase(); });
        for (var i = 0; i < browserLangs.length; i++) {
            var bl = browserLangs[i];
            if (bl.indexOf('zh-tw') === 0 || bl.indexOf('zh-hk') === 0) return 'zh-TW';
            if (bl.indexOf('zh') === 0) return 'zh-CN';
            if (bl.indexOf('ja') === 0) return 'ja';
            if (bl.indexOf('en') === 0) return 'en';
        }
        return 'en';
    }

    // 2. Detect current language from URL path
    function getCurrent() {
        var m = window.location.pathname.match(/\/(en|zh-CN|zh-TW|ja)\//);
        return m ? m[1] : 'en';
    }

    // 3. Resolve a path to a particular language.
    //    - /lha/en/security.html         → /lha/zh-CN/security.html
    //    - /lha/security.html (legacy)   → /lha/zh-CN/security.html
    //    - /lha/                          → /lha/zh-CN/index.html
    function toLang(pathname, lang) {
        // Normalize: split into segments, drop the existing lang dir if any.
        var parts = pathname.split('/').filter(Boolean);
        var dropIdx = (parts[0] === 'lha') ? 1 : 0;
        if (parts[dropIdx] && SUPPORTED.indexOf(parts[dropIdx]) !== -1) dropIdx++;
        var rest = parts.slice(dropIdx).join('/');
        // Determine the current file
        var file;
        if (rest === '') {
            file = 'index.html';
        } else if (/\.html$/.test(rest)) {
            file = rest;
        } else {
            file = rest + (/\/$/.test(pathname) ? 'index.html' : '/index.html');
        }
        // Build new path
        if (lang === 'en') return '/lha/' + file;
        return '/lha/' + lang + '/' + file;
    }

    // 4. Append or replace the ?lang= param on a URL
    function withLang(href, lang) {
        try {
            var u = new URL(href, window.location.origin);
            if (u.origin === window.location.origin) {
                u.searchParams.set(URL_PARAM, lang);
                return u.pathname + (u.search ? u.search : '') + u.hash;
            }
        } catch (e) {}
        return href;
    }

    // 5. Decide if `href` is an internal link we should rewrite
    function isInternal(href) {
        if (!href) return false;
        if (href[0] === '#') return false;
        if (href.indexOf('://') !== -1) {
            try {
                var u = new URL(href);
                return u.origin === window.location.origin;
            } catch (e) {
                return false;
            }
        }
        return true;
    }

    // 6. Mark the active language in the switcher
    function markActive(lang) {
        var links = document.querySelectorAll('.lang-switch a');
        for (var i = 0; i < links.length; i++) {
            var a = links[i];
            var text = a.textContent.trim();
            if (text === LANG_DISPLAY[lang]) {
                a.setAttribute('aria-current', 'true');
            } else {
                a.removeAttribute('aria-current');
            }
        }
    }

    // 7. Rewrite all internal <a href> links to carry ?lang= and to
    //    stay in the chosen language's directory
    function rewriteLinks(lang) {
        var anchors = document.querySelectorAll('a[href]');
        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.getAttribute('href');
            if (!isInternal(href)) continue;
            // Skip the lang-switcher itself (we want the bare path
            // so each switcher item can carry the right ?lang=).
            if (a.parentNode && a.parentNode.classList && a.parentNode.classList.contains('lang-switch')) continue;
            // If the link is to a page in our site, point it at the
            // chosen language's directory
            var u;
            try { u = new URL(href, window.location.origin); } catch (e) { continue; }
            if (u.origin !== window.location.origin) continue;
            // Compute the canonical ("en"-path) then re-lang it
            var canonical = u.pathname;
            var m = canonical.match(/^\/lha\/(en|zh-CN|zh-TW|ja)\//);
            var stripFrom = m ? m[0] : '/lha/';
            if (canonical.indexOf(stripFrom) === 0) {
                canonical = '/lha/' + canonical.substring(stripFrom.length);
            }
            a.setAttribute('href', withLang(canonical, lang));
        }
        // Also rewrite lang-switcher items so each carries ?lang= of
        // the language it points to.
        var switcherAnchors = document.querySelectorAll('.lang-switch a[href]');
        for (var j = 0; j < switcherAnchors.length; j++) {
            var sa = switcherAnchors[j];
            var sHref = sa.getAttribute('href');
            if (!sHref) continue;
            try {
                var su = new URL(sHref, window.location.origin);
                if (su.origin !== window.location.origin) continue;
                // Find the language this switcher item targets
                var sm = su.pathname.match(/\/(en|zh-CN|zh-TW|ja)\//);
                var targetLang = sm ? sm[1] : 'en';
                sa.setAttribute('href', withLang(su.pathname, targetLang));
            } catch (e) {}
        }
    }

    // 8. Run on DOMContentLoaded
    function init() {
        var desired = getDesired();
        var current = getCurrent();

        // If the current page is the legacy en-only path (no /en/ in
        // URL), and the user wants a non-en language, redirect to the
        // per-language file.
        if (desired !== current) {
            var path = toLang(window.location.pathname, desired);
            // Preserve the URL hash and any non-lang query params
            var u = new URL(window.location.href);
            u.pathname = path;
            // Search already has ?lang=... from getDesired (or it didn't;
            // either way we set it fresh).
            u.searchParams.set(URL_PARAM, desired);
            window.location.replace(u.pathname + (u.search ? u.search : '') + u.hash);
            return;
        }

        // Current matches desired — rewrite all internal links and
        // mark the switcher.
        rewriteLinks(desired);
        markActive(desired);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
