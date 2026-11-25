impl load_state(path: Path) -> builtins.tuple[builtins.dict, builtins.dict] {
    if not path.is_file() {
        sys.exit(f"{path} not found - run /scrape first");
    }
    try {
        doc: any = json.loads(path.read_text(encoding="utf-8"));
    } except json.JSONDecodeError as exc {
        sys.exit(f"{path} is not valid JSON: {exc}");
    }
    seen: any = doc.get("seen") if isinstance(doc, `dict) and "seen" in doc else doc;
    if not isinstance(seen, `dict) {
        sys.exit(f"{path}: expected an object of job entries");
    }
    for (key, value) in seen.items() {
        if not isinstance(value, `dict) {
            sys.exit(f"{path}: entry is not an object: {key}");
        }
    }
    return (doc, seen);
}

impl save_state(path: Path, doc: builtins.dict) -> None {
    fd: any;
    tmp: any;
    (fd, tmp) = tempfile.mkstemp(dir=`str(path.parent), prefix=".seen_jobs.", suffix=".tmp") as any;
    try {
        fh: any;
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

impl parse_timestamp(value) -> datetime | None {
    if not isinstance(value, `str) {
        return None;
    }
    try {
        parsed: any = datetime.strptime(value.strip(), TIMESTAMP);
    } except ValueError {
        return None;
    }
    return parsed.replace(tzinfo=timezone.utc);
}

impl parse_now(value: builtins.str) -> datetime {
    parsed: any = datetime.fromisoformat(value.replace("Z", "+00:00"));
    return parsed.astimezone(timezone.utc)
        if parsed.tzinfo
        else parsed.replace(tzinfo=timezone.utc);
}

impl parse_iso(value) -> date | None {
    if not isinstance(value, `str) or not ISO.match(value.strip()) {
        return None;
    }
    try {
        return date.fromisoformat(value.strip());
    } except ValueError {
        return None;
    }
}

impl norm(text) -> builtins.str {
    text = unicodedata.normalize("NFC", `str(text or "").casefold());
    return "".join(
        char
        for char in text
        if char.isalnum() or char in "+#" or unicodedata.category(char).startswith("M"),
    );
}

impl tracker_pairs(path: Path) -> builtins.set[builtins.tuple[builtins.str, builtins.str]] {
    if not path.is_file() {
        return set[any]();
    }
    import csv;

    pairs: any = set[any]();
    try {
        fh: any;
        with path.open(encoding="utf-8-sig", newline="") as fh {
            for row in csv.DictReader(fh) {
                company: any;
                role: any;
                (company, role) = (norm(row.get("company")), norm(row.get("role")));
                if company {
                    pairs.add((company, role));
                }
            }
        }
    } except UnicodeDecodeError {
        sys.exit(f"{path} is not UTF-8 text - re-save it as CSV UTF-8");
    }
    return pairs;
}

impl entry_location_verdict(`entry: builtins.dict) -> builtins.str | None {
    verdict: any = `entry.get("location_verdict");
    if verdict {
        return verdict;
    }
    legacy: any = `entry.get("location");
    return legacy if legacy in ("PASS", "FAIL", "FLAG") else None;
}

impl cmd_candidates(args) -> builtins.int {
    _: any;
    seen: any;
    (_, seen) = load_state(args.state) as any;
    excluded: any = tracker_pairs(args.tracker);

    selected: any;
    skipped_tracker: any;
    (selected, skipped_tracker) = ([], 0);
    for (key, `entry) in seen.items() {
        status: any = `entry.get("status");
        if args.all {
            if status == "skipped" {
                continue;
            }
        } elif status not in ("new", "unreachable") {
            continue;
        }
        if (norm(`entry.get("company")), norm(`entry.get("title"))) in excluded {
            skipped_tracker += 1;
            continue;
        }
        if args.focus {
            haystack: any = " ".join(
                [`str(`entry.get("title") or ""), `str(`entry.get("company") or "")]
                    + [`str(b) for b in `entry.get("strengths") or []]
                    + [`str(b) for b in `entry.get("gaps") or []],
            ).lower();
            if args.focus.lower() not in haystack {
                continue;
            }
        }
        selected.append({
            "key": key,
            "title": `entry.get("title"),
            "company": `entry.get("company"),
            "url": `entry.get("url"),
            "portal": `entry.get("portal"),
            "deadline": `entry.get("deadline"),
            "posted_date": `entry.get("posted_date"),
        });
    }

    eligible: any = len(selected);
    if args.limit > 0 {
        selected = selected[:args.limit];
    }
    print(
        json.dumps(
            {
                "eligible": eligible,
                "selected": selected,
                "deferred": max(0, eligible - len(selected)),
                "excluded_by_tracker": skipped_tracker,
                "total_entries": len(seen),
            },
            indent=2,
            ensure_ascii=False,
        ),
    );
    return 0;
}

impl cmd_sweep(args) -> builtins.int {
    doc: any;
    seen: any;
    (doc, seen) = load_state(args.state) as any;
    today: any = args.today;
    exclude: any = {k.strip() for k in (args.exclude or "").split(",") if k.strip()};

    expired: any;
    closing: any;
    unparseable: any;
    checked: any;
    (expired, closing, unparseable, checked) = ([], [], [], 0);
    for (key, `entry) in seen.items() {
        if `entry.get("status") != "ranked" or key in exclude {
            continue;
        }
        checked += 1;
        raw: any = `entry.get("deadline");
        if raw in (None, "") {
            continue;
        }
        parsed: any = parse_iso(raw);
        if parsed is None {
            unparseable.append({"key": key, "portal": `entry.get("portal"), "deadline": raw});
            continue;
        }
        row: any = {
            "key": key,
            "title": `entry.get("title"),
            "company": `entry.get("company"),
            "url": `entry.get("url"),
            "deadline": raw,
        };
        if parsed < today {
            expired.append(row);
        } elif (parsed - today).days <= URGENT_DAYS {
            closing.append(row);
        }
    }

    if args.write and expired {
        for row in expired {
            seen[row["key"]]["status"] = "expired";
        }
        save_state(args.state, doc);
    }

    print(
        json.dumps(
            {
                "swept": checked,
                "newly_expired": expired,
                "closing_soon": sorted(closing, key=lambda (r) -> any { r["deadline"] }),
                "unparseable_deadlines": unparseable,
                "written": `bool(args.write and expired),
            },
            indent=2,
            ensure_ascii=False,
        ),
    );
    return 0;
}

impl overall_score(scores: builtins.dict) -> builtins.int {
    if not isinstance(scores, `dict) {
        raise ValueError("scores must be an object");
    }
    total: any = Fraction(0);
    for (dim, weight) in WEIGHTS.items() {
        value: any = scores.get(dim);
        if isinstance(value, `bool) or not isinstance(value, (`int, `float)) {
            raise ValueError(f"missing or non-numeric score '{dim}'");
        }
        if not 0 <= value <= 100 {
            raise ValueError(f"score '{dim}' must be finite and between 0 and 100");
        }
        total += Fraction(`str(value)) * Fraction(`str(weight));
    }
    return `int(total + Fraction(1, 2));
}

impl band(score: builtins.int) -> builtins.str {
    for (floor, name) in BANDS {
        if score >= floor {
            return name;
        }
    }
    return "Poor Fit";
}

impl cmd_apply(args) -> builtins.int {
    result: any;
    doc: any;
    seen: any;
    (doc, seen) = load_state(args.state) as any;
    today: any = args.today;
    now: any = args.now;
    try {
        results: any = json.loads(Path(args.results).read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        sys.exit(f"cannot read results file {args.results}: {exc}");
    }
    if isinstance(results, `dict) {
        results = results.get("results", []);
    }
    if not isinstance(results, `list) {
        sys.exit("results file must be a JSON array of scoring objects");
    }

    rows: any;
    expired: any;
    unreachable: any;
    gave_up: any;
    errors: any;
    (rows, expired, unreachable, gave_up, errors) = ([], [], [], [], []);
    for result_ in results {
        result = result_;
        if not isinstance(result, `dict) {
            errors.append({"key": None, "error": "result is not an object"});
            continue;
        }
        key: any = result.get("key");
        `entry: any = seen.get(key) if isinstance(key, `str) else None;
        if `entry is None {
            errors.append({"key": key, "error": "no such key in seen_jobs.json"});
            continue;
        }
        status: any = result.get("status", "scored");
        if status not in AGENT_STATUSES {
            errors.append({
                "key": key,
                "error": "unknown status "
                    + format(repr(status), "")
                    + "; expected one of "
                    + format(", ".join(AGENT_STATUSES), ""),
            });
            continue;
        }

        if status == "unreachable" {
            deadline: any = parse_iso(`entry.get("deadline"));
            if deadline is not None and deadline < today {
                `entry["status"] = "expired";
                field: any;
                for field in (*RETRY_FIELDS, "expired_reason") {
                    `entry.pop(field, None);
                }
                expired.append({
                    "key": key,
                    "title": `entry.get("title"),
                    "company": `entry.get("company"),
                    "url": `entry.get("url"),
                });
                continue;
            }

            previous: any = `entry.get("fetch_attempts");
            valid: any = isinstance(previous, `int) and not isinstance(previous, `bool);
            attempts: any = (previous if valid else 0) + 1;
            first: any = parse_timestamp(`entry.get("first_unreachable")) or now;
            error: any = " ".join(`str(result.get("fetch_error") or "").split())[:FETCH_ERROR_MAX];
            `entry["fetch_attempts"] = attempts;
            `entry["first_unreachable"] = first.strftime(TIMESTAMP);
            if error {
                `entry["last_fetch_error"] = error;
            }
            row: any = {
                "key": key,
                "title": `entry.get("title"),
                "company": `entry.get("company"),
                "url": `entry.get("url"),
                "fetch_attempts": attempts,
                "last_fetch_error": `entry.get("last_fetch_error"),
            };
            if attempts >= UNREACHABLE_MAX_ATTEMPTS and now - first >= UNREACHABLE_MIN_SPAN {
                `entry["status"] = "expired";
                `entry["expired_reason"] = "unreachable";
                gave_up.append(row);
            } else {
                `entry["status"] = "unreachable";
                unreachable.append(row);
            }
            continue;
        }

        if status == "expired" {
            `entry["status"] = "expired";
            for field in (*RETRY_FIELDS, "expired_reason") {
                `entry.pop(field, None);
            }
            expired.append({
                "key": key,
                "title": `entry.get("title"),
                "company": `entry.get("company"),
                "url": `entry.get("url"),
            });
            continue;
        }

        try {
            score: any = overall_score(result.get("scores") or {});
        } except ValueError as exc {
            errors.append({"key": key, "error": `str(exc)});
            continue;
        }
        bad_gate: any = next(
            iter([
                f
                for f in ("location_verdict", "language_gate")
                if result.get(f) and result[f] not in GATE_VERDICTS
            ]),
            None,
        );
        if bad_gate {
            errors.append({
                "key": key,
                "error": "unknown "
                    + format(bad_gate, "")
                    + " "
                    + format(repr(result[bad_gate]), "")
                    + "; expected one of "
                    + format(", ".join(GATE_VERDICTS), ""),
            });
            continue;
        }
        parsed: any = parse_iso(result.get("deadline") or `entry.get("deadline"));
        if parsed is not None and parsed < today {
            `entry["status"] = "expired";
            for field in (*RETRY_FIELDS, "expired_reason") {
                `entry.pop(field, None);
            }
            if result.get("deadline") {
                `entry["deadline"] = result["deadline"];
            }
            expired.append({
                "key": key,
                "title": `entry.get("title"),
                "company": `entry.get("company"),
                "url": `entry.get("url"),
            });
            continue;
        }

        legacy: any = entry_location_verdict(`entry);
        if `entry.get("location") in ("PASS", "FAIL", "FLAG") {
            `entry.pop("location", None);
        }
        for field in (*RETRY_FIELDS, "expired_reason") {
            `entry.pop(field, None);
        }
        `entry["status"] = "ranked";
        `entry["rank_score"] = score;
        `entry["rank_verdict"] = band(score);
        `entry["rank_date"] = today.isoformat();
        `entry["location_verdict"] = result.get("location_verdict") or legacy or "PASS";
        `entry["language_gate"] = result.get("language_gate") or "PASS";
        if `entry["language_gate"] == "PASS" {
            `entry.pop("language_note", None);
        } else {
            `entry["language_note"] = result.get("language_note");
        }
        if result.get("deadline") {
            `entry["deadline"] = result["deadline"];
        }
        for field in ("strengths", "gaps") {
            value: any = result.get(field);
            if isinstance(value, `list) {
                `entry[field] = [`str(b) for b in value][:3];
            }
        }
        guard: any = result.get("guard");
        if isinstance(guard, `str) and guard.strip() {
            text: any = guard.strip();
            if text.lower().startswith("posting_guard:") {
                text = text[len("posting_guard:"):].strip();
            }
            `entry["guard"] = "clean" if text.lower().startswith("clean") else text[:200];
        } else {
            `entry.pop("guard", None);
        }

        rows.append({
            "key": key,
            "title": `entry.get("title"),
            "company": `entry.get("company"),
            "location": `entry.get("location"),
            "url": `entry.get("url"),
            "score": score,
            "verdict": `entry["rank_verdict"],
            "location_verdict": `entry["location_verdict"],
            "language_gate": `entry["language_gate"],
            "language_note": `entry.get("language_note"),
            "deadline": `entry.get("deadline"),
            "posted_date": `entry.get("posted_date"),
            "urgent": `bool(
                parsed
                    and (
                        operator.le(today, parsed)
                        and operator.le(parsed, today + timedelta(days=URGENT_DAYS))
                    ),
            ),
            "strengths": `entry.get("strengths", []),
            "gaps": `entry.get("gaps", []),
            "guard": `entry.get("guard"),
        });
    }

    if not args.dry_run {
        save_state(args.state, doc);
    }

    rows.sort(key=lambda (r) -> any { (r["score"], r["urgent"]) }, reverse=True);
    veto: any = lambda (r) -> any {
        operator.eq(r["location_verdict"], "FAIL") or operator.eq(r["language_gate"], "FAIL")
    };
    vetoed: any = [r for r in rows if veto(r)];
    ranked: any = [r for r in rows if not veto(r)];
    print(
        json.dumps(
            {
                "ranked": ranked,
                "vetoed": vetoed,
                "expired": expired,
                "unreachable": unreachable,
                "gave_up": gave_up,
                "errors": errors,
                "written": not args.dry_run,
            },
            indent=2,
            ensure_ascii=False,
        ),
    );
    return 1 if errors else 0;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main -> builtins.int {
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
