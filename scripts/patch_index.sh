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

# 4. Inject HTML mobile login overlay (before </body>)
if 'zps-login-overlay' not in html:
    LOGIN_HTML = r"""
	<!-- ZPS World HTML Login Overlay — mobile-friendly native inputs -->
	<div id="zps-login-overlay" style="display:none;position:fixed;inset:0;z-index:9999;background:#09090f;align-items:center;justify-content:center;font-family:'Segoe UI','Noto Sans',Arial,sans-serif;">
		<div style="background:#0d0d1a;border:1px solid rgba(232,201,122,0.45);border-radius:14px;padding:32px 28px;width:min(400px,92vw);box-sizing:border-box;display:flex;flex-direction:column;gap:14px;">
			<h2 style="color:#e8c97a;text-align:center;margin:0;font-size:1.55rem;letter-spacing:0.1em;">ZPS World</h2>
			<p style="color:#7777aa;text-align:center;margin:0;font-size:0.85rem;">Đăng nhập bằng domain nội bộ</p>
			<div style="width:100%;height:1px;background:rgba(255,255,255,0.08);"></div>
			<label style="color:#aab0cc;font-size:0.83rem;margin-bottom:-8px;">Domain / Callsign</label>
			<input id="zps-domain" type="text" placeholder="vd: sangvk, hieupt"
				autocomplete="username" autocapitalize="none" autocorrect="off" spellcheck="false"
				style="width:100%;box-sizing:border-box;background:#0a0a18;border:1px solid #2a2a4a;border-radius:8px;color:#e0e0f0;font-size:1.05rem;padding:14px 14px;outline:none;-webkit-tap-highlight-color:transparent;-webkit-appearance:none;">
			<label style="color:#aab0cc;font-size:0.83rem;margin-bottom:-8px;">Mật khẩu</label>
			<input id="zps-password" type="password" placeholder="••••••••"
				autocomplete="current-password"
				style="width:100%;box-sizing:border-box;background:#0a0a18;border:1px solid #2a2a4a;border-radius:8px;color:#e0e0f0;font-size:1.05rem;padding:14px 14px;outline:none;-webkit-tap-highlight-color:transparent;-webkit-appearance:none;">
			<div id="zps-login-err" style="color:#f07878;font-size:0.82rem;text-align:center;min-height:18px;display:none;"></div>
			<button id="zps-login-btn"
				style="width:100%;padding:16px;background:#1a3e78;border:none;border-radius:8px;color:#fff;font-size:1.05rem;font-family:inherit;font-weight:600;cursor:pointer;letter-spacing:0.04em;-webkit-tap-highlight-color:transparent;touch-action:manipulation;margin-top:4px;">
				Vào ZPS World
			</button>
		</div>
	</div>
	<script>
	(function(){
		var overlay=document.getElementById('zps-login-overlay');
		var domainIn=document.getElementById('zps-domain');
		var passIn=document.getElementById('zps-password');
		var errDiv=document.getElementById('zps-login-err');
		var btn=document.getElementById('zps-login-btn');
		var _api='';
		window.zpsShowLogin=function(apiBase,preFill){
			_api=apiBase||'';
			if(preFill)domainIn.value=preFill;
			overlay.style.display='flex';
			setTimeout(function(){(preFill?passIn:domainIn).focus();},200);
		};
		window.zpsHideLogin=function(){overlay.style.display='none';};
		function showErr(m){errDiv.textContent=m;errDiv.style.display='block';}
		async function doLogin(){
			var d=domainIn.value.trim(),p=passIn.value;
			if(!d||!p){showErr('Vui lòng nhập đầy đủ domain và mật khẩu.');return;}
			btn.textContent='Đang đăng nhập…';btn.disabled=true;errDiv.style.display='none';
			try{
				var r=await fetch(_api+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({domain:d,password:p})});
				var data=await r.json();
				if(data.access_token){window._zpsLoginResult=JSON.stringify(data);}
				else{showErr(data.error||'Domain hoặc mật khẩu không đúng.');}
			}catch(e){showErr('Không kết nối được server API.');}
			btn.textContent='Vào ZPS World';btn.disabled=false;
		}
		btn.addEventListener('click',doLogin);
		passIn.addEventListener('keydown',function(e){if(e.key==='Enter')doLogin();});
		domainIn.addEventListener('keydown',function(e){if(e.key==='Enter')passIn.focus();});
	})();
	</script>"""
    html = html.replace('</body>', LOGIN_HTML + '\n\t</body>')

# 5. Inject dynamic floating joystick + pinch-to-zoom (mobile only)
if 'zps-joystick-base' not in html:
    JOYSTICK_HTML = r"""
	<!-- ZPS World Dynamic Joystick + Pinch Zoom — mobile only -->
	<div id="zps-joystick-base" style="display:none;position:fixed;width:120px;height:120px;border-radius:50%;background:rgba(255,255,255,0.12);border:2px solid rgba(255,255,255,0.30);z-index:9998;pointer-events:none;transform:translate(-50%,-50%);">
		<div id="zps-joystick-thumb" style="position:absolute;width:48px;height:48px;border-radius:50%;background:rgba(255,255,255,0.45);top:36px;left:36px;pointer-events:none;"></div>
	</div>
	<script>
	(function(){
		function isMobile(){return('ontouchstart' in window)||navigator.maxTouchPoints>0;}
		if(!isMobile()) return;
		var base=document.getElementById('zps-joystick-base');
		var thumb=document.getElementById('zps-joystick-thumb');
		var baseR=60,thumbR=24,MAX_R=36;
		window._zpsJoystick={x:0,y:0};
		window._zpsPinchZoom=0;
		setTimeout(function(){var c=document.querySelector('canvas');if(c)c.style.touchAction='none';},800);
		var joyId=null,joyActive=false,startX=0,startY=0;
		var pinchId2=null,pinchDist=0;
		var DRAG_THRESHOLD=18;
		function getT(id,list){for(var i=0;i<list.length;i++)if(list[i].identifier===id)return list[i];return null;}
		function activateJoy(ox,oy){
			joyActive=true;
			base.style.left=ox+'px';base.style.top=oy+'px';base.style.display='block';
			thumb.style.left=(baseR-thumbR)+'px';thumb.style.top=(baseR-thumbR)+'px';
		}
		function updateJoy(dx,dy){
			var d=Math.sqrt(dx*dx+dy*dy);
			var nx=dx,ny=dy;
			if(d>MAX_R){nx=dx/d*MAX_R;ny=dy/d*MAX_R;}
			thumb.style.left=(baseR-thumbR+nx)+'px';thumb.style.top=(baseR-thumbR+ny)+'px';
			window._zpsJoystick={x:Math.max(-1,Math.min(1,dx/MAX_R)),y:Math.max(-1,Math.min(1,dy/MAX_R))};
		}
		document.addEventListener('touchstart',function(e){
			if(e.target.closest&&e.target.closest('#zps-login-overlay'))return;
			for(var i=0;i<e.changedTouches.length;i++){
				var t=e.changedTouches[i];
				if(joyId===null){joyId=t.identifier;joyActive=false;startX=t.clientX;startY=t.clientY;}
				else if(pinchId2===null){
					pinchId2=t.identifier;
					var t1=getT(joyId,e.touches);
					if(t1){var dx=t1.clientX-t.clientX,dy=t1.clientY-t.clientY;pinchDist=Math.sqrt(dx*dx+dy*dy);}
					joyActive=false;base.style.display='none';window._zpsJoystick={x:0,y:0};
				}
			}
		},{passive:true});
		document.addEventListener('touchmove',function(e){
			if(e.target.closest&&e.target.closest('#zps-login-overlay'))return;
			var used=false;
			for(var i=0;i<e.changedTouches.length;i++){
				var t=e.changedTouches[i];
				if(t.identifier===joyId&&pinchId2===null){
					var dx=t.clientX-startX,dy=t.clientY-startY;
					if(!joyActive&&Math.sqrt(dx*dx+dy*dy)>DRAG_THRESHOLD)activateJoy(startX,startY);
					if(joyActive){updateJoy(dx,dy);used=true;}
				}else if(pinchId2!==null){
					var t1=getT(joyId,e.touches),t2=getT(pinchId2,e.touches);
					if(t1&&t2){var pdx=t1.clientX-t2.clientX,pdy=t1.clientY-t2.clientY;var d=Math.sqrt(pdx*pdx+pdy*pdy);if(pinchDist>0)window._zpsPinchZoom=(d-pinchDist)/pinchDist;pinchDist=d;used=true;}
				}
			}
			if(used)e.preventDefault();
		},{passive:false});
		document.addEventListener('touchend',function(e){
			for(var i=0;i<e.changedTouches.length;i++){
				var t=e.changedTouches[i];
				if(t.identifier===joyId){joyId=null;joyActive=false;base.style.display='none';window._zpsJoystick={x:0,y:0};}
				else if(t.identifier===pinchId2){pinchId2=null;window._zpsPinchZoom=0;}
			}
		},{passive:true});
		document.addEventListener('touchcancel',function(){
			joyId=null;joyActive=false;pinchId2=null;base.style.display='none';
			window._zpsJoystick={x:0,y:0};window._zpsPinchZoom=0;
		},{passive:true});
	})();
	</script>"""
    html = html.replace('</body>', JOYSTICK_HTML + '\n\t</body>')

html_path.write_text(html, encoding="utf-8")
print("✓ index.html patched with ZPS World loading screen")
PYEOF
