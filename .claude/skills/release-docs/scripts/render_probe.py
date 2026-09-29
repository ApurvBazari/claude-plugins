"""render-check helpers.

  scripts PAGE OUT.js            the page's inline, non-JSON scripts joined, for node --check
  inject  PAGE OUT.html MODE     a copy with the probe (MODE=probe) or the light theme (MODE=light)
  read    LOG                    the probe's JSON from a real-time console-log capture
  judge   WIDTH [HEAD]           reads probe JSON on stdin; prints failures (nothing when clean).
                                 HEAD is the scrollWidth of HEAD's copy at WIDTH: an overflow fails
                                 only when HEAD's copy had none or it grew past HEAD's
  width                          reads probe JSON on stdin; prints its scrollWidth (nothing if none)

Deviation from the original design (release-docs spec task 5): the probe was specified to append
its JSON to the DOM and read it back from a `--dump-dom` capture taken after a fixed
`--virtual-time-budget`. On this machine's Chrome (153.0.8010.54), IntersectionObserver's initial
callback does not reliably fire under `--virtual-time-budget` — verified directly (a minimal
observe-and-count probe reports 0 callbacks on a meaningful fraction of runs, and never fires at
all on the real fixture's window geometry across budgets from 4s to 25s). That would make every
"hidden section" check flaky/always-wrong, which is exactly the failure class this tool exists to
catch. Real wall-clock time (no virtual-time-budget) fires IntersectionObserver reliably, so the
probe now runs in real time and reports via `console.log` (captured with `--enable-logging=stderr
--v=1`) instead of a DOM dump; render-check.sh's polling/kill loop (already needed because Chrome
never exits on its own) waits for the console marker instead of a dumped attribute.
"""
import json
import re
import sys

EARLY = ("<script>window.__errs=[];addEventListener('error',function(e){"
         "__errs.push(String(e.message||e))});</script>")
LATE = """<script>setTimeout(function(){
var r={errors:window.__errs.slice(),hidden:[],empty:[],badNav:[],badKeys:[],openErrors:[]};
document.querySelectorAll('section[id]').forEach(function(s){var c=getComputedStyle(s);
 if(parseFloat(c.opacity)<0.5||c.display==='none'||c.visibility==='hidden')r.hidden.push(s.id);
 if(!s.textContent.trim())r.empty.push(s.id);});
document.querySelectorAll('nav a[href^="#"]').forEach(function(a){
 var id=a.getAttribute('href').slice(1);if(id&&!document.getElementById(id))r.badNav.push(id);});
var det=(typeof DET!=='undefined')?DET:null;
var tested={};
document.querySelectorAll('[data-d]').forEach(function(n){var k=n.getAttribute('data-d');
 if(!det||!(k in det)){r.badKeys.push(k);return;}
 tested[k]=1;
 if(typeof openD==='function'){try{openD(k);if(typeof closeD==='function')closeD();}
 catch(e){r.openErrors.push(k+': '+e.message);}}});
if(det&&typeof openD==='function'){Object.keys(det).forEach(function(k){if(tested[k])return;
 try{openD(k);if(typeof closeD==='function')closeD();}
 catch(e){r.openErrors.push(k+': '+e.message);}});}
r.width=window.innerWidth;r.scrollWidth=document.documentElement.scrollWidth;
console.log('RCPROBE:'+JSON.stringify(r)+':ENDPROBE');},2000);</script>"""
LIGHT = "<script>document.documentElement.setAttribute('data-theme','light');</script>"


def scripts(page, out):
    text = open(page, encoding="utf-8").read()
    bodies = [b for attrs, b in re.findall(r"<script([^>]*)>(.*?)</script>", text, re.S)
              if "application/json" not in attrs and "src=" not in attrs]
    open(out, "w", encoding="utf-8").write("\n;\n".join(bodies))


def inject(page, out, mode):
    text = open(page, encoding="utf-8").read()
    early = EARLY if mode == "probe" else ""
    text, n = re.subn(r"(<head[^>]*>)", lambda m: m.group(1) + early, text, count=1)
    if n == 0:
        text = early + text
    tail = LATE if mode == "probe" else LIGHT
    i = text.rfind("</body>")
    text = text[:i] + tail + text[i:] if i >= 0 else text + tail
    open(out, "w", encoding="utf-8").write(text)


def read(log):
    text = open(log, encoding="utf-8", errors="replace").read()
    m = re.search(r"RCPROBE:(.*?):ENDPROBE", text, re.S)
    print(m.group(1) if m else json.dumps({"error": "the probe never reported (load failed or timed out)"}))


def judge(width, base=None):
    r = json.loads(sys.stdin.read() or "{}")
    out = []
    if "error" in r:
        out.append(r["error"])
    if r.get("errors"):
        out.append("uncaught error(s): %s" % "; ".join(r["errors"]))
    if width >= 1000:
        for key, label in (("hidden", "hidden section(s)"), ("empty", "empty section(s)"),
                           ("badNav", "nav link(s) to missing id"), ("badKeys", "data-d key(s) with no DET entry"),
                           ("openErrors", "openD() threw")):
            if r.get(key):
                out.append("%s: %s" % (label, ", ".join(r[key])))
    elif r.get("scrollWidth", 0) > r.get("width", 0) + 1:
        sw, w = r["scrollWidth"], r["width"]
        if base is None:
            out.append("%dpx: horizontal overflow (scrollWidth %d)" % (w, sw))
        elif base <= w + 1:
            out.append("%dpx: horizontal overflow (scrollWidth %d; HEAD's copy had none)" % (w, sw))
        elif sw > base:
            out.append("%dpx: horizontal overflow grew (scrollWidth %d, HEAD's copy %d)" % (w, sw, base))
        # else: HEAD's copy overflowed at least as far, so this is pre-existing, not a failure;
        # render-check.sh reports it as a note.
    print("; ".join(out))


def width():
    r = json.loads(sys.stdin.read() or "{}")
    sw = r.get("scrollWidth")
    if isinstance(sw, int) and "error" not in r:
        print(sw)


if __name__ == "__main__":
    a = sys.argv[1:]
    {"scripts": lambda: scripts(a[1], a[2]), "inject": lambda: inject(a[1], a[2], a[3]),
     "read": lambda: read(a[1]),
     "judge": lambda: judge(int(a[1]), int(a[2]) if len(a) > 2 else None),
     "width": width}[a[0]]()
