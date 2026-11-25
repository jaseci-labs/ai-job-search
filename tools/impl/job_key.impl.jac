impl slugify(text: str) -> str {
    folded: str = unicodedata.normalize("NFKD", str(text or "")).translate(_LATIN_FOLD_TABLE);
    ascii_only: str = folded.encode("ascii", "ignore").decode("ascii");
    return _NON_SLUG.sub("-", ascii_only.replace("+", "plus").replace("#", "sharp").lower()).strip(
        "-"
    );
}

impl _lost_letters(text: str) -> bool {
    return any([
        ord(ch) >= 128 and ch.isalpha() and not unicodedata.name(ch, "LATIN").startswith("LATIN")
        for ch in unicodedata.normalize("NFKD", str(text or ""))
    ]);
}

impl _digest(text: str) -> str {
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:HASH_LEN];
}

impl _cap(slug: str, limit: int) -> str {
    return slug if len(slug) <= limit else f"{slug[:limit].rstrip('-')}-{_digest(slug)}";
}

impl make_key(company: str, title: str, url: str = "") -> str {
    company_slug: str = _cap(slugify(company), COMPANY_MAX);
    if not company_slug or _lost_letters(company) {
        name: str = unicodedata.normalize("NFC", str(company or "").strip().casefold());
        company_slug = f"{company_slug or 'company'}-{_digest(name)}"
            if name
            else "unknown-company";
    }
    title_slug: str = _cap(slugify(title), TITLE_MAX);
    if not title_slug or _lost_letters(title) {
        job_id: any = _JOB_ID.search(url or "");
        ident: str = job_id.group(1) if job_id else _digest(str(url or title));
        if title_slug {
            title_slug = f"{title_slug}-{ident}";
        } else {
            title_slug = ident if job_id else slugify(title or url) or f"untitled-{ident}";
        }
    }
    return f"{company_slug}_{title_slug}";
}

impl is_canonical(key: str) -> bool {
    return bool(key and _CANONICAL.match(key));
}

impl is_legacy_shape(key: str) -> bool {
    return bool(key)
        and key.count("_") > 1
        and all([re.fullmatch(_SLUG, part) for part in key.split("_") if part]);
}

impl _flaw(seen: any) -> str | None {
    if not isinstance(seen, dict) {
        return "expected an object of job entries";
    }
    not_objects: list[str] = [k for (k, v) in seen.items() if not isinstance(v, dict)];
    if not_objects {
        return f"entry is not an object: {not_objects[0]}";
    }
    bad_url: list[str] = [
        k
        for (k, v) in seen.items()
        if v.get("url") is not None and not isinstance(v["url"], str)
    ];
    return f"entry url is not a string: {bad_url[0]}" if bad_url else None;
}

impl _load_seen(path: Path) -> tuple[any, dict[str, any]] | None {
    try {
        doc: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        print(f"cannot read {path}: {exc}", file=sys.stderr);
        return None;
    }
    seen: any = doc.get("seen", doc) if isinstance(doc, dict) else doc;
    flaw: str | None = _flaw(seen);
    if flaw {
        print(f"{path}: {flaw}", file=sys.stderr);
        return None;
    }
    return (doc, seen);
}

impl _drifted(seen: dict[str, any]) -> dict[str, str] {
    current: dict[str, str] = {
        k: make_key(v.get("company", ""), v.get("title", ""), v.get("url", ""))
        for (k, v) in seen.items()
        if is_canonical(k)
    };
    return {k: new for (k, new) in current.items() if new != k};
}

impl _rename_pass(seen: dict[str, any]) -> tuple[dict[str, str], list[dict[str, str]]] {
    movers: dict[str, str] = _drifted(seen);
    blocked: dict[str, str] = {};
    changed: bool = True;
    while changed {
        changed = False;
        claimed: set[str] = set();
        for (old, new) in list(movers.items()) {
            if new in seen and new not in movers or new in claimed {
                blocked[old] = new;
                del movers[old];
                changed = True;
            } else {
                claimed.add(new);
            }
        }
    }
    return (movers, [{"old": o, "new": n} for (o, n) in blocked.items()]);
}

impl migrate(path: Path, doc: any, seen: dict[str, any]) -> dict[str, any] {
    current: dict[str, any] = dict(seen);
    migrated: list[dict[str, str]] = [];
    collisions: list[dict[str, str]] = [];
    for _ in range(len(seen) + 1) {
        (renames, collisions) = _rename_pass(current);
        if not renames {
            break;
        }
        migrated.extend([{"old": o, "new": n} for (o, n) in renames.items()]);
        current = {renames.get(k, k): v for (k, v) in current.items()};
    }
    outcome: dict[str, any] = {
        "migrated": migrated,
        "migrate_collisions": collisions,
        "backup": None,
    };
    if migrated {
        backup: Path = path.with_name(f"{path.name}.bak-{datetime.now():%Y%m%d-%H%M%S}");
        shutil.copy2(path, backup);
        outcome["backup"] = str(backup);
        save_state(
            path, dict(doc, seen=current) if isinstance(doc, dict) and "seen" in doc else current
        );
    }
    return outcome;
}

impl audit(path: Path, do_migrate: bool = False) -> int {
    loaded: tuple[any, dict[str, any]] | None = _load_seen(path);
    migration: dict[str, any] = {};
    if loaded and do_migrate {
        migration = migrate(path, loaded[0], loaded[1]);
        if migration["migrated"] {
            loaded = _load_seen(path);
        }
    }
    if loaded is None {
        return 1;
    }
    seen: dict[str, any] = loaded[1];
    legacy: list[str] = [k for k in seen if is_legacy_shape(k)];
    malformed: list[str] = [k for k in seen if not is_canonical(k) and k not in legacy];
    by_url: dict[str, list[str]] = {};
    for (key, job) in seen.items() {
        url: str = (job.get("url") or "").rstrip("/");
        if url {
            by_url.setdefault(url, []).append(key);
        }
    }
    duplicates: dict[str, list[str]] = {u: ks for (u, ks) in by_url.items() if len(ks) > 1};
    found: dict[str, any] = {
        "entries": len(seen),
        "malformed_keys": malformed,
        "legacy_three_part_keys": legacy,
        "duplicate_urls": duplicates,
        "keys_not_matching_current_rule": len(_drifted(seen)),
        **migration,
    };
    print(json.dumps(found, indent=2, ensure_ascii=False));
    return 1 if malformed or duplicates else 0;
}

impl main -> int {
    _force_utf8_output();
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    ap.add_argument("--company");
    ap.add_argument("--title");
    ap.add_argument("--url", default="");
    ap.add_argument("--audit", nargs="?", const=str(STATE), metavar="STATE_JSON");
    ap.add_argument(
        "--migrate",
        action="store_true",
        help="with --audit: rewrite drifted keys in place (backup first)",
    );
    args: any = ap.parse_args();
    if args.migrate and not args.audit {
        ap.error("--migrate needs --audit");
    }
    if args.audit {
        return audit(Path(args.audit), args.migrate);
    }
    if args.company is None or args.title is None {
        ap.error("give --company and --title, or --audit");
    }
    print(make_key(args.company, args.title, args.url));
    return 0;
}
