"""Data layer for /html-report: tracker rows, status buckets, outcome.md stages, counts,
funnel and rates, gathered by load() for tools/html_report.jac to render unchanged."""

import collections, csv, datetime, os, re, sys, unicodedata;
import from glob { glob as list_paths }

glob BUCKET: dict[str, str] = {
         "drafted": "Drafted",
         "applied": "Active",
         "interview": "Interview",
         "offer": "Offer",
         "hired": "Hired",
     },
     CLOSED: set[str] = {
         "rejected",
         "no_response",
         "no response",
         "offer_declined",
         "offer declined",
         "withdrawn",
     },
     FIELDS: list[str] = "date company sector role role_type channel status contact_person fit_rating notes cv_file cover_letter_file source deadline".split(),
     STAGES: list[str] = [
         "Application screen",
         "Recruiter screen",
         "Technical round",
         "Case or presentation",
         "Final round",
         "Offer",
         "Hired",
     ],
     STATUS_STAGE: dict[str, int] = {
         "interview": 1,
         "offer": 5,
         "offer_declined": 5,
         "offer declined": 5,
         "hired": 6,
     },
     TICK_STAGE: list[tuple[int, str]] = [
         (5, "offer"),
         (4, "final"),
         (3, "case|assessment|presentation"),
         (2, "technical"),
         (1, "phone|screen|recruiter|interview"),
     ],
     INTERVIEW: int = 1,
     OFFER: int = 5,
     HIRED: int = 6,
     STATUS_ORDER: list[str] = [
         "Drafted",
         "Active",
         "Interview",
         "Offer",
         "Hired",
         "Rejected/Closed",
     ];

"""documents/README.md's folder rule: NFC, lowercase, spaces to underscores, only letters,
digits and underscores, runs collapsed, ends trimmed."""
def folder_name(company: str, role: str) -> str {
    name: str = unicodedata.normalize("NFC", f"{company} {role}").lower().replace(" ", "_");
    name = "".join([ch for ch in name if ch.isalnum() or ch == "_"]);
    return re.sub("_+", "_", name).strip("_");
}

"""(start of period, precision) for YYYY, YYYY-MM or YYYY-MM-DD (- or /); None if unparseable,
before 1970 or over a year ahead."""
def when(s: str | None, today: any = None) -> any {
    m: any = re.fullmatch("(\\d{4})(?:[-/](\\d{1,2})(?:[-/](\\d{1,2}))?)?", (s or "").strip());
    if not m {
        return None;
    }
    (y, mo, d) = m.groups() as any;
    try {
        day: any = datetime.date(int(y), int(mo or 1), int(d or 1));
    } except ValueError {
        return None;
    }
    today = today or datetime.date.today();
    if day < datetime.date(1970, 1, 1) or day > today + datetime.timedelta(days=366) {
        return None;
    }
    return (day, "day" if d else "month" if mo else "year");
}

"""The '## Interview stages reached' checklist of an outcome.md, or the whole text without one."""
def stages_section(txt: str) -> str {
    m: any = re.search("^## Interview stages reached[^\\n]*\\n(.*?)(?=^## |\\Z)", txt, re.M | re.S);
    return m.group(1) if m else txt;
}

"""Applications per week (full dates within 12 weeks), else per month, else per year."""
def timeline(sent: list[any], today: any) -> any {
    w: list[any] = [x for x in [when(r["date"], today) for r in sent] if x];
    if not w {
        return ("week", []);
    }
    days: list[any] = [d for (d, _) in w];
    (first, last) = (min(days), max(days));
    end: any = max(last, today);
    if all([p == "day" for (_, p) in w]) and (end - first).days < 12 * 7 {
        start: any = first - datetime.timedelta(days=first.weekday());
        week: any = datetime.timedelta(days=7);
        weeks: list[any] = [start + week * i for i in range((end - start).days // 7 + 1)];
        return ("week", [(wk, sum([wk <= d and d < wk + week for d in days])) for wk in weeks]);
    }
    if all([p != "year" for (_, p) in w]) {
        months: list[any] = [
            datetime.date(m // 12, m % 12 + 1, 1)
            for m in range(first.year * 12 + first.month - 1, last.year * 12 + last.month)
        ];
        return (
            "month",
            [(m, sum([(d.year, d.month) == (m.year, m.month) for d in days])) for m in months],
        );
    }
    return (
        "year",
        [
            (datetime.date(y, 1, 1), sum([d.year == y for d in days]))
            for y in range(first.year, last.year + 1)
        ],
    );
}

def load(path_root: str = ".") -> dict[str, any] {
    path: str = os.path.join(path_root, "job_search_tracker.csv");
    if not os.path.isfile(path) {
        sys.exit(f"{path} not found - /apply creates it with the first application");
    }
    try {
        with open(path, newline="", encoding="utf-8-sig") as fh {
            reader: any = csv.DictReader(fh);
            header: list[str] = [h.strip().lower() for h in reader.fieldnames or []];
            reader.fieldnames = header;
            rows: list[any] = [*reader];
        }
    } except UnicodeDecodeError {
        sys.exit(f"{path} is not UTF-8 text - re-save it as CSV UTF-8");
    }
    if not all([name in header for name in ("company", "role", "status")]) {
        sys.exit(
            f"{path} has no company, role and status columns - re-save it as comma-separated CSV UTF-8",
        );
    }
    for row in rows {
        for h in FIELDS {
            row[h] = row.get(h) or "";
        }
    }
    rows = [r for r in rows if any([r[h].strip() for h in FIELDS])];
    unknown: set[str] = set[str]();
    arch: dict[str, any] = {};
    for d in sorted(list_paths(os.path.join(path_root, "documents/applications/*/"))) {
        f: str = os.path.join(d, "outcome.md");
        try {
            txt: str = open(f, encoding="utf-8").read() if os.path.exists(f) else "";
        } except UnicodeDecodeError {
            sys.exit(f"{f} is not UTF-8 text - re-save it as UTF-8");
        }
        arch.setdefault(folder_name(os.path.basename(os.path.normpath(d)), ""), (d, []))[1].extend([
            (t.lower(), n)
            for (t, n) in re.findall("- \\[( |x|X)\\] (.+)", stages_section(txt))
        ]);
    }
    for row in rows {
        status: str = row["status"].strip().lower();
        if status in BUCKET {
            row["_b"] = BUCKET[status];
        } else {
            if status not in CLOSED {
                unknown.add(status);
            }
            row["_b"] = "Rejected/Closed";
        }
        key: str = folder_name(row["company"], row["role"]);
        row["_a"] = key if key in arch else None;
        ticked: list[str] = [n for (t, n) in arch[key][1] if t == "x"] if row["_a"] else [];
        tick: int = max(
            [
                next(iter([i for (i, pat) in TICK_STAGE if re.search(pat, n, re.I)]), 0)
                for n in ticked
            ],
            default=0,
        );
        row["_stage"] = max(STATUS_STAGE.get(status, 0), tick);
    }
    sent: list[any] = [r for r in rows if r["_b"] != "Drafted"];
    reached: any = lambda (stage: int) -> int { len([r for r in sent if r["_stage"] >= stage]) };
    fun: list[any] = [
        ("Applied", len(sent)),
        ("Interview", reached(INTERVIEW)),
        ("Offer", reached(OFFER)),
        ("Hired", reached(HIRED)),
    ];
    statuses: list[str] = [r["status"].strip().lower() for r in rows];
    rej: int = len([s for s in statuses if s in ("rejected", "no_response", "no response")]);
    final: int = len([s for s in statuses if s in CLOSED or s == "hired"]);
    today: str = datetime.date.today().isoformat();
    return {
        "today": today,
        "rows": rows,
        "sent": sent,
        "counts": collections.Counter([r["_b"] for r in rows]),
        "sector": collections.Counter([r["sector"].strip() or "Unspecified" for r in sent]),
        "channel": collections.Counter([r["channel"].strip() or "other" for r in sent]),
        "timeline": timeline(sent, datetime.date.fromisoformat(today)),
        "funnel": fun,
        "rejected": rej,
        "final": final,
        "rejection_rate": f"{rej / final * 100:.0f}%" if final else "n/a",
        "progress_rate": f"{fun[1][1] / fun[0][1] * 100:.0f}%" if fun[0][1] else "n/a",
        "unknown": unknown,
        "archives": arch,
    };
}
