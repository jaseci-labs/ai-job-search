impl folder_name(company, role) -> any {
    name: any = unicodedata.normalize("NFC", f"{company} {role}").lower().replace(" ", "_");
    name = "".join(ch for ch in name if ch.isalnum() or ch == "_");
    return re.sub("_+", "_", name).strip("_");
}

impl when(s, today=None) -> any {
    m: any = re.fullmatch("(\\d{4})(?:[-/](\\d{1,2})(?:[-/](\\d{1,2}))?)?", (s or "").strip());
    if not m {
        return None;
    }
    y: any;
    mo: any;
    d: any;
    (y, mo, d) = m.groups() as any;
    try {
        day: any = datetime.date(`int(y), `int(mo or 1), `int(d or 1));
    } except ValueError {
        return None;
    }
    today = today or datetime.date.today();
    if day < datetime.date(1970, 1, 1) or day > today + datetime.timedelta(days=366) {
        return None;
    }
    return (day, "day" if d else "month" if mo else "year");
}

impl stages_section(txt) -> any {
    m: any = re.search("^## Interview stages reached[^\\n]*\\n(.*?)(?=^## |\\Z)", txt, re.M | re.S);
    return m.group(1) if m else txt;
}

impl timeline(sent, today) -> any {
    w: any = [x for x in (when(r["date"], today) for r in sent) if x];
    if not w {
        return ("week", []);
    }
    days: any = [d for (d, _) in w];
    first: any;
    last: any;
    (first, last) = (min(days), max(days));
    if all(operator.eq(p, "day") for (_, p) in w) and (max(last, today) - first).days < 12 * 7 {
        start: any = first - datetime.timedelta(days=first.weekday());
        weeks: any = [
            start + datetime.timedelta(days=7 * i)
            for i in range((max(last, today) - start).days // 7 + 1)
        ];
        return (
            "week",
            [
                (
                    wk,
                    sum([
                        operator.le(wk, d) and operator.lt(d, wk + datetime.timedelta(days=7))
                        for d in days
                    ]),
                )
                for wk in weeks
            ],
        );
    }
    if all(operator.ne(p, "year") for (_, p) in w) {
        months: any = [
            datetime.date(m // 12, m % 12 + 1, 1)
            for m in range(first.year * 12 + first.month - 1, last.year * 12 + last.month)
        ];
        return (
            "month",
            [
                (m, sum([operator.eq((d.year, d.month), (m.year, m.month)) for d in days]))
                for m in months
            ],
        );
    }
    return (
        "year",
        [
            (datetime.date(y, 1, 1), sum([operator.eq(d.year, y) for d in days]))
            for y in range(first.year, last.year + 1)
        ],
    );
}

impl load(`root=".") -> any {
    r: any;
    h: any;
    unknown: any;
    arch: any;
    st: any;
    path: any = os.path.join(`root, "job_search_tracker.csv");
    if not os.path.isfile(path) {
        sys.exit(f"{path} not found - /apply creates it with the first application");
    }
    try {
        fh: any;
        with open(path, newline="", encoding="utf-8-sig") as fh {
            reader: any = csv.DictReader(fh);
            header: any = [h.strip().lower() for h in reader.fieldnames or []];
            reader.fieldnames = header;
            rows: any = `list(reader);
        }
    } except UnicodeDecodeError {
        sys.exit(f"{path} is not UTF-8 text - re-save it as CSV UTF-8");
    }
    if not all(name in header for name in ("company", "role", "status")) {
        sys.exit(
            f"{path} has no company, role and status columns - re-save it as comma-separated CSV UTF-8",
        );
    }
    for r_ in rows {
        r = r_;
        for h in FIELDS {
            r[h] = r.get(h) or "";
        }
    }
    rows = [r for r in rows if `any([r[h].strip() for h in FIELDS])];
    today: any = datetime.date.today().isoformat();
    unknown = set[any]();

    def bucket(s) -> any {
        s = (s or "").strip().lower();
        if s in BUCKET {
            return BUCKET[s];
        }
        if s not in CLOSED {
            unknown.add(s);
        }
        return "Rejected/Closed";
    }
    arch = {};
    for d in sorted(`glob.glob(os.path.join(`root, "documents/applications/*/"))) {
        f: any = os.path.join(d, "outcome.md");
        try {
            txt: any = open(f, encoding="utf-8").read() if os.path.exists(f) else "";
        } except UnicodeDecodeError {
            sys.exit(f"{f} is not UTF-8 text - re-save it as UTF-8");
        }
        arch.setdefault(folder_name(os.path.basename(os.path.normpath(d)), ""), (d, []))[1].extend(
            (t.lower(), n) for (t, n) in re.findall("- \\[( |x|X)\\] (.+)", stages_section(txt))
        );
    }

    def find_arch(r) -> any {
        key: any = folder_name(r["company"], r["role"]);
        return key if key in arch else None;
    }

    for r__ in rows {
        r = r__;
        b: any = bucket(r["status"]);
        r["_b"] = b;
        a: any = find_arch(r);
        r["_a"] = a;
        ticked: any = [n for (t, n) in arch[a][1] if t == "x"] if a else [];
        tick: any = max(
            [
                next(iter([i for (i, pat) in TICK_STAGE if re.search(pat, n, re.I)]), 0)
                for n in ticked
            ],
            default=0,
        );
        r["_stage"] = max(STATUS_STAGE.get(r["status"].strip().lower(), 0), tick);
    }

    sent: any = [r for r in rows if r["_b"] != "Drafted"];
    cnt: any = collections.Counter(r["_b"] for r in rows);
    sector: any = collections.Counter(r["sector"].strip() or "Unspecified" for r in sent);
    channel: any = collections.Counter(r["channel"].strip() or "other" for r in sent);
    fun: any = [
        ("Applied", len(sent)),
        ("Interview", sum(1 for r in sent if r["_stage"] >= INTERVIEW)),
        ("Offer", sum(1 for r in sent if r["_stage"] >= OFFER)),
        ("Hired", sum(1 for r in sent if r["_stage"] >= HIRED)),
    ];
    st = lambda (r) -> any { r["status"].strip().lower() };
    rej: any = sum(1 for r in rows if st(r) in ("rejected", "no_response", "no response"));
    final: any = sum(1 for r in rows if st(r) in CLOSED | {"hired"});
    rate: any = f"{rej / final * 100:.0f}%" if final else "n/a";
    prog: any = f"{fun[1][1] / fun[0][1] * 100:.0f}%" if fun[0][1] else "n/a";
    return {
        "today": today,
        "rows": rows,
        "sent": sent,
        "counts": cnt,
        "sector": sector,
        "channel": channel,
        "timeline": timeline(sent, datetime.date.fromisoformat(today)),
        "funnel": fun,
        "rejected": rej,
        "final": final,
        "rejection_rate": rate,
        "progress_rate": prog,
        "unknown": unknown,
        "archives": arch,
    };
}
