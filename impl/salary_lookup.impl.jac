impl fail_data_error(message) -> any {
    print(f"Error: invalid salary_data.json: {message}", file=sys.stderr);
    print("", file=sys.stderr);
    print("See tools/README_SALARY_TOOL.md for the expected format.", file=sys.stderr);
    sys.exit(1);
}

impl collect_validation_issues(data) -> any {
    errors: any = [];
    warnings: any = [];

    if not isinstance(data, `dict) {
        errors.append("top-level JSON value must be an object");
        return (errors, warnings);
    }

    metadata: any = data.get("metadata", {});
    if metadata is not None and not isinstance(metadata, `dict) {
        errors.append("'metadata' must be an object when provided");
    } elif isinstance(metadata, `dict) {
        baseline: any = metadata.get("index_baseline", 100);
        try {
            finite_baseline: any = math.isfinite(baseline);
        } except (TypeError, OverflowError) {
            finite_baseline = False;
        }
        if isinstance(baseline, `bool) or not finite_baseline {
            errors.append("'metadata.index_baseline' must be a finite number");
        }
        if not isinstance(metadata.get("index_label", "Index"), `str) {
            errors.append("'metadata.index_label' must be a string");
        }
    }

    companies: any = data.get("companies");
    if not isinstance(companies, `list) {
        errors.append("'companies' must be a list");
        return (errors, warnings);
    }

    seen_companies: any = {};
    for (index, `entry) in enumerate(companies, 1) {
        if not isinstance(`entry, `dict) {
            errors.append(f"companies[{index}] must be an object");
            continue;
        }

        company: any = `entry.get("company");
        if not isinstance(company, `str) or not company.strip() {
            errors.append(f"companies[{index}].company must be a non-empty string");
        } else {
            key: any = company.lower();
            if key in seen_companies {
                warnings.append(
                    f"Duplicate company name '{company}' (companies[{seen_companies[key]}] and companies[{index}])",
                );
            } else {
                seen_companies[key] = index;
            }
        }

        city: any = `entry.get("city");
        if city is not None and not isinstance(city, `str) {
            errors.append(f"companies[{index}].city must be a string when provided");
        }

        categories: any = `entry.get("categories", dict[any, any]());
        if categories is not None and not isinstance(categories, `dict) {
            errors.append(f"companies[{index}].categories must be an object when provided");
        } elif categories {
            for (cat_label, cat_data) in categories.items() {
                if not isinstance(cat_data, `dict) {
                    errors.append(
                        f"companies[{index}].categories.{cat_label} must be an object with 'count' and/or 'index' (got {`type(cat_data).__name__})",
                    );
                    continue;
                }
                count: any = cat_data.get("count");
                if count is not None and not isinstance(count, (`int, `float)) {
                    errors.append(
                        f"companies[{index}].categories.{cat_label}.count must be a number (got {`type(count).__name__})",
                    );
                }
                index_val: any = cat_data.get("index");
                if index_val is not None and not isinstance(index_val, (`int, `float, `str)) {
                    errors.append(
                        f"companies[{index}].categories.{cat_label}.index must be a number or string (got {`type(index_val).__name__})",
                    );
                }
            }
        }
    }

    return (errors, warnings);
}

impl validate_data(data) -> any {
    errors: any;
    _: any;
    (errors, _) = collect_validation_issues(data) as any;
    if errors {
        fail_data_error(errors[0]);
    }
    return data;
}

impl read_raw_data -> any {
    if not DATA_FILE.exists() {
        print("Error: salary_data.json not found.", file=sys.stderr);
        print("", file=sys.stderr);
        print("This tool requires a salary data file.", file=sys.stderr);
        print("See tools/README_SALARY_TOOL.md for setup instructions.", file=sys.stderr);
        print("", file=sys.stderr);
        print("If you don't have salary data, the salary lookup", file=sys.stderr);
        print("step will be skipped during /apply.", file=sys.stderr);
        sys.exit(1);
    }
    try {
        f: any;
        with open(DATA_FILE, "r", encoding="utf-8-sig") as f {
            data: any = json.load(f);
        }
    } except json.JSONDecodeError as exc {
        fail_data_error(f"invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}");
    }
    return data;
}

impl load_data -> any {
    return validate_data(read_raw_data());
}

impl normalize(s) -> any {
    s = unicodedata.normalize("NFC", s.casefold()).strip();
    for pat in STRIP_PATTERNS {
        s = re.sub(pat, "", s);
    }
    return "".join(
        char for char in s if char.isalnum() or unicodedata.category(char).startswith("M")
    );
}

impl anglicize(s) -> any {
    s = s.lower();
    for (danish, english) in SPELLING_VARIANTS.items() {
        s = s.replace(danish, english);
    }
    return "".join(
        char for char in unicodedata.normalize("NFKD", s) if not unicodedata.combining(char)
    );
}

impl extract_core_words(s) -> any {
    s = unicodedata.normalize("NFC", s.casefold());
    for pat in STRIP_PATTERNS {
        s = re.sub(pat, "", s);
    }
    s = "".join(
        char if char.isalnum() or unicodedata.category(char).startswith("M") else " " for char in s
    );
    words: any = s.split();
    return [w for w in words if len(w) > 1];
}

impl match_score_optimized(q_norm, q_ang, q_words_set, q_words_ang_set, query, entry_name) -> any {
    n_norm: any = normalize(entry_name);

    if not q_norm or not n_norm {
        return 0;
    }

    if q_norm == n_norm {
        return 100;
    }

    if q_norm in n_norm {
        ratio: any = len(q_norm) / len(n_norm);
        if len(q_norm) <= 4 and ratio < 0.5 {
            n_words: any = `set(extract_core_words(entry_name));
            if not q_words_set & n_words {} else {
                return 80 + `int(ratio * 10);
            }
        } else {
            return 80 + `int(ratio * 10);
        }
    }
    if n_norm in q_norm {
        ratio = len(n_norm) / len(q_norm);
        if len(n_norm) <= 4 and ratio < 0.5 {} else {
            return 80 + `int(ratio * 10);
        }
    }

    n_ang: any = anglicize(n_norm);
    if q_ang == n_ang {
        return 85;
    }
    if q_ang in n_ang or n_ang in q_ang {
        shorter: any = min(len(q_ang), len(n_ang));
        longer: any = max(len(q_ang), len(n_ang));
        if shorter <= 4 and shorter / longer < 0.5 {
            n_words_ang: any = {anglicize(w) for w in extract_core_words(entry_name)};
            if q_words_ang_set & n_words_ang {
                return 75;
            }
        } else {
            return 75;
        }
    }

    n_words = `set(extract_core_words(entry_name));
    if not q_words_set or not n_words {
        return 0;
    }

    overlap: any = q_words_set & n_words;
    if not overlap {
        n_words_ang = {anglicize(w) for w in n_words};
        overlap = q_words_ang_set & n_words_ang;
    }

    if overlap {
        if len(q_words_set) == 1 {
            q_word: any = `list(q_words_set)[0];
            if q_word in n_words or anglicize(q_word) in {anglicize(w) for w in n_words} {
                return 70;
            }
            return 0;
        }

        coverage: any = len(overlap) / len(q_words_set);
        return `int(30 + coverage * 40);
    }

    return 0;
}

impl match_score(query, entry_name) -> any {
    q_norm: any = normalize(query);
    q_ang: any = anglicize(q_norm);
    q_words: any = extract_core_words(query);
    q_words_set: any = `set(q_words);
    q_words_ang_set: any = {anglicize(w) for w in q_words};
    return match_score_optimized(q_norm, q_ang, q_words_set, q_words_ang_set, query, entry_name);
}

impl search_company(data, query, city=None) -> any {
    companies: any = data.get("companies", []);
    scored: any = [];
    q_norm: any = normalize(query);
    q_ang: any = anglicize(q_norm);
    q_words: any = extract_core_words(query);
    q_words_set: any = `set(q_words);
    q_words_ang_set: any = {anglicize(w) for w in q_words};

    for `entry in companies {
        if city {
            city_lower: any = city.lower();
            entry_city: any = (`entry.get("city") or "").lower();
            if city_lower not in entry_city and anglicize(city_lower) not in anglicize(entry_city) {
                continue;
            }
        }

        score: any = match_score_optimized(
            q_norm, q_ang, q_words_set, q_words_ang_set, query, `entry["company"]
        );
        if score > 0 {
            scored.append((score, `entry));
        }
    }

    scored.sort(key=lambda (x) -> any { (-x[0], x[1]["company"]) });

    min_score: any = 30;
    return [`entry for (score, `entry) in scored if score >= min_score];
}

impl format_entry(`entry, metadata) -> any {
    metadata = metadata or {};
    lines: any = [];
    lines.append("\n" + format("=" * 60, ""));
    lines.append("  " + format(`entry["company"], ""));
    if `entry.get("city") {
        lines.append("  Location: " + format(`entry["city"], ""));
    }
    lines.append(format("=" * 60, ""));
    categories: any = `entry.get("categories") or {};
    if not categories {
        skip_keys: any = {"company", "city", "categories"};
        key: any;
        value: any;
        for (key, value) in `entry.items() {
            if key not in skip_keys and isinstance(value, `dict) {
                categories[key] = value;
            }
        }
    }

    if categories {
        index_label: any = metadata.get("index_label", "Index");
        baseline: any = metadata.get("index_baseline", 100);

        lines.append(
            "  "
                + format("Category", "<22")
                + " "
                + format("Count", ">6")
                + " "
                + format(index_label, ">8")
                + "  "
                + format("vs Baseline", ">10"),
        );
        lines.append("  " + format("-" * 50, ""));

        suppressed: any = False;
        for (label, data) in categories.items() {
            display_label: any = label.replace("_", " ").title();
            count: any = data.get("count");
            index: any = data.get("index");
            if count is not None or index is not None {
                count_str: any = `str(count) if count is not None else "-";
                if isinstance(index, (`int, `float)) {
                    index_str: any = f"{index:.1f}";
                    if baseline == 0 {
                        diff_str: any = "";
                    } else {
                        diff_pct: any = (index - baseline) / baseline * 100;
                        sign: any = "+" if diff_pct >= 0 else "";
                        diff_str = f"{sign}{diff_pct:.1f}%";
                    }
                } elif index is not None {
                    index_str = `str(index);
                    diff_str = "";
                } elif "index" not in data {
                    index_str = "-";
                    diff_str = "";
                } else {
                    index_str = "N/A*";
                    diff_str = "";
                    suppressed = True;
                }
                lines.append(
                    f"  {display_label:<22} {count_str:>6} {index_str:>8}  {diff_str:>10}"
                );
            }
        }
        lines.append("");
        if suppressed {
            lines.append("  * N/A = Too few employees to publish (privacy)");
        }
        if metadata.get("baseline_description") {
            lines.append("  " + format(metadata["baseline_description"], ""));
        } else {
            lines.append(f"  {index_label} {baseline} = baseline");
        }
    } else {
        skip_keys = {"company", "city", "categories"};
        for (key, value) in `entry.items() {
            if key not in skip_keys {
                display_key: any = key.replace("_", " ").title();
                lines.append(f"  {display_key}: {value}");
            }
        }
    }

    return "\n".join(lines);
}

impl print_validation_report(errors, warnings) -> any {
    if not errors and not warnings {
        print("OK - no issues found.");
        return 0;
    }
    print(f"Found {len(errors) + len(warnings)} issue(s):");
    if errors {
        print("  Errors:");
        i: any;
        msg: any;
        for (i, msg) in enumerate(errors, 1) {
            print(f"    [{i}] {msg}");
        }
    }
    if warnings {
        print("  Warnings:");
        for (i, msg) in enumerate(warnings, 1) {
            print(f"    [{i}] {msg}");
        }
    }
    if errors {
        print("");
        print(
            "Fix the errors above, then re-run. See tools/README_SALARY_TOOL.md for the expected format.",
        );
        return 1;
    }
    return 0;
}

impl _force_utf8_output -> None {
    for stream in (sys.stdout, sys.stderr) {
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure {
            reconfigure(encoding="utf-8");
        }
    }
}

impl main -> any {
    _force_utf8_output();
    parser: any = argparse.ArgumentParser(description="Salary Benchmark Lookup");
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
        data: any = read_raw_data();
        errors: any;
        warnings: any;
        (errors, warnings) = collect_validation_issues(data) as any;
        print(f"Validating {DATA_FILE.name} ...");
        print("");
        sys.exit(print_validation_report(errors, warnings));
    }

    data = load_data();
    metadata: any = data.get("metadata", {});
    companies: any = data.get("companies", []);

    if args.list_all {
        `entry: any;
        for `entry in companies {
            city: any = `entry.get("city", "");
            city_str: any = f" ({city})" if city else "";
            print(format(`entry["company"], "") + format(city_str, ""));
        }
        return;
    }

    if not args.company {
        parser.print_help();
        sys.exit(1);
    }

    results: any = search_company(data, args.company, args.city);

    if not results {
        print(f"No results found for '{args.company}'");
        if args.city {
            print(f"  (filtered by city: {args.city})");
        }
        print("\nTry a shorter or different name. Company names in the dataset");
        print("may include legal suffixes like 'A/S' or 'ApS'.");
        sys.exit(1);
    }

    if args.json {
        print(json.dumps(results, ensure_ascii=False, indent=2));
    } else {
        print(f"\nFound {len(results)} match(es) for '{args.company}':");
        for `entry in results {
            print(format_entry(`entry, metadata));
        }
        print();
    }
}
