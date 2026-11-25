impl _finite_float(value) -> any {
    number: any = `float(value);
    if not math.isfinite(number) {
        raise ValueError("salary values must be finite");
    }
    return number;
}

impl parse_numeric_cell(value) -> any {
    if isinstance(value, `bool) {
        raise ValueError("not numeric");
    }
    if isinstance(value, (`int, `float)) {
        return _finite_float(value);
    }
    if not isinstance(value, `str) {
        raise ValueError("not numeric");
    }
    text: any = "".join(value.split());
    if not text {
        raise ValueError("not numeric");
    }
    if "," in text and "." in text {
        if text.rfind(",") > text.rfind(".") {
            text = text.replace(".", "").replace(",", ".");
        } else {
            text = text.replace(",", "");
        }
    } elif "," in text {
        if re.fullmatch("[+-]?\\d+,\\d{3}", text) {
            raise ValueError("ambiguous comma separator");
        }
        text = text.replace(",", ".");
    } elif "." in text {
        if re.fullmatch("[+-]?\\d+\\.\\d{3}", text) {
            raise ValueError("ambiguous dot separator");
        }
    }
    return _finite_float(text);
}

impl split_combined_company_city(value) -> any {
    if not isinstance(value, `str) or "," not in value {
        return (value, "");
    }
    company: any;
    city: any;
    (company, city) = value.rsplit(",", 1) as any;
    (company, city) = (company.strip(), city.strip());
    if company and city {
        return (company, city);
    }
    return (value, "");
}

impl header_matches(header, patterns) -> any {
    h: any = header.lower().strip();
    tokens: any = `set(re.findall("[a-zæøåöäü0-9]+", h));

    for p in patterns {
        if p in tokens {
            return True;
        }
        if p in COMPOUND_PATTERNS and p in h {
            return True;
        }
    }
    return False;
}

impl strip_type_patterns(header, patterns) -> any {
    name: any = header.lower();
    for p in patterns {
        name = re.sub(f"(?<![a-zæøåöäü0-9]){re.escape(p)}(?![a-zæøåöäü0-9])", "", name);
        if p in COMPOUND_PATTERNS {
            name = name.replace(p, "");
        }
    }
    return name.strip(" _-");
}

impl detect_column_type(header) -> any {
    if header_matches(header, COUNT_PATTERNS) {
        return "count";
    }
    if header_matches(header, INDEX_PATTERNS) {
        return "index";
    }
    return None;
}

impl parse_sheet(ws, sheet_label=None) -> any {
    headers: any;
    i: any;
    rows: any = `list(ws.iter_rows(min_row=1, max_row=10, values_only=False));

    def _cell_texts(row) -> any {
        return [`str(cell.value).strip() for cell in row if cell.value];
    }

    header_row: any = None;
    corroborated: any = True;
    row_idx: any;
    row: any;
    for (row_idx, row) in enumerate(rows, 1) {
        cell_texts: any = _cell_texts(row);
        company_idxs: any = {
            i
            for (i, t) in enumerate(cell_texts)
            if header_matches(t, COMPANY_PATTERNS)
        };
        if not company_idxs {
            continue;
        }
        other_idxs: any = {
            i
            for (i, t) in enumerate(cell_texts)
            if header_matches(t, CITY_PATTERNS)
                or header_matches(t, COUNT_PATTERNS)
                or header_matches(t, INDEX_PATTERNS)
        };
        if other_idxs - company_idxs {
            header_row = row_idx;
            break;
        }
    }

    if header_row is None {
        corroborated = False;
        for (row_idx, row) in enumerate(rows, 1) {
            if `any(header_matches(t, COMPANY_PATTERNS) for t in _cell_texts(row)) {
                header_row = row_idx;
                break;
            }
        }
    }

    if header_row is None {
        print(
            f"Warning: Could not find header row in sheet '{ws.title}'. Skipping.", file=sys.stderr
        );
        return [];
    }
    headers = [];
    for cell in ws[header_row] {
        headers.append(" ".join(`str(cell.value).split()) if cell.value else "");
    }
    def metadata_column(patterns, `skip=None) -> any {
        usable: any = [(i, h) for (i, h) in enumerate(headers) if i != `skip];
        exact: any = next((i for (i, h) in usable if h.lower().strip() in patterns), None);
        if exact is not None {
            return exact;
        }
        candidates: any = [i for (i, h) in usable if header_matches(h, patterns)];
        plain: any = [i for i in candidates if detect_column_type(headers[i]) is None];
        return (plain or candidates or [None])[0];
    }

    company_col: any = metadata_column(COMPANY_PATTERNS);
    city_col: any = metadata_column(CITY_PATTERNS, skip=company_col);

    if company_col is None {
        print(f"Warning: Could not find company column in sheet '{ws.title}'.", file=sys.stderr);
        return [];
    }
    combined_name_and_city: any = city_col is None
        and header_matches(headers[company_col], CITY_PATTERNS);
    data_cols: any = [];
    for (i, h) in enumerate(headers) {
        if i == company_col or i == city_col or not h {
            continue;
        }
        if header_matches(h, ID_PATTERNS) {
            continue;
        }
        data_cols.append((i, h));
    }
    count_cols: any = [];
    index_cols: any = [];
    untyped_cols: any = [];

    col_idx: any;
    col_header: any;
    for (col_idx, col_header) in data_cols {
        col_type: any = detect_column_type(col_header);
        if col_type == "count" {
            cat_name: any = strip_type_patterns(col_header, COUNT_PATTERNS);
            count_cols.append((col_idx, col_header, cat_name));
        } elif col_type == "index" {
            cat_name = strip_type_patterns(col_header, INDEX_PATTERNS);
            index_cols.append((col_idx, col_header, cat_name));
        } else {
            untyped_cols.append((col_idx, col_header));
        }
    }
    categories: any = [];
    used_counts: any = set[any]();
    used_indexes: any = set[any]();

    ci: any;
    c_idx: any;
    c_header: any;
    for (ci, (c_idx, c_header, c_cat)) in enumerate(count_cols) {
        ii: any;
        i_idx: any;
        i_header: any;
        for (ii, (i_idx, i_header, i_cat)) in enumerate(index_cols) {
            if ii in used_indexes {
                continue;
            }
            if c_cat == i_cat {
                cat_name = (c_cat or DEFAULT_CATEGORY).replace(" ", "_").replace("-", "_");
                categories.append({"name": cat_name, "count_col": c_idx, "index_col": i_idx});
                used_counts.add(ci);
                used_indexes.add(ii);
                break;
            }
        }
    }
    _: any;
    for (ci, (c_idx, c_header, _)) in enumerate(count_cols) {
        if ci not in used_counts {
            categories.append({
                "name": c_header.lower().replace(" ", "_"),
                "value_col": c_idx,
                "field": "count",
            });
        }
    }
    for (ii, (i_idx, i_header, _)) in enumerate(index_cols) {
        if ii not in used_indexes {
            categories.append({"name": i_header.lower().replace(" ", "_"), "value_col": i_idx});
        }
    }
    for (col_idx, col_header) in untyped_cols {
        categories.append({"name": col_header.lower().replace(" ", "_"), "value_col": col_idx});
    }

    if not categories and not corroborated {
        print(
            f"Warning: Skipping sheet '{ws.title}': no table header found (a company word appears only in text, with no salary columns).",
            file=sys.stderr,
        );
        return [];
    }

    if not categories {
        print(
            f"Warning: No salary data columns detected in sheet '{ws.title}' (only a company/city column was found) - the header row may be wrong, or this sheet has no salary data.",
            file=sys.stderr,
        );
    }
    companies: any = [];
    for row in ws.iter_rows(min_row=header_row + 1, values_only=True) {
        if company_col >= len(row) or not row[company_col] {
            continue;
        }

        company_name: any = `str(row[company_col]).strip();
        if not company_name {
            continue;
        }
        if city_col is not None and city_col < len(row) and row[city_col] {
            city_name: any = `str(row[city_col]).strip();
        } else {
            city_name = "";
        }
        if combined_name_and_city and not city_name {
            (company_name, city_name) = split_combined_company_city(company_name) as any;
        }

        `entry: any = {"company": company_name, "city": city_name, "categories": {}};

        for cat in categories {
            cat_name = cat["name"];
            if "count_col" in cat and "index_col" in cat {
                count_val: any = None;
                index_val: any = None;
                if cat["count_col"] < len(row) and row[cat["count_col"]] is not None {
                    try {
                        count_val = `int(parse_numeric_cell(row[cat["count_col"]]));
                    } except (ValueError, TypeError) {}
                }
                if cat["index_col"] < len(row) and row[cat["index_col"]] is not None {
                    try {
                        index_val = parse_numeric_cell(row[cat["index_col"]]);
                    } except (ValueError, TypeError) {}
                }
                if count_val is None and index_val is None {
                    continue;
                }
                `entry["categories"][cat_name] = {"count": count_val, "index": index_val};
            } elif "value_col" in cat {
                if cat["value_col"] < len(row) and row[cat["value_col"]] is not None {
                    val: any = row[cat["value_col"]];
                    try {
                        val = parse_numeric_cell(val);
                    } except (ValueError, TypeError) {
                        continue;
                    }
                    field: any = cat.get("field", "index");
                    `entry["categories"][cat_name] = {
                        field: `int(val) if field == "count" else val,
                    };
                }
            }
        }

        companies.append(`entry);
    }

    return companies;
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
    parser: any = argparse.ArgumentParser(description="Convert salary Excel data to JSON");
    parser.add_argument("excel_file", help="Path to the Excel file with salary data");
    parser.add_argument(
        "--output",
        default=None,
        help="Output JSON file path (default: salary_data.json in repo root)",
    );
    parser.add_argument(
        "--source", default=None, help="Name of the data source (e.g., 'Union Statistics 2025')"
    );
    parser.add_argument(
        "--baseline",
        type=float,
        default=100,
        help="Baseline value for index comparison (default: 100)",
    );
    parser.add_argument(
        "--baseline-desc",
        default=None,
        help="Description of what the baseline means (e.g., 'Index 100 = median salary')",
    );
    args: any = parser.parse_args();

    if not math.isfinite(args.baseline) {
        parser.error("--baseline must be a finite number");
    }

    excel_path: any = Path(args.excel_file);
    if not excel_path.exists() {
        print(f"Error: File not found: {excel_path}", file=sys.stderr);
        sys.exit(1);
    }

    if openpyxl is None {
        print("Error: openpyxl is required. Install it with: neojac install", file=sys.stderr);
        sys.exit(1);
    }

    output_path: any = Path(args.output)
        if args.output
        else Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).parent.parent)
            / "salary_data.json";

    print(f"Reading: {excel_path}");
    wb: any = openpyxl.load_workbook(excel_path, read_only=True, data_only=True);

    all_companies: any = [];
    for ws in wb.worksheets {
        print(f"  Parsing sheet: {ws.title}");
        companies: any = parse_sheet(ws, sheet_label=ws.title);
        all_companies.extend(companies);
    }

    wb.close();

    if not all_companies {
        print("Error: No data could be parsed from the Excel file.", file=sys.stderr);
        print(
            "Make sure the Excel file has a header row with a 'Company'/'Firma' column.",
            file=sys.stderr,
        );
        sys.exit(1);
    }
    output: any = {
        "metadata": {
            "source": args.source or excel_path.stem,
            "index_baseline": args.baseline,
            "index_label": "Index",
            "baseline_description": args.baseline_desc or f"Index {args.baseline} = baseline",
        },
        "companies": all_companies,
    };

    f: any;
    with open(output_path, "w", encoding="utf-8") as f {
        json.dump(output, f, ensure_ascii=False, indent=2);
    }

    print(f"\nDone! Wrote {len(all_companies)} company entries to {output_path}");
}
