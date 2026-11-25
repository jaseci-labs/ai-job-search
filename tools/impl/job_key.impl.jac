impl slugify(text: builtins.str) -> builtins.str {
    if not text {
        return "";
    }
    decomposed: any = unicodedata.normalize("NFKD", `str(text));
    folded: any = decomposed.translate(_LATIN_FOLD_TABLE);
    ascii_only: any = folded.encode("ascii", "ignore").decode("ascii");
    ascii_only = ascii_only.replace("+", "plus").replace("#", "sharp");
    return _NON_SLUG.sub("-", ascii_only.lower()).strip("-");
}

impl _lost_letters(text: builtins.str) -> builtins.bool {
    if not text {
        return False;
    }
    for ch in unicodedata.normalize("NFKD", `str(text)) {
        if ord(ch) < 128 or not ch.isalpha() {
            continue;
        }
        if not unicodedata.name(ch, "LATIN").startswith("LATIN") {
            return True;
        }
    }
    return False;
}

impl _cap(slug: builtins.str, limit: builtins.int) -> builtins.str {
    if len(slug) <= limit {
        return slug;
    }
    digest: any = hashlib.sha1(slug.encode("utf-8")).hexdigest()[:HASH_LEN];
    return format(slug[:limit].rstrip("-"), "") + "-" + format(digest, "");
}

impl make_key(company: builtins.str, title: builtins.str, url: builtins.str = "") -> builtins.str {
    company_slug: any = _cap(slugify(company), COMPANY_MAX);
    if not company_slug or _lost_letters(company) {
        name: any = unicodedata.normalize("NFC", `str(company or "").strip().casefold());
        digest: any = hashlib.sha1(name.encode("utf-8")).hexdigest()[:HASH_LEN];
        if not name {
            company_slug = "unknown-company";
        } else {
            company_slug = f"{company_slug}-{digest}" if company_slug else f"company-{digest}";
        }
    }
    title_slug: any = _cap(slugify(title), TITLE_MAX);
    if not title_slug or _lost_letters(title) {
        fragment: any = title_slug;
        `match: any = _JOB_ID.search(url or "");
        if `match {
            title_slug = f"{fragment}-{`match.group(1)}" if fragment else `match.group(1);
        } else {
            basis: any = slugify(unicodedata.normalize("NFKD", `str(title or url or "")));
            digest_basis: any = `str(url) if url else `str(title);
            digest = hashlib.sha1(digest_basis.encode("utf-8")).hexdigest()[:HASH_LEN];
            title_slug = f"{fragment}-{digest}" if fragment else basis or f"untitled-{digest}";
        }
    }
    return f"{company_slug}_{title_slug}";
}

impl is_canonical(key: builtins.str) -> builtins.bool {
    return `bool(key) and `bool(_CANONICAL.match(key));
}

impl is_legacy_shape(key: builtins.str) -> builtins.bool {
    return `bool(key)
        and operator.gt(key.count("_"), 1)
        and all(re.fullmatch("[a-z0-9][a-z0-9-]*", part) for part in key.split("_") if part);
}

impl _load_seen(path: Path) -> any {
    try {
        doc: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        print(f"cannot read {path}: {exc}", file=sys.stderr);
        return None;
    }
    seen: any = doc.get("seen", doc) if isinstance(doc, `dict) else doc;
    if not isinstance(seen, `dict) {
        print(f"{path}: expected an object of job entries", file=sys.stderr);
        return None;
    }
    not_objects: any = [k for (k, v) in seen.items() if not isinstance(v, `dict)];
    if not_objects {
        print(f"{path}: entry is not an object: {not_objects[0]}", file=sys.stderr);
        return None;
    }
    bad_url: any = [
        k
        for (k, v) in seen.items()
        if v.get("url") is not None and not isinstance(v["url"], `str)
    ];
    if bad_url {
        print(f"{path}: entry url is not a string: {bad_url[0]}", file=sys.stderr);
        return None;
    }
    return (doc, seen);
}

impl _drifted(seen: builtins.dict) -> builtins.list[builtins.str] {
    return [
        k
        for (k, v) in seen.items()
        if is_canonical(k)
            and k != make_key(v.get("company", ""), v.get("title", ""), v.get("url", ""))
    ];
}

impl _rename_pass(
    seen: builtins.dict
) -> builtins.tuple[builtins.dict[builtins.str, builtins.str], builtins.list[builtins.dict]] {
    target: any = {
        k: make_key(seen[k].get("company", ""), seen[k].get("title", ""), seen[k].get("url", ""))
        for k in _drifted(seen)
    };
    movers: any = `dict(target);
    blocked: builtins.dict[builtins.str, builtins.str] = {};
    changed: any = True;
    while changed {
        changed = False;
        claimed: builtins.set[builtins.str] = set[any]();
        for (old, new) in `list(movers.items()) {
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

impl migrate(path: Path, doc, seen: builtins.dict) -> builtins.dict {
    current: any = `dict(seen);
    migrated: builtins.list[builtins.dict] = [];
    collisions: builtins.list[builtins.dict] = [];
    for _ in range(len(seen) + 1) {
        renames: any;
        (renames, collisions) = _rename_pass(current) as any;
        if not renames {
            break;
        }
        migrated.extend({"old": o, "new": n} for (o, n) in renames.items());
        current = {renames.get(k, k): v for (k, v) in current.items()};
    }
    `report: any = {"migrated": migrated, "migrate_collisions": collisions, "backup": None};
    if not migrated {
        return `report;
    }

    backup: any = path.with_name(f"{path.name}.bak-{datetime.now():%Y%m%d-%H%M%S}");
    shutil.copy2(path, backup);
    `report["backup"] = `str(backup);

    out: any = `dict(doc, seen=current) if isinstance(doc, `dict) and "seen" in doc else current;
    fd: any;
    tmp: any;
    (fd, tmp) = tempfile.mkstemp(
        dir=`str(path.parent), prefix=f".{path.name}.", suffix=".tmp"
    ) as any;
    try {
        fh: any;
        with os.fdopen(fd, "w", encoding="utf-8") as fh {
            json.dump(out, fh, indent=2, ensure_ascii=False);
            fh.write("\n");
        }
        os.replace(tmp, path);
    } except BaseException {
        Path(tmp).unlink(missing_ok=True);
        raise;
    }
    return `report;
}

impl audit(path: Path, do_migrate: builtins.bool = False) -> builtins.int {
    loaded: any = _load_seen(path);
    if loaded is None {
        return 1;
    }
    doc: any;
    seen: any;
    (doc, seen) = loaded as any;

    migration: any = {};
    if do_migrate {
        migration = migrate(path, doc, seen);
        if migration["migrated"] {
            loaded = _load_seen(path);
            if loaded is None {
                return 1;
            }
            (doc, seen) = loaded as any;
        }
    }

    malformed: any = [k for k in seen if not is_canonical(k) and not is_legacy_shape(k)];
    legacy: any = [k for k in seen if is_legacy_shape(k)];
    by_url: builtins.dict[builtins.str, builtins.list[builtins.str]] = {};
    for (key, `entry) in seen.items() {
        url: any = (`entry.get("url") or "").rstrip("/");
        if url {
            by_url.setdefault(url, []).append(key);
        }
    }
    duplicates: any = {u: ks for (u, ks) in by_url.items() if len(ks) > 1};
    drift: any = _drifted(seen);

    print(
        json.dumps(
            {
                "entries": len(seen),
                "malformed_keys": malformed,
                "legacy_three_part_keys": legacy,
                "duplicate_urls": duplicates,
                "keys_not_matching_current_rule": len(drift),
                **migration,
            },
            indent=2,
            ensure_ascii=False,
        ),
    );
    return 1 if malformed or duplicates else 0;
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
    ap: any = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    ap.add_argument("--company");
    ap.add_argument("--title");
    ap.add_argument("--url", default="");
    ap.add_argument("--audit", nargs="?", const=`str(STATE), metavar="STATE_JSON");
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
