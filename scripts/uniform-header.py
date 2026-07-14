#!/usr/bin/env python3
"""
Refactor ljh-sh/lha Pages site: every page gets a section nav.

  - Homepage (index.html): 4-item nav that mostly goes OFF site
    (Latest release + Upstream are github.com links; Build audit
    + Algorithm are internal).
  - Other pages: 6-item nav in the page's own language
    (algorithm · perf · security · faq · build-audit · ↑ home).

The current page item is rendered as <strong>; others as <a href>.
"""
import re, sys
from pathlib import Path

# Per-language label sets for the section nav on each page type.
# All pages (including the homepage) use SECTION_LABELS.
# INDEX_LABELS is retained but no longer wired in (kept around in case
# we want a 4-item compact homepage nav later).

# Sections for non-homepages, with per-language labels.
SECTION_LABELS = {
    'en':    ['algorithm', 'perf', 'security', 'faq', 'build audit', '↑ home'],
    'zh-CN': ['算法',       '性能', '安全',    '常见问题', '构建审计', '↑ 首页'],
    'zh-TW': ['演算法',    '效能', '資安',    '常見問題', '建置稽核', '↑ 首頁'],
    'ja':    ['アルゴリズム', '性能', 'セキュリティ', 'FAQ', 'ビルド監査', '↑ ホーム'],
}
SECTIONS = ['algorithm', 'perf', 'security', 'faq', 'build-audit']

HTML_LANG_MAP = {
    'en':    'en',
    'zh-CN': 'zh-CN',
    'zh-Hant': 'zh-TW',
    'ja':    'ja',
}


def render_index_nav(lang_code, is_top_level):
    """Homepage section nav: 4 items (2 external + 2 internal).
    Internal hrefs get '../' prefix when on per-language homepage."""
    prefix = '' if is_top_level else '../'
    parts = []
    for label, href in INDEX_LABELS[lang_code]:
        # External links keep their full URL; internal links get the prefix.
        full_href = href if href.startswith('http') else prefix + href
        parts.append('<a href="' + full_href + '">' + label + '</a>')
    return ' · '.join(parts)


def render_section_nav(lang_code, current_file, is_top_level):
    """Section nav used on EVERY page (including the homepage).
    The current item is rendered as <strong>; the rest are <a href>.
    For the homepage, 'home' is the active item — <strong>↑ 首页</strong>."""
    labels = SECTION_LABELS[lang_code]
    prefix = '' if is_top_level else '../'
    parts = []
    for i, name in enumerate(SECTIONS):
        label = labels[i]
        href = prefix + name + '.html'
        if name == current_file:
            parts.append('<strong>' + label + '</strong>')
        else:
            parts.append('<a href="' + href + '">' + label + '</a>')
    home_label = labels[5]
    home_href = prefix + 'index.html'
    if current_file == 'home':
        parts.append('<strong>' + home_label + '</strong>')
    else:
        parts.append('<a href="' + home_href + '">' + home_label + '</a>')
    return ' · '.join(parts)


def render_lang_switch(lang_code, current_file, is_top_level):
    """Render the 4-language switch in the page's language."""
    prefix = '' if is_top_level else '../'

    def href_for(target_lang):
        if target_lang == 'en':
            return prefix + current_file + '.html'
        return prefix + target_lang + '/' + current_file + '.html'

    parts = []
    for lang_target in ['en', 'zh-CN', 'zh-TW', 'ja']:
        if lang_target == lang_code:
            parts.append('<strong>' + lang_target + '</strong>')
        else:
            parts.append('<a href="' + href_for(lang_target) + '">'
                         + lang_target + '</a>')
    return ' · '.join(parts)


def current_file_from_path(p):
    name = p.name
    if name.endswith('.html'):
        return name[:-5]
    return name


def is_top_level_path(p):
    rel = p.relative_to(Path('docs'))
    return len(rel.parts) == 1


def infer_lang(html):
    m = re.search(r'<html\s+lang="([^"]+)"', html)
    if not m: return 'en'
    return HTML_LANG_MAP.get(m.group(1), 'en')


def refactor_file(path):
    html = path.read_text()
    lang = infer_lang(html)
    current = current_file_from_path(path)
    # On the homepage, the "current section" is the home item — the
    # section nav expects the literal stem 'home' to light up ↑ 首页.
    if current == 'index':
        section_current = 'home'
    else:
        section_current = current
    top = is_top_level_path(path)

    nav_inner = render_section_nav(lang, section_current, top)
    header_inner = (
        '<nav class="section-nav">' + nav_inner + '</nav>\n'
        '    <div class="lang-switch">' + render_lang_switch(lang, current, top) + '</div>'
    )

    new_header = (
        '<header class="page-header">\n'
        '    ' + header_inner + '\n'
        '</header>'
    )

    new = re.sub(
        r'<header class="page-header">.*?</header>',
        new_header,
        html,
        count=1,
        flags=re.DOTALL
    )
    if new == html:
        return False
    path.write_text(new)
    return True


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else 'docs')
    changed = 0
    for f in sorted(root.rglob('*.html')):
        if refactor_file(f):
            changed += 1
            print('  OK', f)
    print(f'\n{changed} files updated.')


if __name__ == '__main__':
    main()
