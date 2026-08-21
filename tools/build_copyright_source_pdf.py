import html
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "发布软件V1.0_源程序鉴别材料.pdf"
HTML_OUTPUT = ROOT / "output" / "pdf" / "发布软件V1.0_源程序鉴别材料.html"
SOURCE_ROOT = Path(
    os.environ.get(
        "FABUSHI_SOURCE_ROOT",
        "/Users/gloriachan/.devspace/worktrees/fabushi-2867ce87",
    )
)
CHROME = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")

SECTIONS = [
    ("frontend/apps/web/src/app/host/host-client.tsx", 1, None),
    ("frontend/apps/web/src/app/host/host.module.css", 1, None),
    ("frontend/apps/web/src/app/host/rich-transcript.tsx", 1, None),
    ("frontend/apps/web/src/lib/mahayana-host/electron-transport.ts", 1, None),
    ("frontend/apps/web/src/lib/mahayana-host/contracts.ts", 1, None),
    ("frontend/apps/web/src/lib/mahayana-host/mock-transport.ts", 1, None),
    ("desktop/electron/main.cjs", 1, None),
    ("third_party/mahayana/mahayana-rs/mahayana-feature-host/src/lib.rs", 1, None),
    ("third_party/mahayana/mahayana-rs/mahayana-host-protocol/src/lib.rs", 1, None),
    ("third_party/mahayana/mahayana-rs/mahayana-host/src/lib.rs", 1, None),
    ("third_party/mahayana/mahayana-rs/mahayana-agent-codex/src/lib.rs", 1, None),
    ("third_party/mahayana/mahayana-rs/mahayana-core/src/lib.rs", 1, None),
]


def collect_rows() -> list[str]:
    rows: list[str] = []
    for relative_path, start, end in SECTIONS:
        path = SOURCE_ROOT / relative_path
        if not path.exists():
            raise FileNotFoundError(f"Missing latest source file: {path}")
        source_lines = path.read_text(encoding="utf-8").splitlines()
        last = len(source_lines) if end is None else min(end, len(source_lines))
        rows.append(f"===== {relative_path} (lines {start}-{last}) =====")
        for index in range(start - 1, last):
            clean = source_lines[index].replace("\t", "    ").replace("\r", "")
            if len(clean) > 126:
                clean = clean[:123] + "..."
            rows.append(f"{index + 1:05d}  {clean}")
    if len(rows) < 3000:
        raise RuntimeError(f"Not enough source rows: {len(rows)}")
    return rows[:3000]


def build_html(rows: list[str]) -> str:
    pages: list[str] = []
    lines_per_page = 50
    total_pages = 60
    for page_number in range(1, total_pages + 1):
        start = (page_number - 1) * lines_per_page
        page_rows = rows[start : start + lines_per_page]
        body = "\n".join(html.escape(row) for row in page_rows)
        pages.append(
            f'''<section class="page">
<header><span>发布软件 V1.0 源程序</span><span>程序鉴别材料</span></header>
<pre>{body}</pre>
<footer><span>广西谛曦人工智能应用软件有限公司</span><span>第 {page_number} 页 / 共 {total_pages} 页</span></footer>
</section>'''
        )
    return f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>发布软件 V1.0 源程序鉴别材料</title>
<style>
@page {{ size:A4; margin:0; }}
* {{ box-sizing:border-box; }}
html,body {{ margin:0; padding:0; background:white; }}
body {{ font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif; color:#111827; }}
.page {{ width:210mm; height:297mm; padding:10mm 12mm 9mm; page-break-after:always; overflow:hidden; position:relative; background:white; }}
.page:last-child {{ page-break-after:auto; }}
header,footer {{ display:flex; justify-content:space-between; align-items:center; color:#5b6573; font-size:8pt; }}
header {{ height:8mm; border-bottom:0.4pt solid #c9d4e2; color:#1f3a5f; }}
footer {{ position:absolute; left:12mm; right:12mm; bottom:6mm; border-top:0.4pt solid #d7dee8; padding-top:2mm; }}
pre {{ margin:4mm 0 0; white-space:pre; overflow:hidden; font-family:Menlo,Monaco,"SFMono-Regular",monospace; font-size:5.8pt; line-height:5.05mm; letter-spacing:-0.05px; }}
</style></head><body>{''.join(pages)}</body></html>'''


def build() -> None:
    rows = collect_rows()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    HTML_OUTPUT.write_text(build_html(rows), encoding="utf-8")
    if not CHROME.exists():
        raise FileNotFoundError(f"Chrome not found: {CHROME}")
    cmd = [
        str(CHROME),
        "--headless=new",
        "--disable-gpu",
        "--allow-file-access-from-files",
        "--no-pdf-header-footer",
        f"--print-to-pdf={OUTPUT}",
        HTML_OUTPUT.as_uri(),
    ]
    subprocess.run(cmd, check=True)
    if not OUTPUT.exists() or OUTPUT.stat().st_size < 100_000:
        raise RuntimeError(f"Source PDF generation failed: {OUTPUT}")
    print(OUTPUT)


if __name__ == "__main__":
    build()
