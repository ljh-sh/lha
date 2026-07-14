#!/usr/bin/env python3
"""Move the usage TLDR from below the hero to right before the
brief-history section. Idempotent: removes any existing misplaced
usage TLDR before inserting in the right place."""
import re, sys
from pathlib import Path

LANG_MAP = {'en': 'en', 'zh-CN': 'zh-CN', 'zh-Hant': 'zh-TW', 'ja': 'ja'}

USAGE_BLOCKS = {
    'en': {
        'intro_html': '<b>Usage.</b> Four commands &mdash; compress, decompress, list, print:',
        'commands': [
            ('lha c archive.lzh file1 file2', 'compress'),
            ('lha x archive.lzh',             'decompress / extract'),
            ('lha l archive.lzh',             'list (ls)'),
            ('lha p archive.lzh file',        'print to stdout (cat)'),
        ],
    },
    'zh-CN': {
        'intro_html': '<b>使用方法。</b>四组命令 &mdash; 压缩、解压、列表、打印：',
        'commands': [
            ('lha c archive.lzh file1 file2', '压缩'),
            ('lha x archive.lzh',             '解压'),
            ('lha l archive.lzh',             '列表（ls）'),
            ('lha p archive.lzh file',        '打印到标准输出（cat）'),
        ],
    },
    'zh-TW': {
        'intro_html': '<b>使用方法。</b>四組指令 &mdash; 壓縮、解壓、列表、輸出：',
        'commands': [
            ('lha c archive.lzh file1 file2', '壓縮'),
            ('lha x archive.lzh',             '解壓'),
            ('lha l archive.lzh',             '列表（ls）'),
            ('lha p archive.lzh file',        '輸出至標準輸出（cat）'),
        ],
    },
    'ja': {
        'intro_html': '<b>使い方。</b>4つのコマンド &mdash; 圧縮、展開、一覧、出力：',
        'commands': [
            ('lha c archive.lzh file1 file2', '圧縮'),
            ('lha x archive.lzh',             '展開'),
            ('lha l archive.lzh',             '一覧（ls）'),
            ('lha p archive.lzh file',        '標準出力へ表示（cat）'),
        ],
    },
}

INSTALL_LINE = {
    'en':    'install: <code>x eget use lha</code> &middot; static binary, ~150 KB, zero deps',
    'zh-CN': '安装：<code>x eget use lha</code> &middot; 静态二进制，~150 KB，零依赖',
    'zh-TW': '安裝：<code>x eget use lha</code> &middot; 靜態二進位檔，~150 KB，零相依',
    'ja':    'インストール：<code>x eget use lha</code> &middot; 静的バイナリ，~150 KB，依存なし',
}


def build_usage_block(lang_code):
    blk = USAGE_BLOCKS[lang_code]
    pad = max(len(cmd) for cmd, _ in blk['commands'])
    lines = []
    for cmd, label in blk['commands']:
        lines.append('  ' + cmd.ljust(pad) + '   # ' + label)
    pre_inner = '\n'.join(lines)
    return (
        '<aside class="tldr" id="usage">\n'
        '    <p>' + blk['intro_html'] + '</p>\n'
        '    <pre><code>' + pre_inner + '</code></pre>\n'
        '    <p class="cpu-note">' + INSTALL_LINE[lang_code] + '</p>\n'
        '</aside>'
    )


def infer_lang(html):
    m = re.search(r'<html\s+lang="([^"]+)"', html)
    if not m: return 'en'
    return LANG_MAP.get(m.group(1), 'en')


def refactor_file(path):
    html = path.read_text()
    lang = infer_lang(html)

    # Step 1: remove any existing usage TLDR (regardless of position).
    html = re.sub(
        r'\n*\s*<aside class="tldr" id="usage">.*?</aside>',
        '',
        html,
        flags=re.DOTALL
    )

    # Step 2: insert the usage TLDR just before the brief-history
    # section. The brief-history section is identifiable by its
    # heading text — it varies per language, so we match by id
    # (id="history") which is the conventional name across pages.
    usage_html = build_usage_block(lang)
    target_re = r'(<section\s+id="history">)'
    new = re.sub(
        target_re,
        '\n\n    ' + usage_html + '\n\n    ' + r'\1',
        html,
        count=1
    )
    if new == html:
        # Some pages don't have id="history" (e.g. faq). Fall back
        # to inserting before <footer>.
        new = re.sub(
            r'(<footer>)',
            '\n\n    ' + usage_html + '\n\n    ' + r'\1',
            html,
            count=1
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
