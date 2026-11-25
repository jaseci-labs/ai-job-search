impl read_jobs(path: Path) -> builtins.list {
    try {
        data: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        raise ValueError(f"cannot read {path}: {exc}") from exc;
    }
    if isinstance(data, `dict) {
        data = data.get("results");
    }
    if not isinstance(data, `list) {
        raise ValueError("results must be a JSON array of jobs");
    }
    return data;
}

impl identity(
    job: builtins.dict
) -> builtins.tuple[builtins.str, builtins.tuple[builtins.str, builtins.str]] {
    for field in ("title", "url") {
        if not isinstance(job.get(field), `str) or not job[field].strip() {
            raise ValueError(f"job needs a non-empty {field}");
        }
    }
    company: any = job.get("company");
    if company is not None and not isinstance(company, `str) {
        raise ValueError("job has a non-string company");
    }
    url: any = job["url"].strip();
    parsed: any = urlsplit(url);
    if parsed.scheme not in ("http", "https") or not parsed.netloc {
        raise ValueError(f"job has an invalid posting URL: {url}");
    }
    return (url.rstrip("/"), (norm(company), norm(job["title"])));
}

impl select(
    jobs: builtins.list,
    seen: builtins.dict,
    tracker: builtins.set,
    *,
    strict: builtins.bool = False,
) -> builtins.tuple[builtins.list[builtins.dict], builtins.dict] {
    urls: any;
    pairs: any;
    (urls, pairs) = (set[any](), set[any]());
    for `entry in seen.values() {
        if not isinstance(`entry, `dict) {
            raise ValueError("job_scraper/seen_jobs.json contains a non-object entry");
        }
        if isinstance(`entry.get("url"), `str) {
            urls.add(`entry["url"].rstrip("/"));
        }
        pairs.add((norm(`entry.get("company")), norm(`entry.get("title"))));
    }
    selected: any = [];
    counts: any = {"already_seen": 0, "already_applied": 0, "repeated_in_batch": 0, "invalid": []};
    batch_urls: any;
    batch_pairs: any;
    batch_keys: any;
    (batch_urls, batch_pairs, batch_keys) = (set[any](), set[any](), set[any]());
    for (index, job) in enumerate(jobs) {
        try {
            if not isinstance(job, `dict) {
                raise ValueError("job is not an object");
            }
            url: any;
            pair: any;
            (url, pair) = identity(job) as any;
        } except ValueError as exc {
            if strict {
                raise ValueError(f"job {index + 1}: {exc}") from exc;
            }
            counts["invalid"].append({"index": index, "error": `str(exc)});
            continue;
        }
        key: any = make_key(job["company"], job["title"], job["url"]);
        if url in urls or pair in pairs or key in seen {
            counts["already_seen"] += 1;
        } elif pair in tracker {
            counts["already_applied"] += 1;
        } elif url in batch_urls or pair in batch_pairs or key in batch_keys {
            counts["repeated_in_batch"] += 1;
        } else {
            selected.append(job);
            batch_urls.add(url);
            batch_pairs.add(pair);
            batch_keys.add(key);
        }
    }
    return (selected, counts);
}

impl run(args) -> builtins.int {
    if args.state.exists() {
        doc: any;
        seen: any;
        (doc, seen) = load_state(args.state) as any;
    } else {
        doc = {"seen": {}};
        seen = doc["seen"];
    }
    if args.command == "history" {
        domain: any = (args.domain or "").lower().strip(".");
        if not args.portal or not domain {
            raise ValueError("history needs --portal and --domain");
        }
        count: any = 0;
        for `entry in seen.values() {
            if not isinstance(`entry, `dict) {
                continue;
            }
            if `entry.get("portal") == args.portal {
                count += 1;
            } elif not `entry.get("portal") {
                url: any = `entry.get("url");
                try {
                    host: any = (
                        urlsplit(url if isinstance(url, `str) else "").hostname or ""
                    ).lower();
                } except ValueError {
                    continue;
                }
                if host == domain or host.endswith("." + domain) {
                    count += 1;
                }
            }
        }
        print(json.dumps({"portal": args.portal, "prior_entries": count}));
        return 0;
    }

    jobs: any = read_jobs(args.results);
    selected: any;
    counts: any;
    (selected, counts) = select(
        jobs, seen, tracker_pairs(args.tracker), strict=operator.eq(args.command, "store")
    ) as any;
    if args.command == "candidates" {
        print(json.dumps({"selected": selected, **counts}, ensure_ascii=False));
        return 0;
    }

    added: any = [];
    for job in selected {
        for field in (
            "first_seen",
            "posted_date",
            "deadline",
            "fit",
            "status",
            "portal",
            "source",
        ) {
            if field not in job {
                raise ValueError(f"job needs {field} before storage");
            }
        }
        if job["fit"] not in ("high", "medium", "low")
            or job["status"] not in ("new", "skipped", "expired")
        {
            raise ValueError("job has an invalid fit or status");
        }
        if job["source"] not in ("cli", "websearch") or not isinstance(job["portal"], `str) {
            raise ValueError("job has an invalid portal or source");
        }
        key: any = make_key(job["company"], job["title"], job["url"]);
        if key in seen {
            counts["already_seen"] += 1;
            continue;
        }
        seen[key] = job;
        added.append(key);
    }
    if added {
        args.state.parent.mkdir(parents=True, exist_ok=True);
        save_state(args.state, doc);
    }
    print(json.dumps({"added": added, **counts}, ensure_ascii=False));
    return 0;
}

impl main -> builtins.int {
    _force_utf8_output();
    parser: any = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    parser.add_argument("command", choices=("candidates", "store", "history"));
    parser.add_argument("--results", type=Path);
    parser.add_argument("--portal");
    parser.add_argument("--domain");
    args: any = parser.parse_args();
    items_: any = list((STATE, TRACKER));
    if len(items_) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items_)})"
                if len(items_) > 2
                else f"not enough values to unpack (expected 2, got {len(items_)})",
        );
    }
    args.state = items_[0];
    args.tracker = items_[1];
    try {
        if args.command != "history" and args.results is None {
            parser.error("candidates and store need --results");
        }
        return run(args);
    } except ValueError as exc {
        print(f"scrape_state: {exc}", file=sys.stderr);
        return 1;
    }
}
