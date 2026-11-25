impl E(v: any) -> str {
    return escape(str(v), quote=True);
}

impl iso_date(r: any) -> str {
    w: any = when(r["date"]);
    return w[0].isoformat() if w else "";
}

impl undated(sent: list[any]) -> str {
    n: int = len([r for r in sent if not when(r["date"])]);
    return f" · {n} without a usable date, left out" if n else "";
}

impl unknown_list(d: dict[str, any]) -> str {
    return ", ".join(sorted([s or "(empty)" for s in d["unknown"]]));
}

impl hidden_table(caption: str, pairs: list[any]) -> str {
    body: str = "".join([
        f"<tr><th scope='row'>{E(k)}</th><td>{E(v)}</td></tr>"
        for (k, v) in pairs
    ]);
    return f"<table class='sr-only'><caption>{E(caption)}</caption>{body}</table>";
}

impl hbars(pairs: list[any], total: any = None, var: str = "--accent") -> str {
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

impl over_time(timeline: any) -> any {
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

impl status_mix(counts: any) -> str {
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

impl render(d: dict[str, any]) -> str {
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

impl _force_utf8_output {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main {
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
