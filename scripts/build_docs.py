#!/usr/bin/env python3
"""Render a Markdown reference sheet as a self-contained HTML page.

The Markdown file is the source of truth; the HTML is generated and always
overwritten. Never edit the generated file — edit the Markdown and re-run.

    python3 scripts/build_docs.py INPUT.md OUTPUT.html [--title "Page title"]

Supports the subset actually used in these sheets: headings, fenced code,
tables, blockquotes, bullet lists, bold, inline code and links. Lines opening
with a marker emoji become callout blocks.
"""

import html
import re
import sys
from pathlib import Path

CALLOUTS = {"\U0001F534": "stop", "⚠️": "warn", "\U0001F48E": "tip"}

CSS = """
:root{--bg:#fbfaf8;--fg:#1c1b19;--muted:#6b6862;--line:#e2ded6;--card:#fff;
--code-bg:#f4f1eb;--accent:#b4501e;--accent-soft:#fdf0e8;--ok:#2f6f4e;
--warn:#8a6d1f;--stop:#a33028;
--mono:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,monospace}
@media (prefers-color-scheme:dark){:root{--bg:#16150f;--fg:#eae6dd;--muted:#9d978a;
--line:#2f2c24;--card:#1e1c16;--code-bg:#24211a;--accent:#e8834a;
--accent-soft:#2a1d14;--ok:#7fbb96;--warn:#d9bc6a;--stop:#e08a80}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
-webkit-font-smoothing:antialiased}
.wrap{max-width:960px;margin:0 auto;padding:2.5rem 1.25rem 5rem}
h1{font-size:2rem;margin:0 0 1.25rem;letter-spacing:-.02em;
border-bottom:2px solid var(--fg);padding-bottom:1rem}
h2{font-size:1.3rem;margin:2.75rem 0 .6rem;padding-bottom:.35rem;
border-bottom:1px solid var(--line);letter-spacing:-.01em;scroll-margin-top:1rem}
h3{font-size:1.05rem;margin:1.75rem 0 .4rem;color:var(--accent)}
h4{font-size:.95rem;margin:1.25rem 0 .3rem}
p{margin:.6rem 0}
code{font-family:var(--mono);font-size:.87em;background:var(--code-bg);
padding:.12em .38em;border-radius:4px}
pre{background:var(--code-bg);border:1px solid var(--line);border-radius:8px;
padding:.9rem 1rem;overflow-x:auto;font-family:var(--mono);font-size:.83rem;
line-height:1.55;margin:.75rem 0}
pre code{background:none;padding:0;font-size:inherit}
table{border-collapse:collapse;width:100%;margin:.9rem 0;font-size:.93rem;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:.5rem .7rem;text-align:left;vertical-align:top}
th{background:var(--card);font-weight:600}
blockquote{border-left:3px solid var(--accent);margin:.9rem 0;padding:.15rem 0 .15rem .9rem;color:var(--muted)}
blockquote p{margin:.25rem 0}
.callout{border-left:3px solid var(--line);padding:.15rem 0 .15rem .9rem;margin:.9rem 0}
.callout.stop{border-color:var(--stop)}
.callout.warn{border-color:var(--warn)}
.callout.tip{border-color:var(--ok)}
.callout p{margin:.25rem 0}
ul,ol{margin:.6rem 0;padding-left:1.4rem}
li{margin:.25rem 0}
a{color:var(--accent)}
nav.toc{background:var(--card);border:1px solid var(--line);border-radius:10px;
padding:1rem 1.25rem;margin:1.5rem 0}
nav.toc ul{margin:.4rem 0 0;padding-left:1.1rem;columns:2;column-gap:2rem}
nav.toc li{margin:.2rem 0}
footer{margin-top:4rem;padding-top:1rem;border-top:1px solid var(--line);
text-align:center;color:var(--muted);font-size:.82rem;font-style:italic}
@media (max-width:620px){nav.toc ul{columns:1}}
"""


def inline(text):
    """Escape, then re-apply the inline Markdown we support."""
    out = html.escape(text)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"\[\[([^\]]+)\]\]", r"<em>\1</em>", out)          # vault links: no target here
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', out)
    return out


def slug(text):
    base = re.sub(r"[^a-z0-9]+", "-", re.sub(r"<[^>]+>", "", text).lower()).strip("-")
    return base or "section"


def convert(md):
    # strip YAML front matter
    if md.startswith("---\n"):
        md = md.split("\n---\n", 1)[-1]

    lines = md.split("\n")
    out, toc = [], []
    i, in_code = 0, False
    list_kind = None          # "ul" | "ol" | None
    para = []                 # buffered lines of the current paragraph

    def flush_para():
        """A paragraph in Markdown is several lines until a blank one."""
        if not para:
            return
        text = " ".join(para)
        para.clear()
        cls = next((c for k, c in CALLOUTS.items() if text.startswith(k)), None)
        if cls:
            out.append(f'<div class="callout {cls}"><p>{inline(text)}</p></div>')
        else:
            out.append(f"<p>{inline(text)}</p>")

    def close_list():
        nonlocal list_kind
        if list_kind:
            out.append(f"</{list_kind}>")
            list_kind = None

    while i < len(lines):
        line = lines[i]

        if line.startswith("```"):
            flush_para()
            close_list()
            if in_code:
                out.append("</code></pre>")
                in_code = False
            else:
                out.append("<pre><code>")
                in_code = True
            i += 1
            continue

        if in_code:
            out.append(html.escape(line))
            i += 1
            continue

        stripped = line.strip()

        if not stripped:
            flush_para()
            close_list()
            i += 1
            continue

        # table: a header row followed by a separator row
        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i + 1].strip()):
            flush_para()
            close_list()
            headers = [c.strip() for c in stripped.strip("|").split("|")]
            out.append("<table><thead><tr>" + "".join(f"<th>{inline(h)}</th>" for h in headers) + "</tr></thead><tbody>")
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                out.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in cells) + "</tr>")
                i += 1
            out.append("</tbody></table>")
            continue

        m = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if m:
            flush_para()
            close_list()
            level, text = len(m.group(1)), inline(m.group(2))
            if level == 2:
                anchor = slug(m.group(2))
                toc.append((anchor, text))
                out.append(f'<h2 id="{anchor}">{text}</h2>')
            else:
                out.append(f"<h{level}>{text}</h{level}>")
            i += 1
            continue

        if stripped.startswith(">"):
            flush_para()
            close_list()
            block = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                block.append(lines[i].strip().lstrip(">").strip())
                i += 1
            body = " ".join(b for b in block if b)
            cls = next((c for k, c in CALLOUTS.items() if body.startswith(k)), None)
            if cls:
                out.append(f'<div class="callout {cls}"><p>{inline(body)}</p></div>')
            else:
                out.append(f"<blockquote><p>{inline(body)}</p></blockquote>")
            continue

        # list items, bulleted or numbered — continuation lines are indented
        m = re.match(r"^([-*]|\d+\.)\s+(.*)$", stripped)
        if m:
            flush_para()
            kind = "ul" if m.group(1) in "-*" else "ol"
            if list_kind != kind:
                close_list()
                out.append(f"<{kind}>")
                list_kind = kind
            item = [m.group(2)]
            i += 1
            while i < len(lines) and lines[i].startswith(("   ", "\t")) and lines[i].strip() \
                    and not re.match(r"^\s*([-*]|\d+\.)\s", lines[i]):
                item.append(lines[i].strip())
                i += 1
            out.append(f"<li>{inline(' '.join(item))}</li>")
            continue

        if re.match(r"^-{3,}$", stripped):
            flush_para()
            close_list()
            i += 1
            continue

        para.append(stripped)
        i += 1

    flush_para()
    close_list()
    if in_code:
        out.append("</code></pre>")
    return "\n".join(out), toc


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    title = "Reference"
    if "--title" in sys.argv:
        title = sys.argv[sys.argv.index("--title") + 1]

    body, toc = convert(src.read_text(encoding="utf-8"))
    toc_html = ""
    if toc:
        items = "".join(f'<li><a href="#{a}">{t}</a></li>' for a, t in toc)
        toc_html = f'<nav class="toc"><strong>Sur cette page</strong><ul>{items}</ul></nav>'

    # the first h1 already carries the title; drop the duplicate heading text
    page = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
{toc_html}
{body}
<footer>Généré depuis <code>{html.escape(src.name)}</code> — ne pas éditer cette page,
éditer le Markdown et relancer <code>scripts/build_docs.py</code>.</footer>
</div>
</body>
</html>
"""
    dst.write_text(page, encoding="utf-8")
    print(f"{dst}  ({dst.stat().st_size // 1024} Ko, {len(toc)} sections)")


if __name__ == "__main__":
    main()
