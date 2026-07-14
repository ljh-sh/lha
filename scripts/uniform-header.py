#!/usr/bin/env python3
"""
Refactor ljh-sh/lha Pages site: every non-index page gets the SAME
section nav (6 items, page-language labels, current page as <strong>).

Sections (in order):
  algorithm, perf, security, faq, build-audit, ↑ 站点(=home)

The current page renders as <strong>; others are <a> with relative paths.

Language labels (per the page's own lang attribute):
  en:    algorithm · perf · security · faq · build audit · ↑ site
  zh-CN: 算法 · 性能 · 安全 · 常见问题 · 构建审计 · ↑ 站点
  zh-TW: 演算法 · 效能 · 資安 · 常見問題 · 建置稽核 · ↑ 站台
  ja:    アルゴリズム · 性能 · セキュリティ · FAQ · ビルド監査 · ↑ サイト
"""
import re, sys
from pathlib import Path

# Per-language label sets
LABELS = {
    'en':    ['algorithm', 'perf', 'security', 'faq', 'build audit', '↑ site'],
    'zh-CN': ['算法',       '性能', '安全',    '常见问题', '构建审计', '↑ 站点'],
    'zh-TW': ['演算法',    '效能', '資安',    '常見問題', '建置稽核', '↑ 站台'],
    'ja':    ['アルゴリズム', '性能', 'セキュリティ', 'FAQ', 'ビルド監査', '↑ サイト'],
}
FILES = ['algorithm', 'perf', 'security', 'faq', 'build-audit']

# Map html <html lang="..."> to our label set
HTML_LANG_MAP = {
    'en':    'en',
    'zh-CN': 'zh-CN',
    'zh-Hant': 'zh-TW',
    'ja':    'ja',
}

def render_section_nav(lang_code, current_file, is_top_level):
    """Return inner HTML for <nav class=\"section-nav\"> with the
    current file rendered as <strong>, others as <a href>.

    For top-level pages, sibling hrefs are relative filenames like
    'perf.html'. For per-language pages, we go up one and into the
    same-named file: '../perf.html'. For ↑ 站点 it's always
    '../index.html' (since home is at top-level)."""
    labels = LABELS[lang_code]
    prefix = '' if is_top_level else '../'
    parts = []
    for i, name in enumerate(FILES):
        label = labels[i]
        href = prefix + name + '.html'
        if name == current_file:
            parts.append('<strong>' + label + '</strong>')
        else:
            parts.append('<a href="' + href + '">' + label + '</a>')
    # Last: ↑ 站点, links to ../index.html (or index.html)
    home_label = labels[5]
    home_href = prefix + 'index.html'
    parts.append('<a href="' + home_href + '">' + home_label + '</a>')
    return ' · '.join(parts)

def render_lang_switch(lang_code, current_file, is_top_level):
    """Render the 4-language switch in the page's language. Active
    lang as <strong>, others as <a href>."""
    prefix = '' if is_top_level else '../'

    def href_for(target_lang):
        # English lives at top level; other langs in /<lang>/ subdir.
        # From a top-level page, going to en: current_file.html,
        # going to other: <lang>/<file>.html.
        # From a per-language page: ../<file>.html for en (top level),
        # ../<lang>/<file>.html for others.
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
    """Infer current file stem from path. /foo.html → 'foo'."""
    name = p.name
    if name.endswith('.html'):
        return name[:-5]
    return name

def is_top_level_path(p):
    """True if the path lives directly under docs/ (i.e. no per-lang
    subdirectory). False if it's under docs/<lang>/."""
    rel = p.relative_to(Path('docs'))
    return len(rel.parts) == 1   # just the file, no subdir

def infer_lang(html):
    m = re.search(r'<html\s+lang="([^"]+)"', html)
    if not m: return 'en'
    return HTML_LANG_MAP.get(m.group(1), 'en')

def refactor_file(path):
    html = path.read_text()
    lang = infer_lang(html)
    current = current_file_from_path(path)
    top = is_top_level_path(path)

    if current == 'index':
        new_header = '<header class="page-header">\n    <div class="lang-switch">' + render_lang_switch(lang, 'index', top) + '</div>\n</header>'
    else:
        new_header = (
            '<header class="page-header">\n'
            '    <nav class="section-nav">' + render_section_nav(lang, current, top) + '</nav>\n'
            '    <div class="lang-switch">' + render_lang_switch(lang, current, top) + '</div>\n'
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
