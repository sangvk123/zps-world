#!/bin/bash
# patch_index.sh — Run after every Godot web export to restore custom loading screen
# Usage: ./scripts/patch_index.sh
set -e

HTML="$(dirname "$0")/../backend/public/index.html"

# 1. Replace Godot default #status CSS block with ZPS custom
python3 - <<'PYEOF'
import re, pathlib, sys

html_path = pathlib.Path(__file__).parent.parent / "backend/public/index.html"
html = html_path.read_text(encoding="utf-8")

GODOT_CSS_PAT = re.compile(
    r'#status, #status-splash, #status-progress \{.*?\}'
    r'.*?#status-notice \{.*?\}',
    re.DOTALL
)

ZPS_CSS = """/* ── ZPS World Custom Loading Screen ── */
#status, #status-splash, #status-progress {
\tposition: absolute;
\tleft: 0;
\tright: 0;
}
#status, #status-splash { top: 0; bottom: 0; }

#status {
\tbackground: #09090f;
\tdisplay: flex;
\tflex-direction: column;
\tjustify-content: center;
\talign-items: center;
\tgap: 20px;
\tvisibility: hidden;
\tfont-family: 'Segoe UI', 'Noto Sans', Arial, sans-serif;
}

#status-splash { display: none !important; }

#zps-loading-title {
\tcolor: #e8c97a;
\tfont-size: 2.2rem;
\tfont-weight: 700;
\tletter-spacing: 0.12em;
\ttext-shadow: 0 0 28px rgba(232,201,122,0.40);
}

#zps-loading-sub {
\tcolor: #6677aa;
\tfont-size: 0.82rem;
\tletter-spacing: 0.06em;
}

#zps-bar-wrap {
\twidth: 300px;
\theight: 5px;
\tbackground: rgba(255,255,255,0.07);
\tborder-radius: 3px;
\toverflow: hidden;
}

#zps-bar-fill {
\theight: 100%;
\twidth: 0%;
\tbackground: linear-gradient(90deg, #3a66ee, #e8c97a);
\tborder-radius: 3px;
\ttransition: width 0.25s ease;
}

#status-progress { display: none !important; }

#status-notice {
\tdisplay: none;
\tbackground: #2a0e14;
\tborder-radius: 8px;
\tborder: 1px solid #8b2533;
\tcolor: #e0e0e0;
\tfont-family: 'Segoe UI', Arial, sans-serif;
\tfont-size: 0.85rem;
\tline-height: 1.4;
\tmax-width: 380px;
\tpadding: 1rem 1.4rem;
\ttext-align: center;
}"""

if not GODOT_CSS_PAT.search(html):
    print("WARNING: Godot CSS pattern not found — index.html may already be patched or template changed.")
    sys.exit(0)

html = GODOT_CSS_PAT.sub(ZPS_CSS, html, count=1)

# 2. Replace status div content
GODOT_DIV_PAT = re.compile(
    r'<div id="status">\s*<img[^>]+>\s*<progress[^>]*></progress>\s*<div id="status-notice"></div>\s*</div>'
)
ZPS_DIV = '''<div id="status">
\t\t\t<img id="status-splash" style="display:none" src="index.png" alt="">
\t\t\t<div id="zps-loading-title">ZPS WORLD</div>
\t\t\t<div id="zps-loading-sub">Đang tải...</div>
\t\t\t<div id="zps-bar-wrap"><div id="zps-bar-fill"></div></div>
\t\t\t<progress id="status-progress"></progress>
\t\t\t<div id="status-notice"></div>
\t\t</div>'''

html = GODOT_DIV_PAT.sub(ZPS_DIV, html, count=1)

# 3. Inject progress bar hook into onProgress
PROGRESS_PAT = re.compile(
    r"engine\.startGame\(\{(\s*'onProgress': function \(current, total\) \{.*?)\}\)",
    re.DOTALL
)
def inject_bar(m):
    return (
        "const zpsBar = document.getElementById('zps-bar-fill');\n"
        "\t\tconst zpsSub = document.getElementById('zps-loading-sub');\n"
        "\t\tengine.startGame({\n"
        "\t\t\t'onProgress': function (current, total) {\n"
        "\t\t\t\tif (current > 0 && total > 0) {\n"
        "\t\t\t\t\tconst pct = Math.round(current / total * 100);\n"
        "\t\t\t\t\tif (zpsBar) zpsBar.style.width = pct + '%';\n"
        "\t\t\t\t\tif (zpsSub) zpsSub.textContent = 'Đang tải... ' + pct + '%';\n"
        "\t\t\t\t\tstatusProgress.value = current;\n"
        "\t\t\t\t\tstatusProgress.max = total;\n"
        "\t\t\t\t} else {\n"
        "\t\t\t\t\tif (zpsBar) zpsBar.style.width = '0%';\n"
        "\t\t\t\t\tstatusProgress.removeAttribute('value');\n"
        "\t\t\t\t\tstatusProgress.removeAttribute('max');\n"
        "\t\t\t\t}\n"
        "\t\t\t},"
        "\n\t\t})"
    )

# Only inject if not already done
if 'zpsBar' not in html:
    html = PROGRESS_PAT.sub(inject_bar, html, count=1)

html_path.write_text(html, encoding="utf-8")
print("✓ index.html patched with ZPS World loading screen")
PYEOF
