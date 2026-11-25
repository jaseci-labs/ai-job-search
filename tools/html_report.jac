"""Render the /html-report dashboard: one self-contained, offline HTML file.

Figures come from tools/report_data.jac; this module only draws them, with inline SVG and CSS,
system fonts and no network requests.

Usage: neojac run jobsearch -- html_report [--out reports/application-dashboard.html] [--root .]
"""

import argparse, contextlib, datetime, os, sys, tempfile;
import from html { escape }

glob BLANK: str = "<span class='muted' aria-label='empty'>—</span>",
     KEY: dict[str, str] = {
         "Drafted": "drafted",
         "Active": "active",
         "Interview": "interview",
         "Offer": "offer",
         "Hired": "hired",
         "Rejected/Closed": "rejected",
     },
     TEMPLATE: str = "<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>Job search dashboard</title>\n<link rel=\"icon\" href=\"data:,\">\n<style>\n:root {{\n  --font-sans: system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;\n  --font-mono: ui-monospace, 'SF Mono', SFMono-Regular, 'Cascadia Mono', 'Segoe UI Mono', Menlo, Consolas, 'Roboto Mono', monospace;\n  --fs-xs: 12px; --fs-sm: 14px; --fs-md: 16px; --fs-lg: 20px; --fs-xl: 28px; --fs-2xl: 36px;\n  --sp-1: 4px; --sp-2: 8px; --sp-3: 12px; --sp-4: 16px; --sp-5: 24px; --sp-6: 32px; --sp-7: 48px;\n  --r-sm: 6px; --r-md: 10px;\n  --bg: #F6F7F9; --surface: #FFFFFF; --surface-2: #F1F3F6; --border: #E2E6EC;\n  --text: #16202E; --text-muted: #5B6676; --accent: #3E63DD;\n  --st-drafted: #7C8594; --st-active: #3E63DD; --st-interview: #C97A1E; --st-offer: #8E4EC6;\n  --st-hired: #2A9461; --st-rejected: #DC3E42;\n  --tx-drafted: #60646C; --tx-active: #3A5BC7; --tx-interview: #9A5600; --tx-offer: #8145B5;\n  --tx-hired: #1E7A4E; --tx-rejected: #C22D32;\n  --shadow: 0 1px 2px rgba(22, 32, 46, .06);\n  color-scheme: light;\n}}\n@media (prefers-color-scheme: dark) {{\n  :root:not([data-theme=\"light\"]) {{\n    --bg: #0F1217; --surface: #161A21; --surface-2: #1C212A; --border: #2A313C;\n    --text: #E6E9EE; --text-muted: #98A2B3; --accent: #7B93FF;\n    --st-drafted: #8B95A5; --st-active: #7B93FF; --st-interview: #F0A04B; --st-offer: #B184E8;\n    --st-hired: #3DD68C; --st-rejected: #FF6369;\n    --tx-drafted: #B0B4BA; --tx-active: #9EB1FF; --tx-interview: #FFCA16; --tx-offer: #D19DFF;\n    --tx-hired: #3DD68C; --tx-rejected: #FF9592;\n    --shadow: 0 1px 2px rgba(0, 0, 0, .4);\n    color-scheme: dark;\n  }}\n}}\n:root[data-theme=\"dark\"] {{\n  --bg: #0F1217; --surface: #161A21; --surface-2: #1C212A; --border: #2A313C;\n  --text: #E6E9EE; --text-muted: #98A2B3; --accent: #7B93FF;\n  --st-drafted: #8B95A5; --st-active: #7B93FF; --st-interview: #F0A04B; --st-offer: #B184E8;\n  --st-hired: #3DD68C; --st-rejected: #FF6369;\n  --tx-drafted: #B0B4BA; --tx-active: #9EB1FF; --tx-interview: #FFCA16; --tx-offer: #D19DFF;\n  --tx-hired: #3DD68C; --tx-rejected: #FF9592;\n  --shadow: 0 1px 2px rgba(0, 0, 0, .4);\n  color-scheme: dark;\n}}\n* {{ box-sizing: border-box; }}\nhtml {{ scroll-behavior: smooth; scroll-padding-top: 72px; }}\n@media (prefers-reduced-motion: reduce) {{ html {{ scroll-behavior: auto; }} }}\nbody {{ margin: 0; background: var(--bg); color: var(--text); font-family: var(--font-sans);\n  font-size: var(--fs-sm); line-height: 1.5; -webkit-font-smoothing: antialiased; }}\n.num, .kpi-value, table td.num, .val, .tick, .lbl {{ font-family: var(--font-mono); font-variant-numeric: tabular-nums; }}\na {{ color: var(--accent); text-underline-offset: 2px; }}\n:focus-visible {{ outline: 2px solid var(--accent); outline-offset: 2px; border-radius: var(--r-sm); }}\n.muted {{ color: var(--text-muted); }}\n.small {{ font-size: var(--fs-xs); }}\n.sr-only {{ position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; border: 0; }}\n\nheader {{ position: sticky; top: 0; z-index: 10; background: var(--surface); border-bottom: 1px solid var(--border); box-shadow: var(--shadow); }}\n.bar {{ max-width: 1240px; margin: 0 auto; padding: var(--sp-3) var(--sp-5); display: flex; align-items: center; gap: var(--sp-5); flex-wrap: wrap; }}\n.brand {{ display: flex; flex-direction: column; margin-right: auto; }}\n.brand h1 {{ margin: 0; font-size: var(--fs-lg); font-weight: 600; line-height: 1.2; }}\n.brand span {{ font-size: var(--fs-xs); color: var(--text-muted); font-family: var(--font-mono); }}\nnav {{ display: flex; gap: var(--sp-1); }}\nnav a {{ font: inherit; font-size: var(--fs-sm); color: var(--text-muted); text-decoration: none; padding: var(--sp-1) var(--sp-3); border-radius: var(--r-sm); border: 1px solid transparent; }}\nnav a:hover {{ color: var(--text); background: var(--surface-2); }}\n.theme {{ position: relative; display: inline-flex; align-items: center; justify-content: space-between; width: 60px; height: 30px; padding: 0 7px; border: 1px solid var(--border); border-radius: 999px; background: var(--surface-2); color: var(--text-muted); cursor: pointer; }}\n.theme svg {{ position: relative; z-index: 1; width: 16px; height: 16px; transition: color .2s; }}\n.theme::before {{ content: \"\"; position: absolute; top: 2px; left: 2px; width: 24px; height: 24px; border-radius: 50%; background: var(--surface); box-shadow: 0 1px 2px rgba(0,0,0,.2); transition: transform .2s; }}\n.theme .sun {{ color: var(--st-interview); }}\n.theme[aria-checked=\"true\"]::before {{ transform: translateX(30px); }}\n.theme[aria-checked=\"true\"] .sun {{ color: var(--text-muted); }}\n.theme[aria-checked=\"true\"] .moon {{ color: var(--accent); }}\n@media (prefers-reduced-motion: reduce) {{ .theme::before, .theme svg {{ transition: none; }} }}\n\nmain {{ max-width: 1240px; margin: 0 auto; padding: var(--sp-5); display: grid; gap: var(--sp-5); }}\nsection {{ display: grid; gap: var(--sp-4); }}\nh2 {{ margin: 0; font-size: var(--fs-md); font-weight: 600; }}\n.panel {{ background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-md); padding: var(--sp-5); min-width: 0; }}\n.panel header, .panel-head {{ position: static; box-shadow: none; border: 0; background: none; display: flex; justify-content: space-between; align-items: baseline; gap: var(--sp-3); margin-bottom: var(--sp-4); }}\n.panel-head p {{ margin: 0; color: var(--text-muted); font-size: var(--fs-xs); }}\n.grid-2 {{ display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: var(--sp-4); }}\n\n.kpis {{ display: grid; grid-template-columns: repeat(9, minmax(0, 1fr)); background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-md); }}\n.kpi {{ padding: var(--sp-4) var(--sp-5); display: flex; flex-direction: column; gap: var(--sp-2); border-left: 1px solid var(--border); }}\n.kpi:first-child {{ border-left: 0; }}\n.kpi-label {{ font-size: var(--fs-xs); color: var(--text-muted); display: flex; align-items: center; gap: var(--sp-2); }}\n.kpi-value {{ font-size: var(--fs-xl); font-weight: 600; line-height: 1.1; }}\n.sw {{ width: 8px; height: 8px; border-radius: 2px; display: inline-block; flex: none; }}\n\n.chart {{ width: 100%; height: auto; display: block; overflow: visible; }}\n.chart .lbl {{ font-size: 13px; fill: var(--text); }}\n.chart .val {{ font-size: 12px; fill: var(--text-muted); }}\n.chart .tick {{ font-size: 11px; fill: var(--text-muted); }}\n.chart .track {{ fill: var(--surface-2); }}\n.chart .grid {{ stroke: var(--border); stroke-width: 1; }}\n\n.hbars {{ display: grid; grid-template-columns: max-content minmax(0, 1fr) max-content; gap: var(--sp-3) var(--sp-4); align-items: center; }}\n.hb-row {{ display: contents; }}\n.hbars .lbl {{ font-size: 13px; color: var(--text); }}\n.hbars .val {{ font-size: 12px; color: var(--text-muted); text-align: right; min-width: 72px; }}\n.hb-track {{ display: block; height: 16px; border-radius: 4px; background: var(--surface-2); overflow: hidden; }}\n.hb-fill {{ display: block; height: 100%; border-radius: 4px; min-width: 0; }}\n.stack {{ display: flex; height: 16px; border-radius: 4px; overflow: hidden; gap: 2px; background: var(--surface-2); }}\n.seg {{ display: block; height: 100%; min-width: 3px; }}\n.legend {{ list-style: none; padding: 0; margin: var(--sp-4) 0 0; display: grid; gap: var(--sp-2); }}\n.legend li {{ display: grid; grid-template-columns: 8px 1fr auto 48px; align-items: center; gap: var(--sp-3); padding: var(--sp-1) 0; border-bottom: 1px solid var(--border); }}\n.legend li:last-child {{ border-bottom: 0; }}\n.legend .num {{ text-align: right; }}\n\ntable.data {{ width: 100%; border-collapse: collapse; font-size: var(--fs-sm); }}\ntable.data th, table.data td {{ text-align: left; padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--border); vertical-align: top; }}\ntable.data thead th {{ position: sticky; top: 0; background: var(--surface); z-index: 1; font-size: var(--fs-xs); font-weight: 600; color: var(--text-muted); white-space: nowrap; }}\ntable.data tbody tr:hover {{ background: var(--surface-2); }}\ntable.data .right {{ text-align: right; }}\ntable.data td.num {{ white-space: nowrap; }}\ntd.notes {{ color: var(--text-muted); max-width: 360px; }}\n.sort {{ font: inherit; color: inherit; background: none; border: 0; padding: 0; cursor: pointer; display: inline-flex; gap: var(--sp-1); align-items: center; }}\n.sort::after {{ content: '↕'; opacity: .4; font-size: 11px; }}\nth[aria-sort=\"ascending\"] .sort::after {{ content: '↑'; opacity: 1; }}\nth[aria-sort=\"descending\"] .sort::after {{ content: '↓'; opacity: 1; }}\n.table-wrap {{ overflow: auto; max-height: 70vh; border: 1px solid var(--border); border-radius: var(--r-sm); }}\n.badge {{ display: inline-block; padding: 1px var(--sp-2); border-radius: 999px; font-size: var(--fs-xs); font-weight: 600; white-space: nowrap; border: 1px solid currentColor; }}\n.b-drafted {{ color: var(--tx-drafted); background: color-mix(in srgb, var(--st-drafted) 12%, transparent); }}\n.b-active {{ color: var(--tx-active); background: color-mix(in srgb, var(--st-active) 12%, transparent); }}\n.b-interview {{ color: var(--tx-interview); background: color-mix(in srgb, var(--st-interview) 12%, transparent); }}\n.b-offer {{ color: var(--tx-offer); background: color-mix(in srgb, var(--st-offer) 12%, transparent); }}\n.b-hired {{ color: var(--tx-hired); background: color-mix(in srgb, var(--st-hired) 12%, transparent); }}\n.b-rejected {{ color: var(--tx-rejected); background: color-mix(in srgb, var(--st-rejected) 12%, transparent); }}\n\n.filters {{ display: flex; gap: var(--sp-3); flex-wrap: wrap; align-items: center; margin-bottom: var(--sp-4); }}\n.filters label {{ display: flex; flex-direction: column; gap: var(--sp-1); font-size: var(--fs-xs); color: var(--text-muted); }}\n.filters select, .filters input {{ font: inherit; font-size: var(--fs-sm); color: var(--text); background: var(--surface); border: 1px solid var(--border); border-radius: var(--r-sm); padding: var(--sp-2) var(--sp-3); min-width: 180px; }}\n.filters input {{ min-width: 240px; }}\n.count {{ margin-left: auto; font-size: var(--fs-xs); color: var(--text-muted); align-self: flex-end; }}\n.empty {{ color: var(--text-muted); }}\nfooter {{ max-width: 1240px; margin: 0 auto; padding: 0 var(--sp-5) var(--sp-6); color: var(--text-muted); font-size: var(--fs-xs); }}\n\n@media (max-width: 1100px) {{ .kpis {{ grid-template-columns: repeat(3, minmax(0, 1fr)); }} .kpi:nth-child(3n+1) {{ border-left: 0; }} .kpi:nth-child(n+4) {{ border-top: 1px solid var(--border); }} }}\n@media (max-width: 900px) {{ .grid-2 {{ grid-template-columns: 1fr; }} .bar {{ padding: var(--sp-3) var(--sp-4); }} main {{ padding: var(--sp-4); }} }}\n@media (max-width: 560px) {{\n  .kpis {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}\n  .kpi {{ border-left: 0; border-top: 1px solid var(--border); }} .kpi:nth-child(-n+2) {{ border-top: 0; }}\n  .kpi:nth-child(even) {{ border-left: 1px solid var(--border); }}\n  .panel {{ padding: var(--sp-4); }} nav {{ order: 3; width: 100%; }}\n  .chart .val {{ font-size: 18px; }} .chart .tick {{ font-size: 18px; }}\n  .hbars .lbl {{ font-size: 12px; }}\n  .filters select, .filters input {{ min-width: 0; width: 100%; }} .filters label {{ flex: 1 1 100%; }}\n}}\n</style>\n</head>\n<body>\n<header>\n  <div class=\"bar\">\n    <div class=\"brand\"><h1>Job search</h1><span>Updated {today}</span></div>\n    <nav aria-label=\"Sections\"><a href=\"#overview\">Overview</a><a href=\"#pipeline\">Pipeline</a><a href=\"#applications\">Applications</a></nav>\n    <button class=\"theme\" id=\"theme\" type=\"button\" role=\"switch\" aria-checked=\"false\" aria-label=\"Dark theme\">\n      <svg class=\"sun\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"4\"/><path d=\"M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4\"/></svg>\n      <svg class=\"moon\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\"><path d=\"M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z\"/></svg>\n    </button>\n  </div>\n</header>\n<main>\n  <section id=\"overview\" aria-labelledby=\"h-overview\">\n    <h2 id=\"h-overview\" class=\"sr-only\">Overview</h2>\n    <div class=\"kpis\">{kpis}</div>\n    {unknown}\n  </section>\n\n  <section id=\"pipeline\" aria-labelledby=\"h-pipeline\">\n    <h2 id=\"h-pipeline\">Pipeline</h2>\n    <div class=\"grid-2\">\n      <div class=\"panel\">\n        <div class=\"panel-head\"><h3 class=\"h3\">Funnel</h3><p>{interviews} of {sent} sent reached an interview stage</p></div>\n        {funnel}{funnel_table}\n      </div>\n      <div class=\"panel\">\n        <div class=\"panel-head\"><h3 class=\"h3\">Status mix</h3><p>All rows, including drafts</p></div>\n        {mix}\n      </div>\n      <div class=\"panel\">\n        <div class=\"panel-head\"><h3 class=\"h3\">Applications over time</h3><p>Sent, per {unit}</p></div>\n        {week}{week_table}\n      </div>\n      <div class=\"panel\">\n        <div class=\"panel-head\"><h3 class=\"h3\">Where closed applications stopped</h3><p>{closed} closed</p></div>\n        {stopped}{stopped_table}\n      </div>\n      <div class=\"panel\">\n        <div class=\"panel-head\"><h3 class=\"h3\">By sector</h3><p>Sent, top 8</p></div>\n        {sector}{sector_table}\n      </div>\n      <div class=\"panel\">\n        <div class=\"panel-head\"><h3 class=\"h3\">By channel</h3><p>Sent</p></div>\n        {channel}{channel_table}\n      </div>\n    </div>\n    <div class=\"panel\">\n      <div class=\"panel-head\"><h3 class=\"h3\">Waiting longest for a reply</h3><p>Follow-up candidates</p></div>\n      <div class=\"table-wrap\" style=\"max-height:none\">\n        <table class=\"data\"><thead><tr><th scope=\"col\">Company</th><th scope=\"col\">Role</th><th scope=\"col\" class=\"right\">Days waiting</th></tr></thead>\n        <tbody>{wait_rows}</tbody></table>\n      </div>\n    </div>\n  </section>\n\n  <section id=\"applications\" aria-labelledby=\"h-apps\">\n    <div class=\"panel\">\n      <div class=\"panel-head\"><h2 id=\"h-apps\">Applications</h2><p>Newest first</p></div>\n      <div class=\"filters\">\n        <label>Status<select id=\"f-status\"><option value=\"\">All statuses</option>{status_opts}</select></label>\n        <label>Sector<select id=\"f-sector\"><option value=\"\">All sectors</option>{sector_opts}</select></label>\n        <label>Search<input id=\"f-q\" type=\"search\" placeholder=\"Company, role or sector\"></label>\n        <span class=\"count\" id=\"count\" aria-live=\"polite\">{total} of {total}</span>\n      </div>\n      <div class=\"table-wrap\">\n        <table class=\"data\" id=\"apps\">\n          <thead><tr>{thead}          </tr></thead>\n          <tbody>{rows}</tbody>\n        </table>\n      </div>\n    </div>\n  </section>\n</main>\n<footer>Generated by Claude Code from job_search_tracker.csv on {iso}.</footer>\n<script>\n(function () {{\n  var root = document.documentElement, btn = document.getElementById('theme');\n  function isDark() {{\n    var t = root.getAttribute('data-theme');\n    return t ? t === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;\n  }}\n  try {{ var saved = localStorage.getItem('dash-theme'); if (saved) root.setAttribute('data-theme', saved); }} catch (e) {{}}\n  btn.setAttribute('aria-checked', String(isDark()));\n  btn.addEventListener('click', function () {{\n    var next = isDark() ? 'light' : 'dark';\n    root.setAttribute('data-theme', next);\n    btn.setAttribute('aria-checked', String(next === 'dark'));\n    try {{ localStorage.setItem('dash-theme', next); }} catch (e) {{}}\n  }});\n\n  var tbody = document.querySelector('#apps tbody'), rows = Array.prototype.slice.call(tbody.rows);\n  var fs = document.getElementById('f-status'), fc = document.getElementById('f-sector'), fq = document.getElementById('f-q');\n  var count = document.getElementById('count');\n  function filter() {{\n    var q = fq.value.trim().toLowerCase(), shown = 0;\n    rows.forEach(function (r) {{\n      var ok = (!fs.value || r.dataset.status === fs.value) && (!fc.value || r.dataset.sector === fc.value)\n        && (!q || r.dataset.text.indexOf(q) !== -1);\n      r.hidden = !ok; if (ok) shown++;\n    }});\n    count.textContent = shown + ' of ' + rows.length;\n  }}\n  [fs, fc, fq].forEach(function (el) {{ el.addEventListener('input', filter); }});\n\n  document.querySelectorAll('#apps .sort').forEach(function (b) {{\n    b.addEventListener('click', function () {{\n      var th = b.parentElement, col = +b.dataset.col;\n      var dir = th.getAttribute('aria-sort') === 'ascending' ? 'descending' : 'ascending';\n      document.querySelectorAll('#apps th').forEach(function (h) {{ h.removeAttribute('aria-sort'); }});\n      th.setAttribute('aria-sort', dir);\n      rows.sort(function (a, c) {{\n        var x = a.cells[col].dataset.v || '', y = c.cells[col].dataset.v || '';\n        return (x < y ? -1 : x > y ? 1 : 0) * (dir === 'ascending' ? 1 : -1);\n      }});\n      rows.forEach(function (r) {{ tbody.appendChild(r); }});\n    }});\n  }});\n}})();\n</script>\n</body>\n</html>\n";

def E(v: any) -> str {
    return escape(str(v), quote=True);
}

"""Chronological sort key: 2026-9-30 sorts before 2026-10-01."""
def iso_date(r: any) -> str {
    w: any = when(r["date"]);
    return w[0].isoformat() if w else "";
}

def undated(sent: list[any]) -> str {
    n: int = len([r for r in sent if not when(r["date"])]);
    return f" · {n} without a usable date, left out" if n else "";
}

def unknown_list(d: dict[str, any]) -> str {
    return ", ".join(sorted([s or "(empty)" for s in d["unknown"]]));
}

def hidden_table(caption: str, pairs: list[any]) -> str {
    body: str = "".join([
        f"<tr><th scope='row'>{E(k)}</th><td>{E(v)}</td></tr>"
        for (k, v) in pairs
    ]);
    return f"<table class='sr-only'><caption>{E(caption)}</caption>{body}</table>";
}

"""Horizontal bar chart drawn with CSS; pairs are (label, value)."""
def hbars(pairs: list[any], total: any = None, var: str = "--accent") -> str {
    mx: any = max([v for (_, v) in pairs] or [1]) or 1;
    label: str = ", ".join([f"{k} {v}" for (k, v) in pairs]);
    rows: list[str] = [];
    for (k, v) in pairs {
        pct: str = f" · {v / total * 100:.0f}%" if total else "";
        rows.append(
            f"<div class='hb-row'><span class='lbl'>{E(k)}</span><span class='hb-track'><span class='hb-fill' style='width:{v / mx * 100:.1f}%;background:var({var})'></span></span><span class='val'>{v}{pct}</span></div>",
        );
    }
    return f"<div class='hbars' role='img' aria-label='{E(label)}'>{''.join(rows)}</div>";
}

def over_time(timeline: any) -> any {
    (unit, pairs) = timeline as any;
    if not pairs {
        return ("<p class='empty'>No dated applications yet.</p>", []);
    }
    fmt: str = {"week": "%d %b", "month": "%b %Y", "year": "%Y"}[unit];
    name: any = (lambda (p: any) -> str { f"Week of {p:%d %b %Y}" })
        if unit == "week"
        else lambda (p: any) -> str { format(p, fmt) };
    mx: int = max([c for (_, c) in pairs]) or 1;
    (width, h, base, left) = (520, 180, 150, 28);
    col: float = (width - left) / len(pairs);
    bw: float = min(col * 0.62, 34);
    step: int = -(-len(pairs) // 7);
    label: str = E(", ".join([f"{name(p)} {c}" for (p, c) in pairs]));
    parts: list[str] = [
        f"<svg class='chart' viewBox='0 0 {width} {h}' role='img' aria-label='Applications per {unit}: {label}'>",
    ];
    for g in (0, 0.5, 1) {
        y: float = base - (base - 12) * g;
        parts.append(
            f"<line x1='{left}' x2='{width}' y1='{y:.1f}' y2='{y:.1f}' class='grid'/><text x='{left - 6}' y='{y + 4:.1f}' class='tick' text-anchor='end'>{round(mx * g)}</text>",
        );
    }
    for (i, (p, c)) in enumerate(pairs) {
        x: float = left + i * col + (col - bw) / 2;
        bh: float = (base - 12) * c / mx;
        parts.append(
            f"<rect x='{x:.1f}' y='{base - bh:.1f}' width='{bw:.1f}' height='{bh:.1f}' rx='3' style='fill:var(--st-active)'><title>{E(name(p))}: {c}</title></rect>",
        );
        if c {
            parts.append(
                f"<text x='{x + bw / 2:.1f}' y='{base - bh - 5:.1f}' class='val' text-anchor='middle'>{c}</text>",
            );
        }
        if i % step == 0 {
            parts.append(
                f"<text x='{x + bw / 2:.1f}' y='{base + 18}' class='tick' text-anchor='middle'>{format(p, fmt)}</text>",
            );
        }
    }
    parts.append("</svg>");
    return ("".join(parts), [(name(p), c) for (p, c) in pairs]);
}

def status_mix(counts: any) -> str {
    total: int = sum(counts.values()) or 1;
    (segs, legend) = ([], []);
    for s in [s for s in STATUS_ORDER if counts.get(s, 0)] {
        (v, key) = (counts[s], KEY[s]);
        pct: float = v / total * 100;
        segs.append(
            f"<span class='seg' style='width:{pct:.2f}%;background:var(--st-{key})' title='{E(s)}: {v}'></span>",
        );
        legend.append(
            f"<li><span class='sw' style='background:var(--st-{key})'></span>{E(s)}<span class='num'>{v}</span><span class='muted num'>{pct:.0f}%</span></li>",
        );
    }
    label: str = "Status mix: "
        + ", ".join([f"{counts.get(s, 0)} {s}" for s in STATUS_ORDER if counts.get(s)]);
    return f"<div class='stack' role='img' aria-label='{E(label)}'>{''.join(segs)}</div><ul class='legend'>{''.join(legend)}</ul>";
}

def render(d: dict[str, any]) -> str {
    (rows, sent, counts, fun) = (d["rows"], d["sent"], d["counts"], d["funnel"]);
    today: any = datetime.date.fromisoformat(d["today"]);
    kpis: list[any] = [
        ("Sent", len(sent), ""),
        *[
            (label, counts.get(bucket, 0), KEY[bucket])
            for (label, bucket) in [
                ("Active", "Active"),
                ("Interview", "Interview"),
                ("Offer", "Offer"),
                ("Hired", "Hired"),
                ("Closed", "Rejected/Closed"),
                ("Drafted", "Drafted"),
            ]
        ],
        ("Past CV screen", d["progress_rate"], ""),
        ("Rejection rate", d["rejection_rate"], ""),
    ];
    kpi_html: str = "".join([
        "<div class='kpi'><span class='kpi-label'>"
            + (f"<span class='sw' style='background:var(--st-{k})'></span>" if k else "")
            + f"{E(label)}</span><span class='kpi-value num'>{E(v)}</span></div>"
        for (label, v, k) in kpis
    ]);
    (week_svg, week_pairs) = over_time(d["timeline"]) as any;
    closed: list[any] = [r for r in rows if r["_b"] == "Rejected/Closed"];
    stop_counts: list[any] = [
        (s, len([r for r in closed if r["_stage"] == i]))
        for (i, s) in enumerate(STAGES[:-1])
    ];
    top: list[any] = d["sector"].most_common();
    sector_pairs: list[any] = top[:8]
        + (
            [(f"Other ({len(top) - 8} sectors)", sum([v for (_, v) in top[8:]]))]
                if len(top) > 8
                else []
        );
    channel_pairs: list[any] = d["channel"].most_common();
    active: list[any] = [(r, when(r["date"])) for r in rows if r["_b"] == "Active"];
    waiting: list[any] = sorted(
        [a for a in active if a[1]], key=lambda (x: any) -> any { x[1][0] }
    )[:8];
    wait_rows: str = "".join([
        f"<tr><td>{E(r['company'])}</td><td>{E(r['role'])}</td><td class='num right'>"
            + E(max((today - dt).days, 0) if p == "day" else "since " + r["date"].strip())
            + "</td></tr>"
        for (r, (dt, p)) in waiting
    ]);
    no_date: int = len([a for a in active if not a[1]]);
    if no_date {
        verb: str = "s have" if no_date > 1 else " has";
        wait_rows += f"<tr><td colspan='3' class='empty'>{no_date} active application{verb} no usable date, so the wait cannot be counted.</td></tr>";
    }
    wait_rows = wait_rows
        or "<tr><td colspan='3' class='empty'>Nothing is waiting on a reply.</td></tr>";
    rows_sorted: list[any] = sorted(
        rows, key=lambda (r: any) -> str { (r["company"] or "").lower() }
    );
    rows_sorted.sort(key=iso_date, reverse=True);
    show_deadline: bool = any([(r.get("deadline") or "").strip() for r in rows]);
    trs: list[str] = [];
    for r in rows_sorted {
        (notes, src, fit, dl) = [
            (r.get(k) or "").strip()
            for k in ("notes", "source", "fit_rating", "deadline")
        ];
        (sector, channel, b) = (
            (r["sector"] or "").strip(),
            (r.get("channel") or "").strip(),
            r["_b"],
        );
        short: str = notes[:90] + ("…" if len(notes) > 90 else "");
        src_cell: str = f"<a href='{E(src)}' rel='noopener noreferrer' target='_blank'>Open</a>"
            if src.lower().startswith(("http://", "https://"))
            else E(src[:24]) or BLANK;
        cells: list[str] = [
            f"<td class='num' data-v='{E(iso_date(r))}'>{E(r['date']) or BLANK}</td>",
            f"<td class='num' data-v='{E(dl)}'>{E(dl) or BLANK}</td>" if show_deadline else "",
            f"<td data-v='{E(r['company'].lower())}'><strong>{E(r['company'])}</strong></td>",
            f"<td data-v='{E(r['role'].lower())}'>{E(r['role'])}</td>",
            f"<td data-v='{E(sector.lower())}'>{E(sector) or BLANK}</td>",
            f"<td data-v='{E(channel.lower())}'>{E(channel) or BLANK}</td>",
            f"<td data-v='{E(b)}'><span class='badge b-{KEY[b]}'>{E(b)}</span></td>",
            f"<td class='num right' data-v='{E(fit.zfill(3) if fit.isdigit() else '')}'>{E(fit) or BLANK}</td>",
            f"<td class='notes' title='{E(notes)}'>{E(short) or BLANK}</td>",
            f"<td>{src_cell}</td>",
        ];
        text: str = E((r["company"] + " " + r["role"] + " " + sector).lower());
        trs.append(
            f"<tr data-status='{E(b)}' data-sector='{E(sector)}' data-text='{text}'>{''.join(cells)}</tr>",
        );
    }
    cols: list[any] = [
        ("Date", True, ""),
        *([("Deadline", True, "")] if show_deadline else []),
        *[(c, True, "") for c in ("Company", "Role", "Sector", "Channel", "Status")],
        ("Fit", True, "right"),
        ("Notes", False, ""),
        ("Source", False, ""),
    ];
    thead: str = "".join([
        "<th scope='col'"
            + (f" class='{cls}'" if cls else "")
            + (" aria-sort='descending'" if i == 0 else "")
            + ">"
            + (f"<button class='sort' data-col='{i}'>{name}</button>" if sortable else name)
            + "</th>"
        for (i, (name, sortable, cls)) in enumerate(cols)
    ]);
    sectors: list[str] = sorted({(r["sector"] or "").strip() for r in rows} - {""});
    unknown: str = "<p class='muted small'>Rejection rate: rejected and no_response ÷ rows with a final outcome (rejected, no_response, offer_declined, withdrawn, hired)."
        + (
            f" Unrecognised status values ({E(unknown_list(d))}) are counted under Closed but left out of the rate."
                if d["unknown"]
                else ""
        )
        + "</p>";
    return TEMPLATE.format(
        today=E(today.strftime("%d %b %Y")),
        iso=E(d["today"]),
        kpis=kpi_html,
        funnel=hbars(fun, total=fun[0][1] or None, var="--st-active"),
        funnel_table=hidden_table("Application funnel", fun),
        mix=status_mix(counts),
        week=week_svg,
        week_table=hidden_table("Applications over time", week_pairs),
        unit=d["timeline"][0] + undated(sent),
        stopped=hbars(stop_counts, total=len(closed) or None, var="--st-rejected"),
        stopped_table=hidden_table("Where closed applications stopped", stop_counts),
        closed=len(closed),
        wait_rows=wait_rows,
        rows="".join(trs),
        total=len(rows),
        sector_opts="".join([f"<option>{E(s)}</option>" for s in sectors]),
        status_opts="".join([f"<option>{E(s)}</option>" for s in STATUS_ORDER]),
        unknown=unknown,
        sent=len(sent),
        interviews=fun[1][1],
        thead=thead,
        sector=hbars(sector_pairs, total=len(sent) or None),
        sector_table=hidden_table("Sent by sector", sector_pairs),
        channel=hbars(channel_pairs, total=len(sent) or None),
        channel_table=hidden_table("Sent by channel", channel_pairs),
    );
}

"""Print a path outside the console code page (cp1252 on Windows pipes) without failing."""
def _force_utf8_output {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

def main {
    _force_utf8_output();
    p: any = argparse.ArgumentParser(description="Render the offline application dashboard.");
    p.add_argument("--root", default=".", help="repo root holding job_search_tracker.csv");
    p.add_argument("--out", default=os.path.join("reports", "application-dashboard.html"));
    a: any = p.parse_args();
    a.out = os.path.expanduser(a.out);
    if not (a.out.lower().endswith(".html") and os.path.realpath(a.out).lower().endswith(".html")) {
        p.error("--out must end in .html (and not be a symlink to another kind of file)");
    }
    data: dict[str, any] = load(a.root);
    html: str = render(data);
    out_dir: str = os.path.dirname(os.path.abspath(a.out));
    os.makedirs(out_dir, exist_ok=True);
    (fd, tmp) = tempfile.mkstemp(suffix=".html", dir=out_dir) as any;
    try {
        with os.fdopen(fd, "w", encoding="utf-8") as f {
            f.write(html);
        }
        os.replace(tmp, a.out);
    } except BaseException {
        with contextlib.suppress(FileNotFoundError) {
            os.unlink(tmp);
        }
        raise;
    }
    c: any = data["counts"];
    tally: str = ", ".join([
        f"{label} {c.get(bucket, 0)}"
        for (label, bucket) in [
            ("drafted", "Drafted"),
            ("active", "Active"),
            ("interview", "Interview"),
            ("offer", "Offer"),
            ("hired", "Hired"),
            ("closed", "Rejected/Closed"),
        ]
    ]);
    extra: str = f"; unrecognised status values: {unknown_list(data)}" if data["unknown"] else "";
    print(
        f"wrote {a.out}: sent {len(data['sent'])}, {tally}, past CV screen {data['progress_rate']}, rejection rate {data['rejection_rate']}{extra}",
    );
}

with entry:__main__ {
    main();
}
