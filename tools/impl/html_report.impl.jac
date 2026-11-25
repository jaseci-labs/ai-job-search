impl E(v) -> any {
    return escape(`str(v), quote=True);
}

impl iso_date(r) -> any {
    w: any = when(r["date"]);
    return w[0].isoformat() if w else "";
}

impl undated(sent) -> any {
    n: any = sum(1 for r in sent if not when(r["date"]));
    return f" · {n} without a usable date, left out" if n else "";
}

impl unknown_list(d) -> any {
    return ", ".join(sorted(s or "(empty)" for s in d["unknown"]));
}

impl hidden_table(caption, pairs) -> any {
    body: any = "".join(f"<tr><th scope='row'>{E(k)}</th><td>{E(v)}</td></tr>" for (k, v) in pairs);
    return f"<table class='sr-only'><caption>{E(caption)}</caption>{body}</table>";
}

impl hbars(pairs, total=None, var="--accent") -> any {
    k: any;
    v: any;
    mx: any = max([v for (_, v) in pairs] or [1]) or 1;
    label: any = ", ".join(f"{k} {v}" for (k, v) in pairs);
    rows: any = [];
    for (k, v) in pairs {
        pct: any = f" · {v / total * 100:.0f}%" if total else "";
        width: any = v / mx * 100;
        rows.append(
            f"<div class='hb-row'><span class='lbl'>{E(k)}</span><span class='hb-track'><span class='hb-fill' style='width:{width:.1f}%;background:var({var})'></span></span><span class='val'>{v}{pct}</span></div>",
        );
    }
    return "<div class='hbars' role='img' aria-label='"
        + format(E(label), "")
        + "'>"
        + format("".join(rows), "")
        + "</div>";
}

impl over_time(timeline) -> any {
    fmt: any;
    name: any;
    p: any;
    c: any;
    unit: any;
    pairs: any;
    (unit, pairs) = timeline as any;
    if not pairs {
        return ("<p class='empty'>No dated applications yet.</p>", []);
    }
    fmt = {"week": "%d %b", "month": "%b %Y", "year": "%Y"}[unit];
    name = (lambda (p) -> any { f"Week of {p:%d %b %Y}" })
        if unit == "week"
        else lambda (p) -> any { format(p, format(fmt, "")) };
    mx: any = max(c for (_, c) in pairs) or 1;
    width: any;
    h: any;
    base: any;
    left: any;
    (width, h, base, left) = (520, 180, 150, 28);
    col: any = (width - left) / len(pairs);
    bw: any = min(col * 0.62, 34);
    step: any = -(-len(pairs) // 7);
    parts: any = [
        f"<svg class='chart' viewBox='0 0 {width} {h}' role='img' aria-label='Applications per {unit}: "
            + E(", ".join(f"{name(p)} {c}" for (p, c) in pairs))
            + "'>",
    ];
    for g in (0, 0.5, 1) {
        y: any = base - (base - 12) * g;
        parts.append(
            f"<line x1='{left}' x2='{width}' y1='{y:.1f}' y2='{y:.1f}' class='grid'/><text x='{left - 6}' y='{y + 4:.1f}' class='tick' text-anchor='end'>{round(mx * g)}</text>",
        );
    }
    for (i, (p, c)) in enumerate(pairs) {
        x: any = left + i * col + (col - bw) / 2;
        bh: any = (base - 12) * c / mx;
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
                "<text x='"
                    + format(x + bw / 2, ".1f")
                    + "' y='"
                    + format(base + 18, "")
                    + "' class='tick' text-anchor='middle'>"
                    + format(p, format(fmt, ""))
                    + "</text>",
            );
        }
    }
    parts.append("</svg>");
    return ("".join(parts), [(name(p), c) for (p, c) in pairs]);
}

impl status_mix(counts) -> any {
    total: any = sum(counts.values()) or 1;
    segs: any;
    legend: any;
    (segs, legend) = ([], []);
    for s in STATUS_ORDER {
        v: any = counts.get(s, 0);
        if not v {
            continue;
        }
        pct: any = v / total * 100;
        segs.append(
            f"<span class='seg' style='width:{pct:.2f}%;background:var(--st-{KEY[s]})' title='{E(s)}: {v}'></span>",
        );
        legend.append(
            f"<li><span class='sw' style='background:var(--st-{KEY[s]})'></span>{E(s)}<span class='num'>{v}</span><span class='muted num'>{pct:.0f}%</span></li>",
        );
    }
    label: any = "Status mix: "
        + ", ".join(f"{counts.get(s, 0)} {s}" for s in STATUS_ORDER if counts.get(s));
    return "<div class='stack' role='img' aria-label='"
        + format(E(label), "")
        + "'>"
        + format("".join(segs), "")
        + "</div><ul class='legend'>"
        + format("".join(legend), "")
        + "</ul>";
}

impl render(d) -> any {
    r: any;
    rows: any;
    sent: any;
    counts: any;
    (rows, sent, counts) = (d["rows"], d["sent"], d["counts"]);
    today: any = datetime.date.fromisoformat(d["today"]);
    fun: any = d["funnel"];
    kpis: any = [
        ("Sent", len(sent), ""),
        ("Active", counts.get("Active", 0), "active"),
        ("Interview", counts.get("Interview", 0), "interview"),
        ("Offer", counts.get("Offer", 0), "offer"),
        ("Hired", counts.get("Hired", 0), "hired"),
        ("Closed", counts.get("Rejected/Closed", 0), "rejected"),
        ("Drafted", counts.get("Drafted", 0), "drafted"),
        ("Past CV screen", d["progress_rate"], ""),
        ("Rejection rate", d["rejection_rate"], ""),
    ];
    kpi_html: any = "".join(
        f"<div class='kpi'><span class='kpi-label'>"
            + (f"<span class='sw' style='background:var(--st-{k})'></span>" if k else "")
            + f"{E(label)}</span><span class='kpi-value num'>{E(v)}</span></div>"
        for (label, v, k) in kpis,
    );

    funnel: any = hbars(fun, total=fun[0][1] or None, var="--st-active");
    week_svg: any;
    week_pairs: any;
    (week_svg, week_pairs) = over_time(d["timeline"]) as any;
    closed: any = [r for r in rows if r["_b"] == "Rejected/Closed"];
    stop_counts: any = [
        (s, len([r for r in closed if r["_stage"] == i]))
        for (i, s) in enumerate(STAGES[:-1])
    ];
    stop_svg: any = hbars(stop_counts, total=len(closed) or None, var="--st-rejected");
    top: any = d["sector"].most_common();
    sector_pairs: any = top[:8]
        + (
            [(f"Other ({len(top) - 8} sectors)", sum(v for (_, v) in top[8:]))]
                if len(top) > 8
                else []
        );
    channel_pairs: any = d["channel"].most_common();
    waiting: any = sorted(
        ((r, when(r["date"])) for r in rows if r["_b"] == "Active" and when(r["date"])),
        key=lambda (x) -> any { x[1][0] },
    )[:8];
    waiting = [
        (r, max((today - dt).days, 0) if p == "day" else "since " + format(r["date"].strip(), ""))
        for (r, (dt, p)) in waiting
    ];
    wait_rows: any = "".join(
        "<tr><td>"
            + format(E(r["company"]), "")
            + "</td><td>"
            + format(E(r["role"]), "")
            + "</td><td class='num right'>"
            + format(E(days), "")
            + "</td></tr>"
        for (r, days) in waiting,
    );
    no_date: any = sum(1 for r in rows if r["_b"] == "Active" and not when(r["date"]));
    if no_date {
        wait_rows += "<tr><td colspan='3' class='empty'>"
            + format(no_date, "")
            + " active application"
            + format("s have" if no_date > 1 else " has", "")
            + " no usable date, so the wait cannot be counted.</td></tr>";
    }
    wait_rows = wait_rows
        or "<tr><td colspan='3' class='empty'>Nothing is waiting on a reply.</td></tr>";
    rows_sorted: any = sorted(rows, key=lambda (r) -> any { (r["company"] or "").lower() });
    rows_sorted.sort(key=iso_date, reverse=True);
    show_deadline: any = `any((r.get("deadline") or "").strip() for r in rows);
    trs: any = [];
    for r in rows_sorted {
        notes: any = (r.get("notes") or "").strip();
        short: any = notes[:90] + ("…" if len(notes) > 90 else "");
        src: any = (r.get("source") or "").strip();
        src_cell: any = f"<a href='{E(src)}' rel='noopener noreferrer' target='_blank'>Open</a>"
            if src.lower().startswith(("http://", "https://"))
            else E(src[:24]) or BLANK;
        fit: any = (r.get("fit_rating") or "").strip();
        dl: any = (r.get("deadline") or "").strip();
        sector: any;
        channel: any;
        (sector, channel) = ((r["sector"] or "").strip(), (r.get("channel") or "").strip());
        cells: any = [
            "<td class='num' data-v='"
                + format(E(iso_date(r)), "")
                + "'>"
                + format(E(r["date"]) or BLANK, "")
                + "</td>",
            f"<td class='num' data-v='{E(dl)}'>{E(dl) or BLANK}</td>" if show_deadline else "",
            "<td data-v='"
                + format(E(r["company"].lower()), "")
                + "'><strong>"
                + format(E(r["company"]), "")
                + "</strong></td>",
            "<td data-v='"
                + format(E(r["role"].lower()), "")
                + "'>"
                + format(E(r["role"]), "")
                + "</td>",
            f"<td data-v='{E(sector.lower())}'>{E(sector) or BLANK}</td>",
            f"<td data-v='{E(channel.lower())}'>{E(channel) or BLANK}</td>",
            "<td data-v='"
                + format(E(r["_b"]), "")
                + "'><span class='badge b-"
                + format(KEY[r["_b"]], "")
                + "'>"
                + format(E(r["_b"]), "")
                + "</span></td>",
            "<td class='num right' data-v='"
                + format(E(fit.zfill(3) if fit.isdigit() else ""), "")
                + "'>"
                + format(E(fit) or BLANK, "")
                + "</td>",
            f"<td class='notes' title='{E(notes)}'>{E(short) or BLANK}</td>",
            f"<td>{src_cell}</td>",
        ];
        trs.append(
            "<tr data-status='"
                + format(E(r["_b"]), "")
                + "' data-sector='"
                + format(E(sector), "")
                + "' data-text='"
                + format(E((r["company"] + " " + r["role"] + " " + sector).lower()), "")
                + "'>"
                + "".join(cells)
                + "</tr>",
        );
    }
    cols: any = [
        ("Date", True, ""),
        ("Deadline", True, "") if show_deadline else None,
        ("Company", True, ""),
        ("Role", True, ""),
        ("Sector", True, ""),
        ("Channel", True, ""),
        ("Status", True, ""),
        ("Fit", True, "right"),
        ("Notes", False, ""),
        ("Source", False, ""),
    ];
    cols = [c for c in cols if c];
    thead: any = "".join(
        "<th scope='col'"
            + format(" class=" + repr(cls) if cls else "", "")
            + format(" aria-sort=" + repr("descending") if i == 0 else "", "")
            + ">"
            + (f"<button class='sort' data-col='{i}'>{name}</button>" if sortable else name)
            + "</th>"
        for (i, (name, sortable, cls)) in enumerate(cols),
    );
    sectors: any = sorted({
        (r["sector"] or "").strip()
        for r in rows
        if (r["sector"] or "").strip()
    });
    sector_opts: any = "".join(f"<option>{E(s)}</option>" for s in sectors);
    status_opts: any = "".join(f"<option>{E(s)}</option>" for s in STATUS_ORDER);
    unknown: any = "<p class='muted small'>Rejection rate: rejected and no_response ÷ rows with a final outcome (rejected, no_response, offer_declined, withdrawn, hired)."
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
        funnel=funnel,
        funnel_table=hidden_table("Application funnel", fun),
        mix=status_mix(counts),
        week=week_svg,
        week_table=hidden_table("Applications over time", week_pairs),
        unit=d["timeline"][0] + undated(sent),
        stopped=stop_svg,
        stopped_table=hidden_table("Where closed applications stopped", stop_counts),
        closed=len(closed),
        wait_rows=wait_rows,
        rows="".join(trs),
        total=len(rows),
        sector_opts=sector_opts,
        status_opts=status_opts,
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

impl _force_utf8_output -> any {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main -> any {
    _force_utf8_output();
    p: any = argparse.ArgumentParser(description="Render the offline application dashboard.");
    p.add_argument("--root", default=".", help="repo root holding job_search_tracker.csv");
    p.add_argument("--out", default=os.path.join("reports", "application-dashboard.html"));
    a: any = p.parse_args();
    a.out = os.path.expanduser(a.out);
    if not (a.out.lower().endswith(".html") and os.path.realpath(a.out).lower().endswith(".html")) {
        p.error("--out must end in .html (and not be a symlink to another kind of file)");
    }
    data: any = load(a.root);
    html: any = render(data);
    out_dir: any = os.path.dirname(os.path.abspath(a.out));
    os.makedirs(out_dir, exist_ok=True);
    fd: any;
    tmp: any;
    (fd, tmp) = tempfile.mkstemp(suffix=".html", dir=out_dir) as any;
    try {
        f: any;
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
    print(
        "wrote "
            + format(a.out, "")
            + ": sent "
            + format(len(data["sent"]), "")
            + ", drafted "
            + format(c.get("Drafted", 0), "")
            + ", active "
            + format(c.get("Active", 0), "")
            + ", interview "
            + format(c.get("Interview", 0), "")
            + ", offer "
            + format(c.get("Offer", 0), "")
            + ", hired "
            + format(c.get("Hired", 0), "")
            + ", closed "
            + format(c.get("Rejected/Closed", 0), "")
            + ", past CV screen "
            + format(data["progress_rate"], "")
            + ", rejection rate "
            + format(data["rejection_rate"], "")
            + (f"; unrecognised status values: {unknown_list(data)}" if data["unknown"] else ""),
    );
}
