// docs/lang-router.js
// Persistent language router for the ljh-sh/lha Pages site.
// Reads ?lang= from the URL, falls back to localStorage['lha-lang'],
// then navigator.language. If the current page's lang dir doesn't
// match the resolved choice, redirects to the equivalent file in the
// right language. Rewrites all internal <a href> links to carry
// ?lang=X so subsequent navigation stays in the chosen language.
// Updates the lang-switcher's aria-current.
//
// Site layout (no Jekyll — .html files served raw):
//   /lha/index.html
//   /lha/security.html
//   /lha/perf.html
//   /lha/{en,zh-CN,zh-TW,ja}/<file>.html
//
// Behavior:
//   1. ?lang=X in URL → set localStorage, return X (strongest signal)
//   2. localStorage['lha-lang'] → return that
//   3. navigator.language → match prefix
//   4. default 'en'
//   If the current URL is /lha/<file>.html (no /<lang>/), and
//   desired isn't 'en', redirect to /lha/<desired>/<file>.html?lang=<desired>.
(function () {
    'use strict';

    var SUPPORTED = ['en', 'zh-CN', 'zh-TW', 'ja'];
    var STORAGE_KEY = 'lha-lang';
    var URL_PARAM = 'lang';

    // 1. Resolve desired language.
    function getDesired() {
        var url = new URL(window.location.href);
        var fromUrl = url.searchParams.get(URL_PARAM);
        if (fromUrl && SUPPORTED.indexOf(fromUrl) !== -1) {
            try { localStorage.setItem(STORAGE_KEY, fromUrl); } catch (e) {}
            return fromUrl;
        }
        var fromStorage = null;
        try { fromStorage = localStorage.getItem(STORAGE_KEY); } catch (e) {}
        if (fromStorage && SUPPORTED.indexOf(fromStorage) !== -1) return fromStorage;
        var bls = (navigator.languages || [navigator.language || 'en'])
            .map(function (l) { return l.toLowerCase(); });
        for (var i = 0; i < bls.length; i++) {
            var bl = bls[i];
            if (bl.indexOf('zh-tw') === 0 || bl.indexOf('zh-hk') === 0) return 'zh-TW';
            if (bl.indexOf('zh') === 0) return 'zh-CN';
            if (bl.indexOf('ja') === 0) return 'ja';
            if (bl.indexOf('en') === 0) return 'en';
        }
        return 'en';
    }

    // 2. Detect current language from URL path.
    function getCurrent() {
        var m = window.location.pathname.match(/\/(en|zh-CN|zh-TW|ja)\//);
        return m ? m[1] : 'en';
    }

    // 3. Compute target path: same file, in the chosen language's dir.
    function toLang(pathname, lang) {
        var parts = pathname.split('/').filter(Boolean);
        var drop = (parts[0] === 'lha') ? 1 : 0;
        if (parts[drop] && SUPPORTED.indexOf(parts[drop]) !== -1) drop++;
        var rest = parts.slice(drop).join('/');
        var file = (rest === '' || !/\.html?$/.test(rest))
            ? ((rest === '' || /\/$/.test(pathname)) ? 'index.html' : 'index.html')
            : rest;
        if (lang === 'en') return '/lha/' + file;
        return '/lha/' + lang + '/' + file;
    }

    // 4. Append or update the ?lang= param on an href (string-level
    //    operation so relative paths resolve correctly).
    function withLang(href, lang) {
        // If it's an absolute URL, validate same-origin.
        var isExternal = /^[a-z]+:\/\//i.test(href) || href.indexOf('//') === 0;
        if (isExternal) {
            try {
                var u = new URL(href);
                if (u.origin !== window.location.origin) return href;
            } catch (e) { return href; }
        }
        if (href.indexOf('?lang=') !== -1 || /[?&]lang=[^&]*/.test(href)) {
            return href.replace(/([?&])lang=[^&#]*/, '$1lang=' + lang);
        }
        if (href.indexOf('?') === -1) {
            return href + '?lang=' + lang;
        }
        return href + '&lang=' + lang;
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

    function markActive(lang) {
        // The currently-active language is rendered as a <strong>
        // (no <a>); the other 3 are <a>. Mark aria-current on both
        // shapes so the active item is identifiable to AT and CSS.
        var strong = document.querySelector('.lang-switch strong');
        if (strong && strong.textContent.trim() === lang) {
            strong.setAttribute('aria-current', 'true');
        }
        var links = document.querySelectorAll('.lang-switch a');
        for (var i = 0; i < links.length; i++) {
            var t = links[i].textContent.trim();
            if (t === lang) {
                links[i].setAttribute('aria-current', 'true');
            } else {
                links[i].removeAttribute('aria-current');
            }
        }
    }

    function rewriteLinks(lang) {
        // Compute the current file name (e.g. "security.html" or
        // "index.html") so the lang-switcher items can build
        // absolute per-language paths. Without this, a switcher
        // item like "../security.html" on a per-language page
        // would resolve to the LEGACY top-level page
        // (/lha/security.html), not the per-language page
        // (/lha/en/security.html). The legacy page is the bug
        // trap: subsequent clicks there are stuck on the same
        // top-level page because the sibling "security.html"
        // resolves to itself.
        var p = window.location.pathname.split('/').filter(Boolean);
        var currentFile = 'index.html';
        if (p.length > 0) {
            var last = p[p.length - 1];
            if (/\.html?$/.test(last)) currentFile = last;
            else if (window.location.pathname.slice(-1) === '/') currentFile = 'index.html';
        }

        // 1. Rewrite the lang-switcher items. Each one targets a
        //    specific language, so we build a per-language URL
        //    using the current file + that target lang + ?lang=<that>.
        var switcher = document.querySelectorAll('.lang-switch a[href]');
        for (var i = 0; i < switcher.length; i++) {
            var a = switcher[i];
            var href = a.getAttribute('href');
            if (!href) continue;
            // The language this item targets = first path segment
            // that's a SUPPORTED code.
            var segs = href.split('/').filter(Boolean);
            var target = null;
            for (var s = 0; s < segs.length; s++) {
                if (SUPPORTED.indexOf(segs[s]) !== -1) { target = segs[s]; break; }
            }
            if (!target) target = 'en';
            // Always build an absolute per-language URL for the
            // switcher. This is the bug fix: clicking "en" from
            // /lha/zh-CN/security.html now goes to
            // /lha/en/security.html?lang=en, not
            // /lha/security.html?lang=en (the legacy top-level
            // page that's the "stuck" page the user was hitting).
            var targetPath;
            if (target === 'en') {
                targetPath = currentFile;
            } else {
                targetPath = target + '/' + currentFile;
            }
            a.setAttribute('href', targetPath + '?lang=' + target);
        }
        // 2. Rewrite all other internal anchors — just add the
        //    ?lang= param; don't change the path. Path rebasing
        //    is the switcher's job; for body content, keeping the
        //    relative path preserves author intent.
        var anchors = document.querySelectorAll('a[href]');
        for (var j = 0; j < anchors.length; j++) {
            var a2 = anchors[j];
            if (a2.parentNode && a2.parentNode.classList && a2.parentNode.classList.contains('lang-switch')) continue;
            var href2 = a2.getAttribute('href');
            if (!isInternal(href2)) continue;
            a2.setAttribute('href', withLang(href2, lang));
        }
    }

    function init() {
        var desired = getDesired();
        var current = getCurrent();
        // Always redirect off the legacy top-level pages (no /<lang>/
        // in URL). The legacy pages have relative body links
        // ("../security.html", "../index.html") which after our
        // ?lang= rewrite still resolve to the legacy top-level
        // pages, so the user is "stuck" — see commit message of
        // this fix. The per-language pages (/lha/<lang>/<file>) have
        // the correct relative link targets, so the user must be
        // on a per-language page for navigation to work.
        if (!/\/(en|zh-CN|zh-TW|ja)\//.test(window.location.pathname)) {
            var target = toLang(window.location.pathname, desired);
            var u = new URL(window.location.href);
            u.pathname = target;
            u.searchParams.set(URL_PARAM, desired);
            window.location.replace(u.pathname + (u.search ? u.search : '') + u.hash);
            return;
        }
        // If we're on a per-language page but the desired language
        // is different, also redirect.
        if (desired !== current) {
            var target = toLang(window.location.pathname, desired);
            var u = new URL(window.location.href);
            u.pathname = target;
            u.searchParams.set(URL_PARAM, desired);
            window.location.replace(u.pathname + (u.search ? u.search : '') + u.hash);
            return;
        }
        rewriteLinks(desired);
        markActive(desired);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
