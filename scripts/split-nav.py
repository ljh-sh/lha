#!/usr/bin/env python3
"""Split .lang-switch into dedicated language switcher + section nav row."""
import re
import sys
from pathlib import Path

SUPPORTED = {'en', 'zh-CN', 'zh-TW', 'ja'}

ITEM_RE = re.compile(
    r'<(strong)>([^<]+)</\1>'
    r'|<a\s+href="([^"]+)"[^>]*>([^<]+)</a>'
)


def parse_items(block_html):
    items = []
    for m in ITEM_RE.finditer(block_html):
        if m.group(1) == 'strong':
            items.append(('strong', '', m.group(2)))
        else:
            items.append(('a', m.group(3), m.group(4)))
    return items


def render(items, indent='        '):
    """Render with `indent` before each item; joined with ' · ' on one line."""
    parts = []
    for tag, href, text in items:
        if tag == 'strong':
            parts.append(f'<strong>{text}</strong>')
        else:
            parts.append(f'<a href="{href}">{text}</a>')
    # Re-indent per-item on separate lines, joined by ' · '
    return ('\n' + indent + '· ').join(parts)


def refactor(path):
    html = path.read_text()
    # Match <div class="lang-switch"> ... </div> with any whitespace inside.
    m = re.search(
        r'<div class="lang-switch">(.*?)</div>',
        html, re.DOTALL
    )
    if not m:
        return False

    items = parse_items(m.group(1))
    if not items:
        return False

    split_idx = None
    lang_seen = 0
    for i, (_, _, text) in enumerate(items):
        if text.strip() in SUPPORTED:
            lang_seen += 1
            if lang_seen == 4:
                split_idx = i
                break
    if split_idx is None:
        return False

    lang_items = items[:split_idx + 1]
    section_items = items[split_idx + 1:]

    # Preserve indentation by reusing the leading whitespace of the
    # existing <div class="lang-switch"> open tag, like:
    #     <div class="lang-switch">
    #         <strong>en</strong> · ...
    #     </div>
    # Find the indentation by looking at the line containing <div class="lang-switch">.
    line_start = html.rfind('\n', 0, m.start()) + 1
    indent_block = html[line_start:m.start()].split('class=')[0]  # e.g. '    '
    indent_item = indent_block + '    '  # 4 more spaces inside

    new_block = '<div class="lang-switch">\n' + indent_item + render(lang_items, indent=indent_item) + '\n' + indent_block + '</div>'
    if section_items:
        new_block += '\n' + indent_block + '<div class="section-nav">\n' + indent_item + render(section_items, indent=indent_item) + '\n' + indent_block + '</div>'

    new_html = html.replace(m.group(0), new_block)
    if new_html == html:
        return False
    path.write_text(new_html)
    return True


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    targets = sorted(root.rglob('*.html'))
    changed = 0
    for f in targets:
        if refactor(f):
            changed += 1
            print(f"  OK   {f}")
        else:
            print(f"  --   {f}")
    print(f"\n{changed}/{len(targets)} files updated.")


if __name__ == '__main__':
    main()
