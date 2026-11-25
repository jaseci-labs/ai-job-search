impl load_state(path: Path) -> tuple[dict[str, any], dict[str, any]] {
    if not path.is_file() {
        sys.exit(f"{path} not found - run /scrape first");
    }
    try {
        doc: any = json.loads(path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError as exc {
        sys.exit(f"{path} is not valid JSON: {exc}");
    }
    seen: any = doc.get("seen") if isinstance(doc, dict) and "seen" in doc else doc;
    if not isinstance(seen, dict) {
        sys.exit(f"{path}: expected an object of job entries");
    }
    for (key, value) in seen.items() {
        if not isinstance(value, dict) {
            sys.exit(f"{path}: entry is not an object: {key}");
        }
    }
    return (doc, seen);
}

impl save_state(path: Path, doc: dict[str, any]) -> None {
    (fd, tmp) = tempfile.mkstemp(dir=str(path.parent), prefix=".seen_jobs.", suffix=".tmp");
    try {
        with os.fdopen(fd, "w", encoding="utf-8") as fh {
            json.dump(doc, fh, indent=2, ensure_ascii=False);
            fh.write("\n");
        }
        os.replace(tmp, path);
    } except BaseException {
        Path(tmp).unlink(missing_ok=True);
        raise;
    }
}

impl parse_timestamp(value: any) -> datetime | None {
    if not isinstance(value, str) {
        return None;
    }
    try {
        return datetime.strptime(value.strip(), TIMESTAMP).replace(tzinfo=timezone.utc);
    } except ValueError {
        return None;
    }
}

impl parse_now(value: str) -> datetime {
    parsed: datetime = datetime.fromisoformat(value.replace("Z", "+00:00"));
    return parsed.astimezone(timezone.utc)
        if parsed.tzinfo
        else parsed.replace(tzinfo=timezone.utc);
}

impl parse_iso(value: any) -> date | None {
    if not isinstance(value, str) or not ISO.match(value.strip()) {
        return None;
    }
    try {
        return date.fromisoformat(value.strip());
    } except ValueError {
        return None;
    }
}

impl norm(text: any) -> str {
    folded: str = unicodedata.normalize("NFC", str(text or "").casefold());
    return "".join(
        char
        for char in folded
        if char.isalnum() or char in "+#" or unicodedata.category(char).startswith("M"),
    );
}

impl tracker_pairs(path: Path) -> set[tuple[str, str]] {
    pairs: set[tuple[str, str]] = set();
    if not path.is_file() {
        return pairs;
    }
    try {
        with path.open(encoding="utf-8-sig", newline="") as fh {
            for row in csv.DictReader(fh) {
                company: str = norm(row.get("company"));
                if company {
                    pairs.add((company, norm(row.get("role"))));
                }
            }
        }
    } except UnicodeDecodeError {
        sys.exit(f"{path} is not UTF-8 text - re-save it as CSV UTF-8");
    }
    return pairs;
}

impl brief(
    key: str, job: dict[str, any], fields: tuple[str, ...] = ("title", "company", "url")
) -> dict[str, any] {
    return {"key": key, **{field: job.get(field) for field in fields}};
}

impl emit(payload: dict[str, any]) -> None {
    print(json.dumps(payload, indent=2, ensure_ascii=False));
}

impl cmd_candidates(args: any) -> int {
    seen: dict[str, any] = load_state(args.state)[1];
    excluded: set[tuple[str, str]] = tracker_pairs(args.tracker);
    selected: list[dict[str, any]] = [];
    skipped_tracker: int = 0;
    for (key, job) in seen.items() {
        status: any = job.get("status");
        if (status == "skipped") if args.all else (status not in ("new", "unreachable")) {
            continue;
        }
        if (norm(job.get("company")), norm(job.get("title"))) in excluded {
            skipped_tracker += 1;
            continue;
        }
        notes: list[any] = [
            job.get("title") or "",
            job.get("company") or "",
            *(job.get("strengths") or []),
            *(job.get("gaps") or []),
        ];
        if args.focus and args.focus.lower() not in " ".join([str(n) for n in notes]).lower() {
            continue;
        }
        selected.append(
            brief(key, job, ("title", "company", "url", "portal", "deadline", "posted_date"))
        );
    }
    eligible: int = len(selected);
    if args.limit > 0 {
        selected = selected[:args.limit];
    }
    emit({
        "eligible": eligible,
        "selected": selected,
        "deferred": eligible - len(selected),
        "excluded_by_tracker": skipped_tracker,
        "total_entries": len(seen),
    });
    return 0;
}

impl cmd_sweep(args: any) -> int {
    (doc, seen) = load_state(args.state);
    exclude: set[str] = {k.strip() for k in (args.exclude or "").split(",") if k.strip()};
    expired: list[dict[str, any]] = [];
    closing: list[dict[str, any]] = [];
    unparseable: list[dict[str, any]] = [];
    checked: int = 0;
    for (key, job) in seen.items() {
        if job.get("status") != "ranked" or key in exclude {
            continue;
        }
        checked += 1;
        raw: any = job.get("deadline");
        if raw in (None, "") {
            continue;
        }
        parsed: date | None = parse_iso(raw);
        if parsed is None {
            unparseable.append(brief(key, job, ("portal", "deadline")));
        } elif parsed < args.today {
            expired.append(brief(key, job, ("title", "company", "url", "deadline")));
        } elif (parsed - args.today).days <= URGENT_DAYS {
            closing.append(brief(key, job, ("title", "company", "url", "deadline")));
        }
    }
    written: bool = bool(args.write and expired);
    if written {
        for row in expired {
            seen[row["key"]]["status"] = "expired";
        }
        save_state(args.state, doc);
    }
    emit({
        "swept": checked,
        "newly_expired": expired,
        "closing_soon": sorted(closing, key=lambda (r: dict[str, any]) -> str { r["deadline"] }),
        "unparseable_deadlines": unparseable,
        "written": written,
    });
    return 0;
}

impl overall_score(scores: any) -> int {
    if not isinstance(scores, dict) {
        raise ValueError("scores must be an object");
    }
    total: Fraction = Fraction(1, 2);
    for (dim, weight) in WEIGHTS.items() {
        value: any = scores.get(dim);
        if isinstance(value, bool) or not isinstance(value, (int, float)) {
            raise ValueError(f"missing or non-numeric score '{dim}'");
        }
        if not 0 <= value <= 100 {
            raise ValueError(f"score '{dim}' must be finite and between 0 and 100");
        }
        total += Fraction(str(value)) * Fraction(str(weight));
    }
    return int(total);
}

impl band(score: int) -> str {
    for (floor, name) in BANDS {
        if score >= floor {
            return name;
        }
    }
    return "Poor Fit";
}

impl record_unreachable(
    key: str, job: dict[str, any], result: dict[str, any], now: datetime
) -> tuple[str, dict[str, any]] {
    previous: any = job.get("fetch_attempts");
    counted: bool = isinstance(previous, int) and not isinstance(previous, bool);
    attempts: int = (previous if counted else 0) + 1;
    first: datetime = parse_timestamp(job.get("first_unreachable")) or now;
    error: str = " ".join(str(result.get("fetch_error") or "").split())[:FETCH_ERROR_MAX];
    job["fetch_attempts"] = attempts;
    job["first_unreachable"] = first.strftime(TIMESTAMP);
    if error {
        job["last_fetch_error"] = error;
    }
    row: dict[str, any] = brief(
        key, job, ("title", "company", "url", "fetch_attempts", "last_fetch_error")
    );
    if attempts >= UNREACHABLE_MAX_ATTEMPTS and now - first >= UNREACHABLE_MIN_SPAN {
        job["status"] = "expired";
        job["expired_reason"] = "unreachable";
        return ("gave_up", row);
    }
    job["status"] = "unreachable";
    return ("unreachable", row);
}

impl record_score(
    key: str,
    job: dict[str, any],
    result: dict[str, any],
    score: int,
    deadline: date | None,
    today: date,
) -> dict[str, any] {
    place: any = job.get("location");
    legacy: any = job.get("location_verdict") or (place if place in GATE_VERDICTS else None);
    for field in (
        *RETRY_FIELDS,
        "expired_reason",
        *(["location"] if place in GATE_VERDICTS else []),
    ) {
        job.pop(field, None);
    }
    job.update({
        "status": "ranked",
        "rank_score": score,
        "rank_verdict": band(score),
        "rank_date": today.isoformat(),
        "location_verdict": result.get("location_verdict") or legacy or "PASS",
        "language_gate": result.get("language_gate") or "PASS",
    });
    if job["language_gate"] == "PASS" {
        job.pop("language_note", None);
    } else {
        job["language_note"] = result.get("language_note");
    }
    if result.get("deadline") {
        job["deadline"] = result["deadline"];
    }
    for field in ("strengths", "gaps") {
        if isinstance(result.get(field), list) {
            job[field] = [str(b) for b in result[field]][:3];
        }
    }
    guard: any = result.get("guard");
    if isinstance(guard, str) and guard.strip() {
        text: str = guard.strip();
        if text.lower().startswith("posting_guard:") {
            text = text[len("posting_guard:"):].strip();
        }
        job["guard"] = "clean" if text.lower().startswith("clean") else text[:200];
    } else {
        job.pop("guard", None);
    }
    return {
        "key": key,
        "title": job.get("title"),
        "company": job.get("company"),
        "location": job.get("location"),
        "url": job.get("url"),
        "score": score,
        "verdict": job["rank_verdict"],
        "location_verdict": job["location_verdict"],
        "language_gate": job["language_gate"],
        "language_note": job.get("language_note"),
        "deadline": job.get("deadline"),
        "posted_date": job.get("posted_date"),
        "urgent": deadline is not None and (deadline - today).days <= URGENT_DAYS,
        "strengths": job.get("strengths", []),
        "gaps": job.get("gaps", []),
        "guard": job.get("guard"),
    };
}

impl apply_result(
    result: any, seen: dict[str, any], today: date, now: datetime
) -> tuple[str, dict[str, any]] {
    if not isinstance(result, dict) {
        return ("errors", {"key": None, "error": "result is not an object"});
    }
    key: any = result.get("key");
    job: any = seen.get(key) if isinstance(key, str) else None;
    status: any = result.get("status", "scored");
    problem: str = "";
    fresh: any = None;
    if job is None {
        problem = "no such key in seen_jobs.json";
    } elif status not in AGENT_STATUSES {
        problem = f"unknown status {status!r}; expected one of " + ", ".join(AGENT_STATUSES);
    } elif status == "unreachable" {
        stored: date | None = parse_iso(job.get("deadline"));
        if stored is None or stored >= today {
            return record_unreachable(key, job, result, now);
        }
    } elif status == "scored" {
        try {
            score: int = overall_score(result.get("scores") or {});
        } except ValueError as exc {
            return ("errors", {"key": key, "error": str(exc)});
        }
        for field in ("location_verdict", "language_gate") {
            if not problem and result.get(field) and result[field] not in GATE_VERDICTS {
                problem = f"unknown {field} {result[field]!r}; expected one of "
                    + ", ".join(GATE_VERDICTS);
            }
        }
        fresh = result.get("deadline");
        deadline: date | None = parse_iso(fresh or job.get("deadline"));
        if not problem and (deadline is None or deadline >= today) {
            return ("rows", record_score(key, job, result, score, deadline, today));
        }
    }
    if problem {
        return ("errors", {"key": key, "error": problem});
    }
    job["status"] = "expired";
    for field in (*RETRY_FIELDS, "expired_reason") {
        job.pop(field, None);
    }
    if fresh {
        job["deadline"] = fresh;
    }
    return ("expired", brief(key, job));
}

impl cmd_apply(args: any) -> int {
    (doc, seen) = load_state(args.state);
    try {
        results: any = json.loads(Path(args.results).read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        sys.exit(f"cannot read results file {args.results}: {exc}");
    }
    if isinstance(results, dict) {
        results = results.get("results", []);
    }
    if not isinstance(results, list) {
        sys.exit("results file must be a JSON array of scoring objects");
    }
    out: dict[str, list[dict[str, any]]] = {
        name: []
        for name in ("rows", "expired", "unreachable", "gave_up", "errors")
    };
    for result in results {
        (bucket, row) = apply_result(result, seen, args.today, args.now);
        out[bucket].append(row);
    }
    if not args.dry_run {
        save_state(args.state, doc);
    }
    rows: list[dict[str, any]] = out.pop("rows");
    rows.sort(
        key=lambda (r: dict[str, any]) -> tuple[int, bool] { (r["score"], r["urgent"]) },
        reverse=True,
    );
    vetoed: list[dict[str, any]] = [
        r
        for r in rows
        if "FAIL" in (r["location_verdict"], r["language_gate"])
    ];
    emit({
        "ranked": [r for r in rows if r not in vetoed],
        "vetoed": vetoed,
        **out,
        "written": not args.dry_run,
    });
    return 1 if out["errors"] else 0;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main -> int {
    _force_utf8_output();
    common: any = argparse.ArgumentParser(add_help=False);
    common.add_argument("--state", type=Path, default=STATE);
    common.add_argument("--today", type=date.fromisoformat, default=date.today());
    common.add_argument(
        "--now",
        type=parse_now,
        default=datetime.now(timezone.utc),
        help="date-time for the unreachable retry floor (default: now, UTC)",
    );
    ap: any = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    sub: any = ap.add_subparsers(dest="command", required=True);

    cand: any = sub.add_parser("candidates", parents=[common], help="select the entries to score");
    cand.add_argument("--tracker", type=Path, default=TRACKER);
    cand.add_argument("--all", action="store_true", help="include every non-skipped status");
    cand.add_argument("--focus", help="substring filter over title, company and stored fit notes");
    cand.add_argument("--limit", type=int, default=DEFAULT_LIMIT, help="0 for no cap");
    cand.set_defaults(func=cmd_candidates);

    sweep: any = sub.add_parser("sweep", parents=[common], help="rule 6's expiry pass, no fetch");
    sweep.add_argument("--write", action="store_true", help="persist the expiries");
    sweep.add_argument("--exclude", help="comma-separated keys re-scored this run");
    sweep.set_defaults(func=cmd_sweep);

    app: any = sub.add_parser(
        "apply", parents=[common], help="write scoring results back and print the ranking"
    );
    app.add_argument("--results", required=True, help="JSON array from the scoring agents");
    app.add_argument("--dry-run", action="store_true");
    app.set_defaults(func=cmd_apply);

    args: any = ap.parse_args();
    return args.func(args);
}
