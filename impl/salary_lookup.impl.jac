impl fail_data_error(message: str) -> None {
    print(f"Error: invalid salary_data.json: {message}\n\n{SETUP_HINT}", file=sys.stderr);
    sys.exit(1);
}

impl collect_validation_issues(data: any) -> tuple[list[str], list[str]] {
    errors: list[str] = [];
    warnings: list[str] = [];
    if not isinstance(data, dict) {
        return (["top-level JSON value must be an object"], warnings);
    }
    metadata: any = data.get("metadata", {});
    if isinstance(metadata, dict) {
        baseline: any = metadata.get("index_baseline", 100);
        try {
            finite: bool = not isinstance(baseline, bool) and math.isfinite(baseline);
        } except (TypeError, OverflowError) {
            finite = False;
        }
        if not finite {
            errors.append("'metadata.index_baseline' must be a finite number");
        }
        if not isinstance(metadata.get("index_label", "Index"), str) {
            errors.append("'metadata.index_label' must be a string");
        }
    } elif metadata is not None {
        errors.append("'metadata' must be an object when provided");
    }
    companies: any = data.get("companies");
    if not isinstance(companies, list) {
        errors.append("'companies' must be a list");
        return (errors, warnings);
    }
    seen: dict[str, int] = {};
    for (i, company) in enumerate(companies, 1) {
        at: str = f"companies[{i}]";
        if not isinstance(company, dict) {
            errors.append(f"{at} must be an object");
            continue;
        }
        name: any = company.get("company");
        if not isinstance(name, str) or not name.strip() {
            errors.append(f"{at}.company must be a non-empty string");
        } elif name.lower() in seen {
            warnings.append(
                f"Duplicate company name '{name}' (companies[{seen[name.lower()]}] and {at})"
            );
        } else {
            seen[name.lower()] = i;
        }
        if not isinstance(company.get("city"), (str, NoneType)) {
            errors.append(f"{at}.city must be a string when provided");
        }
        categories: any = company.get("categories");
        if not isinstance(categories, (dict, NoneType)) {
            errors.append(f"{at}.categories must be an object when provided");
            continue;
        }
        for (label, cat) in (categories or {}).items() {
            if not isinstance(cat, dict) {
                errors.append(
                    f"{at}.categories.{label} must be an object with 'count' and/or 'index' (got {type(cat).__name__})",
                );
                continue;
            }
            for (field, allowed, wanted) in (
                ("count", (int, float, NoneType), "a number"),
                ("index", (int, float, str, NoneType), "a number or string"),
            ) {
                value: any = cat.get(field);
                if not isinstance(value, allowed) {
                    errors.append(
                        f"{at}.categories.{label}.{field} must be {wanted} (got {type(value).__name__})",
                    );
                }
            }
        }
    }
    return (errors, warnings);
}

impl validate_data(data: any) -> any {
    errors: list[str] = collect_validation_issues(data)[0];
    if errors {
        fail_data_error(errors[0]);
    }
    return data;
}

impl read_raw_data -> any {
    if not DATA_FILE.exists() {
        print(
            "Error: salary_data.json not found.\n\nThis tool requires a salary data file.\nSee tools/README_SALARY_TOOL.md for setup instructions.\n\nIf you don't have salary data, the salary lookup\nstep will be skipped during /apply.",
            file=sys.stderr,
        );
        sys.exit(1);
    }
    try {
        return json.loads(DATA_FILE.read_text(encoding="utf-8-sig"));
    } except json.JSONDecodeError as exc {
        fail_data_error(f"invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}");
    }
}

impl load_data -> any {
    return validate_data(read_raw_data());
}

impl squash(s: str, gap: str) -> str {
    s = unicodedata.normalize("NFC", s.casefold());
    for pattern in STRIP_PATTERNS {
        s = re.sub(pattern, "", s);
    }
    return "".join([
        c if c.isalnum() or unicodedata.category(c).startswith("M") else gap
        for c in s
    ]);
}

impl normalize(s: str) -> str {
    return squash(s.strip(), "");
}

impl anglicize(s: str) -> str {
    s = s.lower();
    for (nordic, ascii_form) in SPELLING_VARIANTS.items() {
        s = s.replace(nordic, ascii_form);
    }
    return "".join([c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c)]);
}

impl extract_core_words(s: str) -> list[str] {
    return [w for w in squash(s, " ").split() if len(w) > 1];
}

impl query_key(query: str) -> tuple[str, str, set[str], set[str]] {
    norm: str = normalize(query);
    words: set[str] = set(extract_core_words(query));
    return (norm, anglicize(norm), words, {anglicize(w) for w in words});
}

impl fragment(shorter: int, longer: int) -> bool {
    return shorter <= 4 and shorter / longer < 0.5;
}

impl score_entry(key: tuple[str, str, set[str], set[str]], entry_name: str) -> int {
    (q_norm, q_ang, q_words, q_words_ang) = key;
    n_norm: str = normalize(entry_name);
    if not q_norm or not n_norm {
        return 0;
    }
    if q_norm == n_norm {
        return 100;
    }
    (q_len, n_len) = (len(q_norm), len(n_norm));
    n_words: set[str] = set(extract_core_words(entry_name));
    n_words_ang: set[str] = {anglicize(w) for w in n_words};
    if q_norm in n_norm and (not fragment(q_len, n_len) or bool(q_words & n_words)) {
        return 80 + int(q_len / n_len * 10);
    }
    if n_norm in q_norm and not fragment(n_len, q_len) {
        return 80 + int(n_len / q_len * 10);
    }
    n_ang: str = anglicize(n_norm);
    if q_ang == n_ang {
        return 85;
    }
    (shorter, longer) = sorted([len(q_ang), len(n_ang)]);
    if (q_ang in n_ang or n_ang in q_ang)
        and (not fragment(shorter, longer) or bool(q_words_ang & n_words_ang))
    {
        return 75;
    }
    overlap: set[str] = (q_words & n_words) or (q_words_ang & n_words_ang);
    return int(30 + len(overlap) / len(q_words) * 40) if overlap else 0;
}

impl match_score(query: str, entry_name: str) -> int {
    return score_entry(query_key(query), entry_name);
}

impl search_company(data: any, query: str, city: str | None = None) -> list[any] {
    key: tuple[str, str, set[str], set[str]] = query_key(query);
    wanted: str = (city or "").lower();
    scored: list[tuple[int, any]] = [];
    for company in data.get("companies", []) {
        place: str = (company.get("city") or "").lower();
        if wanted and wanted not in place and anglicize(wanted) not in anglicize(place) {
            continue;
        }
        score: int = score_entry(key, company["company"]);
        if score > 0 {
            scored.append((score, company));
        }
    }
    scored.sort(key=lambda (x: tuple[int, any]) -> any { (-x[0], x[1]["company"]) });
    return [company for (_, company) in scored];
}

impl format_entry(company: any, metadata: any) -> str {
    metadata = metadata or {};
    rule: str = "=" * 60;
    lines: list[str] = [f"\n{rule}", f"  {company['company']}"];
    if company.get("city") {
        lines.append(f"  Location: {company['city']}");
    }
    lines.append(rule);
    categories: any = company.get("categories") or {
        k: v
        for (k, v) in company.items()
        if k not in ENTRY_KEYS and isinstance(v, dict)
    };
    if not categories {
        return "\n".join(
            lines + [
                f"  {k.replace('_', ' ').title()}: {v}"
                for (k, v) in company.items()
                if k not in ENTRY_KEYS
            ],
        );
    }
    row = lambda (a: str, b: str, c: str, d: str) -> str { f"  {a:<22} {b:>6} {c:>8}  {d:>10}" };
    index_label: any = metadata.get("index_label", "Index");
    baseline: any = metadata.get("index_baseline", 100);
    lines += [row("Category", "Count", index_label, "vs Baseline"), "  " + "-" * 50];
    suppressed: bool = False;
    for (label, cat) in categories.items() {
        count: any = cat.get("count");
        index: any = cat.get("index");
        if count is None and index is None {
            continue;
        }
        shown: str = "-";
        diff: str = "";
        if isinstance(index, (int, float)) {
            shown = f"{index:.1f}";
            if baseline != 0 {
                percent: any = (index - baseline) / baseline * 100;
                diff = f"{'+' if percent >= 0 else ''}{percent:.1f}%";
            }
        } elif index is not None {
            shown = str(index);
        } elif "index" in cat {
            shown = "N/A*";
            suppressed = True;
        }
        lines.append(
            row(label.replace("_", " ").title(), "-" if count is None else str(count), shown, diff)
        );
    }
    lines.append("");
    if suppressed {
        lines.append("  * N/A = Too few employees to publish (privacy)");
    }
    lines.append(
        f"  {metadata.get('baseline_description') or f'{index_label} {baseline} = baseline'}"
    );
    return "\n".join(lines);
}

impl print_validation_report(errors: list[str], warnings: list[str]) -> int {
    if not errors and not warnings {
        print("OK - no issues found.");
        return 0;
    }
    print(f"Found {len(errors) + len(warnings)} issue(s):");
    for (heading, issues) in (("Errors", errors), ("Warnings", warnings)) {
        if issues {
            print(f"  {heading}:");
        }
        for (i, issue) in enumerate(issues, 1) {
            print(f"    [{i}] {issue}");
        }
    }
    if errors {
        print(
            "\nFix the errors above, then re-run. See tools/README_SALARY_TOOL.md for the expected format.",
        );
    }
    return 1 if errors else 0;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        if hasattr(stream, "reconfigure") {
            stream.reconfigure(encoding="utf-8");
        }
    }
}

impl main -> None {
    _force_utf8_output();
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Salary Benchmark Lookup"
    );
    parser.add_argument("company", nargs="?", help="Company name to search for");
    parser.add_argument("--city", help="Filter by city name");
    parser.add_argument("--json", action="store_true", help="Output as JSON");
    parser.add_argument("--list-all", action="store_true", help="List all companies");
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Validate salary_data.json and print a report, then exit",
    );
    args: any = parser.parse_args();
    if args.validate {
        (errors, warnings) = collect_validation_issues(read_raw_data());
        print(f"Validating {DATA_FILE.name} ...\n");
        sys.exit(print_validation_report(errors, warnings));
    }
    data: any = load_data();
    if args.list_all {
        for company in data.get("companies", []) {
            city: any = company.get("city", "");
            print(company["company"] + (f" ({city})" if city else ""));
        }
        return;
    }
    if not args.company {
        parser.print_help();
        sys.exit(1);
    }
    results: list[any] = search_company(data, args.company, args.city);
    if not results {
        print(f"No results found for '{args.company}'");
        if args.city {
            print(f"  (filtered by city: {args.city})");
        }
        print(
            "\nTry a shorter or different name. Company names in the dataset\nmay include legal suffixes like 'A/S' or 'ApS'.",
        );
        sys.exit(1);
    }
    if args.json {
        print(json.dumps(results, ensure_ascii=False, indent=2));
    } else {
        print(f"\nFound {len(results)} match(es) for '{args.company}':");
        for company in results {
            print(format_entry(company, data.get("metadata", {})));
        }
        print();
    }
}
