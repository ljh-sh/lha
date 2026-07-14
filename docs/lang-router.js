// docs/lang-router.js
//
// Phase 2 of the lang-router. Runs deferred at the end of <body>,
// after DOMContentLoaded. Its only jobs:
//
//   1. For each <a> in .lang-switch: rewrite the href to an *absolute*
//      /<repo>/<lang>/<file>?lang=<lang> URL, where <lang> is the
//      language that switcher item targets. This is the bug fix: the
//      previous version produced relative hrefs that resolved to the
//      legacy top-level page, so clicking "en" on
//      /lha/zh-CN/security.html stayed on /lha/zh-CN/security.html.
//
//   2. For each other internal <a>: append or update ?lang=<current>
//      so subsequent intra-site navigation preserves the language.
//
//   3. Mark the active language in the switcher with aria-current=true.
//
// Phase 1 (redirect before paint) lives in lang-router-early.js,
// loaded as a non-defer <script> in <head>. This file only runs if
// phase 1 decided *not* to redirect — i.e. we're already on the
// correct per-language URL.

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

    // Current file name, e.g. "security.html" or "index.html".
    function currentFile() {
        var path = window.location.pathname;
        var parts = path.split('/').filter(Boolean);
        var drop = (parts[0] === REPO) ? 1 : 0;
        if (parts[drop] && SUPPORTED.indexOf(parts[drop]) !== -1) drop++;
        var rest = parts.slice(drop).join('/');
        return rest === '' ? 'index.html' : rest;
    }

    // Read the language that a switcher item's href points at, if any.
    // The href can be relative ("../security.html"), absolute
    // ("/lha/en/security.html"), or already per-language ("zh-CN/...").
    function targetLangOf(href) {
        var segs = String(href || '').split('/').filter(Boolean);
        for (var i = 0; i < segs.length; i++) {
            if (SUPPORTED.indexOf(segs[i]) !== -1) return segs[i];
        }
        return null;
    }

    // Read the file that a switcher item's href points at, if any.
    // We default to the current file when the switcher href doesn't
    // hint at a different one.
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
    // Guarantees: starts with "/", contains the language directory,
    // ends with ?lang=<lang>. No relative path can survive this.
    function absoluteLangHref(switcherItemHref, fallbackFile) {
        var lang = targetLangOf(switcherItemHref) || 'en';
        var file = targetFileOf(switcherItemHref, fallbackFile);
        return '/' + REPO + '/' + lang + '/' + file + '?' + URL_PARAM + '=' + lang;
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
            return href.replace(/([?&])lang=[^&#]*/, '$1' + URL_PARAM + '=' + lang);
        }
        if (href.indexOf('?') === -1) return href + '?' + URL_PARAM + '=' + lang;
        return href + '&' + URL_PARAM + '=' + lang;
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

    function markActive(lang) {
        // Switcher items carry /<lang>/ as a path segment after this
        // script runs, so detect the active item by inspecting the
        // rewritten href rather than the textual label (which would
        // miss localized labels like "中文" / "繁體").
        var anchors = document.querySelectorAll('.lang-switch a[href]');
        for (var i = 0; i < anchors.length; i++) {
            var a = anchors[i];
            var href = a.getAttribute('href') || '';
            var segs = href.split('/').filter(Boolean);
            var match = segs.indexOf(lang) !== -1;
            if (match) a.setAttribute('aria-current', 'true');
            else a.removeAttribute('aria-current');
        }
    }

    function init() {
        var lang = getDesired();
        rewriteLinks(lang);
        markActive(lang);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
