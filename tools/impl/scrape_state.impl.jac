impl read_jobs(path: Path) -> list[any] {
    try {
        data: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        raise ValueError(f"cannot read {path}: {exc}") from exc;
    }
    if isinstance(data, dict) {
        data = data.get("results");
    }
    if not isinstance(data, list) {
        raise ValueError("results must be a JSON array of jobs");
    }
    return data;
}

impl identity(job: any) -> tuple[str, tuple[str, str]] {
    if not isinstance(job, dict) {
        raise ValueError("job is not an object");
    }
    for field in ("title", "url") {
        if not isinstance(job.get(field), str) or not job[field].strip() {
            raise ValueError(f"job needs a non-empty {field}");
        }
    }
    company: any = job.get("company");
    if company is not None and not isinstance(company, str) {
        raise ValueError("job has a non-string company");
    }
    url: str = job["url"].strip();
    parsed: any = urlsplit(url);
    if parsed.scheme not in ("http", "https") or not parsed.netloc {
        raise ValueError(f"job has an invalid posting URL: {url}");
    }
    return (url.rstrip("/"), (norm(company), norm(job["title"])));
}

impl select(
    jobs: list[any], seen: dict[str, any], tracker: set[tuple[str, str]], *, strict: bool = False
) -> tuple[dict[str, any], dict[str, any]] {
    urls: set[str] = {
        job["url"].rstrip("/")
        for job in seen.values()
        if isinstance(job.get("url"), str)
    };
    pairs: set[tuple[str, str]] = {
        (norm(job.get("company")), norm(job.get("title")))
        for job in seen.values()
    };
    fresh: dict[str, any] = {};
    batch: set[any] = set();
    counts: dict[str, any] = {
        "already_seen": 0,
        "already_applied": 0,
        "repeated_in_batch": 0,
        "invalid": [],
    };
    for (index, job) in enumerate(jobs) {
        try {
            (url, pair) = identity(job);
        } except ValueError as exc {
            if strict {
                raise ValueError(f"job {index + 1}: {exc}") from exc;
            }
            counts["invalid"].append({"index": index, "error": str(exc)});
            continue;
        }
        key: str = make_key(job["company"], job["title"], job["url"]);
        if url in urls or pair in pairs or key in seen {
            counts["already_seen"] += 1;
        } elif pair in tracker {
            counts["already_applied"] += 1;
        } elif url in batch or pair in batch or key in fresh {
            counts["repeated_in_batch"] += 1;
        } else {
            fresh[key] = job;
            batch.update([url, pair]);
        }
    }
    return (fresh, counts);
}

impl on_domain(url: any, domain: str) -> bool {
    try {
        host: str = (urlsplit(url if isinstance(url, str) else "").hostname or "").lower();
    } except ValueError {
        return False;
    }
    return host == domain or host.endswith("." + domain);
}

impl prior_entries(seen: dict[str, any], portal: str, domain: str) -> int {
    return len([
        job
        for job in seen.values()
        if job.get("portal") == portal
            or not job.get("portal") and on_domain(job.get("url"), domain)
    ]);
}

impl check_storable(job: dict[str, any]) -> None {
    for field in STORED_FIELDS {
        if field not in job {
            raise ValueError(f"job needs {field} before storage");
        }
    }
    if job["fit"] not in ("high", "medium", "low")
        or job["status"] not in ("new", "skipped", "expired")
    {
        raise ValueError("job has an invalid fit or status");
    }
    if job["source"] not in ("cli", "websearch") or not isinstance(job["portal"], str) {
        raise ValueError("job has an invalid portal or source");
    }
}

impl run(args: any) -> int {
    seen: dict[str, any] = {};
    doc: dict[str, any] = {"seen": seen};
    if args.state.exists() {
        (doc, seen) = load_state(args.state);
    }
    if args.command == "history" {
        domain: str = (args.domain or "").lower().strip(".");
        if not args.portal or not domain {
            raise ValueError("history needs --portal and --domain");
        }
        print(
            json.dumps({
                "portal": args.portal,
                "prior_entries": prior_entries(seen, args.portal, domain),
            }),
        );
        return 0;
    }
    (fresh, counts) = select(
        read_jobs(args.results), seen, tracker_pairs(args.tracker), strict=args.command == "store"
    );
    if args.command == "candidates" {
        print(json.dumps({"selected": list(fresh.values()), **counts}, ensure_ascii=False));
        return 0;
    }
    for job in fresh.values() {
        check_storable(job);
    }
    if fresh {
        seen.update(fresh);
        args.state.parent.mkdir(parents=True, exist_ok=True);
        save_state(args.state, doc);
    }
    print(json.dumps({"added": list(fresh), **counts}, ensure_ascii=False));
    return 0;
}

impl main -> int {
    _force_utf8_output();
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    parser.add_argument("command", choices=("candidates", "store", "history"));
    parser.add_argument("--results", type=Path);
    parser.add_argument("--portal");
    parser.add_argument("--domain");
    args: any = parser.parse_args();
    (args.state, args.tracker) = (STATE, TRACKER);
    if args.command != "history" and args.results is None {
        parser.error("candidates and store need --results");
    }
    try {
        return run(args);
    } except ValueError as exc {
        print(f"scrape_state: {exc}", file=sys.stderr);
        return 1;
    }
}
