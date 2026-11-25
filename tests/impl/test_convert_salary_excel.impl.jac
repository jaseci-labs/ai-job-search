impl FakeWorksheet.init(rows) {
    self.rows = rows;
}

impl FakeWorksheet.iter_rows(
    min_row=1, max_row=None, values_only=False
) -> Generator[any, any, any] {
    rows: any = self.rows[min_row - 1:] if max_row is None else self.rows[min_row - 1:max_row];
    for row in rows {
        if values_only {
            yield row;
        } else {
            yield [SimpleNamespace(value=value) for value in row];
        }
    }
}

impl FakeWorksheet.__getitem__(row_number) -> any {
    return [SimpleNamespace(value=value) for value in self.rows[row_number - 1]];
}

impl FakeWorksheet.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl FakeWorksheet.__eq__(other: any) -> bool {
    return self is other;
}

impl FakeWorksheet.__hash__ -> int {
    return id(self);
}

impl BooleanCellCliTests.test_excel_logical_cells_are_not_salary_numbers -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        source: any = Path(tmp) / "salary.xlsx";
        target: any = Path(tmp) / "salary.json";
        workbook: any = openpyxl.Workbook();
        sheet: any = workbook.active;
        sheet.append(["Company", "City", "Count", "Index", "Verified"]);
        sheet.append(["Logical Pair", "Berlin", True, False, True]);
        sheet.append(["Logical Count", "Berlin", False, 108.5, False]);
        sheet.append(["Logical Index", "Berlin", 12, True, None]);
        sheet.append(["Numeric Values", "Berlin", 0, 1, 0]);
        sheet.append(["Numeric Count", "Berlin", 1, 0, 1]);
        workbook.save(source);
        workbook.close();

        result: any = subprocess.run(
            [*tool("convert_salary_excel"), `str(source), "--output", `str(target)],
            capture_output=True,
            text=True,
        );
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
        companies: any = json.loads(target.read_text(encoding="utf-8"))["companies"];
    }

    self.assertEqual(companies[0]["categories"], {});
    self.assertEqual(
        companies[1]["categories"], {"all_employees": {"count": None, "index": 108.5}}
    );
    self.assertEqual(companies[2]["categories"], {"all_employees": {"count": 12, "index": None}});
    self.assertEqual(
        companies[3]["categories"],
        {"all_employees": {"count": 0, "index": 1.0}, "verified": {"index": 0.0}},
    );
    self.assertEqual(
        companies[4]["categories"],
        {"all_employees": {"count": 1, "index": 0.0}, "verified": {"index": 1.0}},
    );
}

impl DetectColumnTypeTests.test_index_headers_are_not_misclassified_as_count -> any {
    for header in ("Index", "Salary Index", "Engineering Index", "Median salary") {
        with self.subTest(header=header) {
            self.assertEqual(detect_column_type(header), "index");
        }
    }
}

impl DetectColumnTypeTests.test_single_letter_n_only_matches_as_a_token -> any {
    self.assertEqual(detect_column_type("Employee n"), "count");
    self.assertEqual(detect_column_type("Engineering"), None);
}

impl DetectColumnTypeTests.test_count_headers_still_match_common_labels -> any {
    for header in ("Count", "Engineering Count", "Antal medarbejdere") {
        with self.subTest(header=header) {
            self.assertEqual(detect_column_type(header), "count");
        }
    }
}

impl DetectColumnTypeTests.test_count_inside_word_does_not_make_count_header -> any {
    self.assertIsNone(detect_column_type("Accounting Total"));
    self.assertEqual(detect_column_type("Accounting Index"), "index");
}

impl DetectColumnTypeTests.test_danish_compound_headers_still_match -> any {
    self.assertEqual(detect_column_type("Lønindeks"), "index");
}

impl DetectColumnTypeTests.test_compound_patterns_match_as_substring_but_others_do_not -> any {
    self.assertTrue(header_matches("lønindeks", INDEX_PATTERNS));
    self.assertFalse(header_matches("salaryindex", INDEX_PATTERNS));
    self.assertTrue(header_matches("salary index", INDEX_PATTERNS));
}

impl DetectColumnTypeTests.test_parse_sheet_preserves_category_name_with_letter_n -> any {
    ws: any = FakeWorksheet([
        ("Company", "Engineering Count", "Engineering Index"),
        ("Example Corp", 12, 105.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"]["engineering"], {"count": 12, "index": 105.5});
}

impl DetectColumnTypeTests.test_parse_sheet_groups_accounting_count_index_pair -> any {
    ws: any = FakeWorksheet([
        ("Company", "Accounting Count", "Accounting Index"),
        ("Example Corp", 12, 105.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"]["accounting"], {"count": 12, "index": 105.5});
}

impl DetectColumnTypeTests.test_parse_sheet_normalizes_paired_category_name_with_underscores -> any {
    ws: any = FakeWorksheet([
        ("Company", "Software Engineering Count", "Software Engineering Index"),
        ("Example Corp", 8, 110.0),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(
        companies[0]["categories"]["software_engineering"], {"count": 8, "index": 110.0}
    );
}

impl DetectColumnTypeTests.test_parse_sheet_detects_company_column_with_token_header -> any {
    for header in ("Company", "Company Name", "Employer Name") {
        with self.subTest(header=header) {
            ws: any = FakeWorksheet([(header, "Salary"), ("Example Corp", 105.5)]);
            companies: any = parse_sheet(ws);
            self.assertEqual(len(companies), 1);
            self.assertEqual(companies[0]["company"], "Example Corp");
            self.assertEqual(companies[0]["categories"]["salary"], {"index": 105.5});
        }
    }
}

impl DetectColumnTypeTests.test_parse_sheet_detects_danish_compound_company_header -> any {
    self.assertTrue(header_matches("Firmanavn og by", COMPANY_PATTERNS));
    ws: any = FakeWorksheet([
        ("Firmanavn og by", "Antal", "Indeks"),
        ("Example A/S,Aarhus", 12, 105.0),
    ]);
    companies: any = parse_sheet(ws);
    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Example A/S");
    self.assertEqual(companies[0]["city"], "Aarhus");
    self.assertEqual(companies[0]["categories"]["all_employees"], {"count": 12, "index": 105.0});
}

impl DetectColumnTypeTests.test_parse_sheet_does_not_split_a_comma_in_a_company_only_column -> any {
    ws: any = FakeWorksheet([("Company", "Antal", "Indeks"), ("Acme, Inc.", 12, 105.0)]);
    companies: any = parse_sheet(ws);
    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Acme, Inc.");
    self.assertEqual(companies[0]["city"], "");
}

impl DetectColumnTypeTests.test_parse_sheet_splits_english_combined_company_and_city_header -> any {
    ws: any = FakeWorksheet([
        ("Company and City", "Count", "Index"),
        ("Ørsted A/S,Kongens Lyngby", 200, 105.2),
    ]);
    companies: any = parse_sheet(ws);
    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Ørsted A/S");
    self.assertEqual(companies[0]["city"], "Kongens Lyngby");
}

impl DetectColumnTypeTests.test_parse_sheet_splits_on_the_last_comma_when_the_company_contains_one -> any {
    ws: any = FakeWorksheet([
        ("Firmanavn og by", "Antal", "Indeks"),
        ("Rambøll Danmark A/S, Odense,Odense C", 12, 105.0),
        ("Ørsted A/S,Fredericia", 200, 105.2),
    ]);
    companies: any = parse_sheet(ws);
    self.assertEqual(
        [(c["company"], c["city"]) for c in companies],
        [("Rambøll Danmark A/S, Odense", "Odense C"), ("Ørsted A/S", "Fredericia")],
    );
}

impl DetectColumnTypeTests.test_parse_sheet_keeps_a_combined_cell_with_no_comma_as_company_only -> any {
    ws: any = FakeWorksheet([("Firmanavn og by", "Antal", "Indeks"), ("Example A/S", 12, 105.0)]);
    companies: any = parse_sheet(ws);
    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Example A/S");
    self.assertEqual(companies[0]["city"], "");
}

impl DetectColumnTypeTests.test_parse_sheet_detects_city_column_with_token_header -> any {
    for header in ("City", "City Name", "Kommune", "City/Kommune") {
        with self.subTest(header=header) {
            ws: any = FakeWorksheet([
                ("Company", header, "Salary"),
                ("Example Corp", "Aarhus", 105.5),
            ]);
            companies: any = parse_sheet(ws);
            self.assertEqual(len(companies), 1);
            self.assertEqual(companies[0]["city"], "Aarhus");
        }
    }
}

impl DetectColumnTypeTests.test_parse_sheet_handles_ragged_rows -> any {
    ws: any = FakeWorksheet([
        ("Company", "City", "Engineering Count", "Engineering Index"),
        ("Example Corp",),
        ("Other Corp", "Aarhus", 12, 105.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(len(companies), 2);
    self.assertEqual(companies[0]["company"], "Example Corp");
    self.assertEqual(companies[0]["city"], "");
    self.assertEqual(companies[0]["categories"], {});
    self.assertEqual(companies[1]["categories"]["engineering"], {"count": 12, "index": 105.5});
}

impl DetectColumnTypeTests.test_parse_sheet_skips_row_shorter_than_company_column -> any {
    ws: any = FakeWorksheet([
        ("Notes", "Company", "Salary Index"),
        ("stray",),
        ("", "Example Corp", 105.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Example Corp");
}

impl DetectColumnTypeTests.test_skips_free_text_column -> any {
    ws: any = FakeWorksheet([
        ("Company", "Salary Index", "Notes"),
        ("Example Corp", 105.5, "good"),
    ]);

    companies: any = parse_sheet(ws);

    self.assertIn("salary_index", companies[0]["categories"]);
    self.assertNotIn("notes", companies[0]["categories"]);
}

impl DetectColumnTypeTests.test_skips_numeric_identifier_column -> any {
    ws: any = FakeWorksheet([("Company", "Salary Index", "Id"), ("Example Corp", 105.5, 7)]);

    companies: any = parse_sheet(ws);

    self.assertIn("salary_index", companies[0]["categories"]);
    self.assertNotIn("id", companies[0]["categories"]);
}

impl DetectColumnTypeTests.test_keeps_numeric_salary_column -> any {
    ws: any = FakeWorksheet([("Company", "Salary Index"), ("Example Corp", 105.5)]);

    companies: any = parse_sheet(ws);

    self.assertIn("salary_index", companies[0]["categories"]);
    self.assertEqual(companies[0]["categories"]["salary_index"], {"index": 105.5});
}

impl DetectColumnTypeTests.test_parse_sheet_accepts_comma_decimal_string_values -> any {
    ws: any = FakeWorksheet([
        ("Company", "Engineering Count", "Engineering Index"),
        ("Example Corp", "12,0", "108,5"),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"]["engineering"], {"count": 12, "index": 108.5});
}

impl DetectColumnTypeTests.test_parse_sheet_accepts_danish_thousands_and_decimal_string -> any {
    ws: any = FakeWorksheet([("Company", "Salary Index"), ("Example Corp", "1.234,5")]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"]["salary_index"], {"index": 1234.5});
}

impl DetectColumnTypeTests.test_parse_sheet_skips_ambiguous_single_comma_thousands_string -> any {
    ws: any = FakeWorksheet([("Company", "Salary Index"), ("Example Corp", "1,234")]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"], {});
}

impl DetectColumnTypeTests.test_parse_sheet_skips_ambiguous_single_dot_thousands_string -> any {
    ws: any = FakeWorksheet([("Company", "Salary Index"), ("Example Corp", "1.234")]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"], {});
}

impl DetectColumnTypeTests.test_parse_sheet_pairs_interleaved_count_index_columns_by_name -> any {
    ws: any = FakeWorksheet([
        ("Company", "Antal kvinder", "Antal mænd", "Kvinder indeks", "Mænd indeks"),
        ("Example Corp", 15, 20, 95.0, 108.0),
    ]);

    companies: any = parse_sheet(ws);

    categories: any = companies[0]["categories"];
    self.assertEqual(categories["kvinder"], {"count": 15, "index": 95.0});
    self.assertEqual(categories["mænd"], {"count": 20, "index": 108.0});
}

impl DetectColumnTypeTests.test_standalone_count_column_is_stored_as_count_not_index -> any {
    ws: any = FakeWorksheet([
        ("Company", "Antal", "IT Count", "IT Index"),
        ("Example Corp", 250, 30, 108.5),
    ]);

    companies: any = parse_sheet(ws);

    categories: any = companies[0]["categories"];
    self.assertEqual(categories["antal"], {"count": 250});
    self.assertEqual(categories["it"], {"count": 30, "index": 108.5});
}

impl DetectColumnTypeTests.test_parse_sheet_non_adjacent_columns_no_cross_match -> any {
    ws: any = FakeWorksheet([
        ("Company", "Count_A", "Count_B", "Index_A", "Index_B"),
        ("Example Corp", 10, 20, 100.0, 200.0),
    ]);

    companies: any = parse_sheet(ws);

    categories: any = companies[0]["categories"];
    self.assertEqual(categories["a"], {"count": 10, "index": 100.0});
    self.assertEqual(categories["b"], {"count": 20, "index": 200.0});
}

impl DetectColumnTypeTests.test_parse_sheet_ignores_citation_row_mentioning_company_pattern_word -> any {
    ws: any = FakeWorksheet([
        ("Lønstatistik 2025",),
        ("Kilde: Medlemsundersøgelse opdelt efter arbejdsgiver og branche",),
        (),
        ("Firma", "By", "Antal alle", "Lønindeks alle"),
        ("Novo Nordisk A/S", "Bagsværd", 500, 108.5),
        ("Ørsted A/S", "Fredericia", 200, 105.2),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(len(companies), 2);
    self.assertEqual(companies[0]["company"], "Novo Nordisk A/S");
    self.assertEqual(companies[0]["city"], "Bagsværd");
    self.assertEqual(companies[0]["categories"]["alle"], {"count": 500, "index": 108.5});
    self.assertEqual(companies[1]["company"], "Ørsted A/S");
}

impl DetectColumnTypeTests.test_parse_sheet_rejects_citation_row_with_count_word_in_same_cell -> any {
    ws: any = FakeWorksheet([
        ("Lønstatistik 2025",),
        ("Kilde: undersøgelse opdelt efter arbejdsgiver, antal svar 1234",),
        (),
        ("Firma", "By", "Antal alle", "Lønindeks alle"),
        ("Novo Nordisk A/S", "Bagsværd", 500, 108.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Novo Nordisk A/S");
    self.assertEqual(companies[0]["categories"]["alle"], {"count": 500, "index": 108.5});
}

impl DetectColumnTypeTests.test_parse_sheet_falls_back_when_no_row_has_cross_cell_corroboration -> any {
    ws: any = FakeWorksheet([
        ("Company", "Base pay 2025", "Bonus 2025"),
        ("Example Corp", 55000, 5000),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(len(companies), 1);
    self.assertEqual(companies[0]["company"], "Example Corp");
    self.assertEqual(companies[0]["categories"]["base_pay_2025"], {"index": 55000.0});
    self.assertEqual(companies[0]["categories"]["bonus_2025"], {"index": 5000.0});
}

impl DetectColumnTypeTests.test_parse_sheet_warns_when_no_salary_columns_detected -> any {
    ws: any = FakeWorksheet([("Company", "City"), ("Example Corp", "Aarhus")]);

    stderr: any = io.StringIO();
    with redirect_stderr(stderr) {
        companies: any = parse_sheet(ws);
    }

    self.assertEqual(companies[0]["categories"], {});
    self.assertIn("No salary data columns detected", stderr.getvalue());
}

impl ParseNumericCellLocaleTests.test_us_thousands_and_decimal_string -> any {
    self.assertEqual(parse_numeric_cell("1,234.56"), 1234.56);
}

impl ParseNumericCellLocaleTests.test_us_multiple_thousands_groups -> any {
    self.assertEqual(parse_numeric_cell("1,234,567.89"), 1234567.89);
}

impl ParseNumericCellLocaleTests.test_european_thousands_and_decimal_string -> any {
    self.assertEqual(parse_numeric_cell("1.234,56"), 1234.56);
}

impl ParseNumericCellLocaleTests.test_european_multiple_thousands_groups -> any {
    self.assertEqual(parse_numeric_cell("1.234.567,89"), 1234567.89);
}

impl BareCountIndexPairingTests.test_bare_english_pair_is_paired_under_the_default_category -> any {
    ws: any = FakeWorksheet([
        ("Company", "City", "Count", "Index"),
        ("Acme Corp", "Copenhagen", 500, 108.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(
        companies[0]["categories"], {self.DEFAULT_CATEGORY: {"count": 500, "index": 108.5}}
    );
}

impl BareCountIndexPairingTests.test_bare_danish_pair_is_paired_under_the_default_category -> any {
    ws: any = FakeWorksheet([
        ("Firma", "By", "Antal", "Lønindeks"),
        ("Acme Corp", "Aarhus", 500, 108.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(
        companies[0]["categories"], {self.DEFAULT_CATEGORY: {"count": 500, "index": 108.5}}
    );
}

impl BareCountIndexPairingTests.test_bare_pair_does_not_cross_pair_with_a_named_category -> any {
    ws: any = FakeWorksheet([
        ("Company", "Antal", "IT Count", "IT Index", "Lønindeks"),
        ("Acme Corp", 500, 30, 112.0, 108.5),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(
        companies[0]["categories"],
        {
            self.DEFAULT_CATEGORY: {"count": 500, "index": 108.5},
            "it": {"count": 30, "index": 112.0},
        },
    );
}

impl BareCountIndexPairingTests.test_lookup_renders_the_bare_pair_as_one_row_without_the_privacy_footnote_firing -> any {
    ws: any = FakeWorksheet([
        ("Company", "City", "Count", "Index"),
        ("Acme Corp", "Copenhagen", 500, 108.5),
    ]);
    `entry: any = parse_sheet(ws)[0];

    rendered: any = format_entry(`entry, {"index_baseline": 100, "index_label": "Index"});

    self.assertNotIn("N/A*", rendered.split("* N/A =")[0]);
    self.assertRegex(rendered, "All Employees\\s+500\\s+108\\.5\\s+\\+8\\.5%");
    self.assertNotRegex(rendered, "^\\s*Count\\s+500");
}

impl QualifiedCompanyHeaderNextToQualifiedSalaryHeader.test_company_name_wins_over_company_index -> any {
    ws: any = FakeWorksheet([
        ("Company Name", "City", "Company Count", "Company Index"),
        ("Acme Corp", "Berlin", 25, 108.5),
    ]);

    `entry: any = parse_sheet(ws)[0];

    self.assertEqual(`entry["company"], "Acme Corp");
    self.assertEqual(`entry["city"], "Berlin");
    self.assertEqual(`entry["categories"], {"company": {"count": 25, "index": 108.5}});
}

impl QualifiedCompanyHeaderNextToQualifiedSalaryHeader.test_danish_name_header_wins_over_qualified_index_header -> any {
    ws: any = FakeWorksheet([
        ("Firmanavn og by", "Antal", "Firmaets indeks"),
        ("Acme A/S", 25, 108.5),
    ]);

    `entry: any = parse_sheet(ws)[0];

    self.assertEqual(`entry["company"], "Acme A/S");
    self.assertEqual(sum(1 for c in `entry["categories"].values() if c.get("index") == 108.5), 1);
    self.assertEqual(sum(1 for c in `entry["categories"].values() if c.get("count") == 25), 1);
}

impl QualifiedCompanyHeaderNextToQualifiedSalaryHeader.test_exact_header_still_wins_over_a_qualified_name_header -> any {
    ws: any = FakeWorksheet([
        ("Company Name", "Company", "Salary Index"),
        ("Acme Corp (legal)", "Acme", 108.5),
    ]);

    self.assertEqual(parse_sheet(ws)[0]["company"], "Acme");
}

impl QualifiedCompanyHeaderNextToQualifiedSalaryHeader.test_city_column_never_aliases_the_company_column -> any {
    ws: any = FakeWorksheet([("Firmanavn og by", "Antal", "Indeks"), ("Acme A/S", 25, 108.5)]);

    `entry: any = parse_sheet(ws)[0];

    self.assertEqual(`entry["company"], "Acme A/S");
    self.assertEqual(`entry["city"], "");
    self.assertEqual(`entry["categories"], {"all_employees": {"count": 25, "index": 108.5}});
}

impl QualifiedCompanyHeaderNextToQualifiedSalaryHeader.test_combined_header_before_a_real_city_column_keeps_the_city -> any {
    for (headers, row, city) in (
        (
            ("Company and city", "City name", "Count", "Index"),
            ("Acme Corp", "Berlin", 25, 108.5),
            "Berlin",
        ),
        (
            ("Firmanavn og by", "City name", "Antal", "Indeks"),
            ("Acme A/S", "Aarhus", 25, 108.5),
            "Aarhus",
        ),
    ) {
        with self.subTest(headers=headers) {
            `entry: any = parse_sheet(FakeWorksheet([headers, row]))[0];
            self.assertEqual(`entry["company"], row[0]);
            self.assertEqual(`entry["city"], city);
            self.assertEqual(
                `entry["categories"], {"all_employees": {"count": 25, "index": 108.5}}
            );
        }
    }
}

impl CompoundCategoryPairingTests.test_parse_sheet_pairs_danish_compound_index_with_count -> any {
    ws: any = FakeWorksheet([
        ("Firma", "Antal alle", "Lønindeks alle"),
        ("Example Corp", 12, 118.0),
    ]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"]["alle"], {"count": 12, "index": 118.0});
}

impl CompoundCategoryPairingTests.test_parse_sheet_sheet_level_us_locale_value -> any {
    ws: any = FakeWorksheet([("Company", "Salary Index"), ("Example Corp", "1,234.56")]);

    companies: any = parse_sheet(ws);

    self.assertEqual(companies[0]["categories"]["salary_index"], {"index": 1234.56});
}
