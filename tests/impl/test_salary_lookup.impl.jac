impl FormatEntryTests.test_privacy_footnote_is_omitted_when_no_row_is_suppressed -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {"all_employees": {"count": 500, "index": 108.5}},
    };

    rendered: any = format_entry(`entry, {"index_baseline": 100, "index_label": "Index"});

    self.assertNotIn("N/A", rendered);
    self.assertNotIn(self.PRIVACY_FOOTNOTE, rendered);
    self.assertRegex(rendered, "All Employees\\s+500\\s+108\\.5\\s+\\+8\\.5%");
}

impl FormatEntryTests.test_privacy_footnote_is_printed_when_a_row_is_suppressed -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {
            "all_employees": {"count": 500, "index": 108.5},
            "small_team": {"count": 3, "index": None},
        },
    };

    rendered: any = format_entry(`entry, {"index_baseline": 100, "index_label": "Index"});

    self.assertRegex(rendered, "Small Team\\s+3\\s+N/A\\*");
    self.assertIn(self.PRIVACY_FOOTNOTE, rendered);
}

impl FormatEntryTests.test_zero_count_is_displayed_as_zero -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {"public_data": {"count": 0, "index": 100.0}},
    };

    rendered: any = format_entry(`entry, {"index_baseline": 100, "index_label": "Index"});

    self.assertRegex(rendered, "Public Data\\s+0\\s+100\\.0");
}

impl FormatEntryTests.test_text_index_does_not_crash -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {"sample": {"count": 3, "index": "private"}},
    };

    rendered: any = format_entry(`entry, {"index_baseline": 100, "index_label": "Index"});

    self.assertIn("private", rendered);
}

impl FormatEntryTests.test_format_entry_with_zero_baseline -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {"it": {"count": None, "index": 45000.0}},
    };
    rendered: any = format_entry(`entry, {"index_baseline": 0, "index_label": "Salary"});
    self.assertIn("45000.0", rendered);
    self.assertNotIn("%", rendered);
}

impl FormatEntryTests.test_format_entry_with_custom_baseline -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {"it": {"count": None, "index": 45000.0}},
    };
    rendered: any = format_entry(`entry, {"index_baseline": 40000, "index_label": "Salary"});
    self.assertIn("45000.0", rendered);
    self.assertIn("+12.5%", rendered);
}

impl FormatEntryTests.test_null_categories_with_sibling_dict_does_not_crash -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": None,
        "engineering": {"count": 10, "index": 105.0},
    };

    rendered: any = format_entry(`entry, {"index_baseline": 100, "index_label": "Index"});

    self.assertRegex(rendered, "Engineering\\s+10\\s+105\\.0");
}

impl FormatEntryTests.test_null_metadata_does_not_crash -> any {
    `entry: any = {
        "company": "Example Corp",
        "city": "",
        "categories": {"eng": {"count": 5, "index": 108.0}},
    };

    rendered: any = format_entry(`entry, None);

    self.assertRegex(rendered, "Eng\\s+5\\s+108\\.0");
}

impl TestMatchScoreExactMatch.test_exact_match_returns_100 -> any {
    self.assertEqual(match_score("Novo Nordisk", "Novo Nordisk"), 100);
}

impl TestMatchScoreExactMatch.test_exact_match_case_insensitive -> any {
    self.assertEqual(match_score("NOVO NORDISK", "Novo Nordisk"), 100);
}

impl TestMatchScoreExactMatch.test_exact_match_after_suffix_stripping -> any {
    self.assertEqual(match_score("Mærsk", "Mærsk A/S"), 100);
}

impl TestMatchScoreExactMatch.test_exact_match_after_dotted_amba_suffix_stripping -> any {
    self.assertEqual(match_score("Arla Foods", "Arla Foods A.M.B.A."), 100);
}

impl TestMatchScoreSubstring.test_query_contained_in_entry_gives_high_score -> any {
    score: any = match_score("Carlsberg", "Carlsberg Danmark A/S");
    self.assertGreaterEqual(score, 80);
}

impl TestMatchScoreSubstring.test_entry_contained_in_query_gives_high_score -> any {
    score: any = match_score("Carlsberg Danmark", "Carlsberg");
    self.assertGreaterEqual(score, 80);
}

impl TestMatchScoreShortQuery.test_short_query_no_word_overlap_returns_zero -> any {
    score: any = match_score("ab", "Something Unrelated Company");
    self.assertEqual(score, 0);
}

impl TestMatchScoreShortQuery.test_short_query_with_word_overlap_scores -> any {
    score: any = match_score("IBM", "IBM Corporation");
    self.assertGreater(score, 0);
}

impl TestMatchScoreAnglicize.test_oe_variant_matches_o_with_slash -> any {
    score: any = match_score("Maersk", "Mærsk A/S");
    self.assertGreater(score, 0);
}

impl TestMatchScoreAnglicize.test_aa_variant_matches_aa -> any {
    self.assertEqual(match_score("Aarsleff", "Aarsleff"), 100);
}

impl TestMatchScoreAnglicize.test_danish_characters_roundtrip -> any {
    score: any = match_score("Maersk", "Mærsk A/S");
    self.assertGreater(score, 0);
}

impl TestMatchScoreNoOverlap.test_completely_unrelated_names_return_zero -> any {
    self.assertEqual(match_score("Apple", "Vestas Wind Systems"), 0);
}

impl TestMatchScoreNoOverlap.test_empty_query_returns_zero -> any {
    self.assertEqual(match_score("", "Novo Nordisk"), 0);
}

impl TestMatchScoreNoOverlap.test_empty_entry_returns_zero -> any {
    self.assertEqual(match_score("Novo Nordisk", ""), 0);
}

impl _make_data(*entries_) -> any {
    entries: any = tuple(entries_);
    return {"companies": `list(entries)};
}

impl _entry(company, city="") -> any {
    return {"company": company, "city": city};
}

impl SearchCompanyTests.test_search_company_with_none_city -> any {
    data: any = {"companies": [{"company": "Acme", "city": None}]};
    results: any = search_company(data, "Acme", city="Aarhus");
    self.assertEqual(results, []);
}

impl ValidateDataTests.assert_invalid_data(data, expected_message) -> any {
    stderr: any = io.StringIO();
    raised: any;
    with self.assertRaises(SystemExit) as raised {
        with redirect_stderr(stderr) {
            validate_data(data);
        }
    }

    self.assertEqual(raised.exception.code, 1);
    self.assertIn("Error: invalid salary_data.json", stderr.getvalue());
    self.assertIn(expected_message, stderr.getvalue());
    self.assertIn("tools/README_SALARY_TOOL.md", stderr.getvalue());
}

impl ValidateDataTests.test_valid_minimal_data_is_returned -> any {
    data: any = {"metadata": {}, "companies": [{"company": "Example Corp"}]};

    self.assertIs(validate_data(data), data);
}

impl ValidateDataTests.test_top_level_value_must_be_object -> any {
    self.assert_invalid_data([], "top-level JSON value must be an object");
}

impl ValidateDataTests.test_companies_must_be_list -> any {
    self.assert_invalid_data(
        {"companies": {"company": "Example Corp"}}, "'companies' must be a list"
    );
}

impl ValidateDataTests.test_metadata_must_be_object_when_provided -> any {
    self.assert_invalid_data(
        {"metadata": [], "companies": [{"company": "Example Corp"}]},
        "'metadata' must be an object when provided",
    );
}

impl ValidateDataTests.test_load_data_reports_json_parse_errors_without_traceback -> any {
    tmpdir: any;
    with tempfile.TemporaryDirectory() as tmpdir {
        data_file: any = Path(tmpdir) / "salary_data.json";
        data_file.write_text("{\"companies\": [", encoding="utf-8");

        original_data_file: any = salary_lookup.DATA_FILE;
        salary_lookup.DATA_FILE = data_file;
        try {
            stderr: any = io.StringIO();
            raised: any;
            with self.assertRaises(SystemExit) as raised {
                with redirect_stderr(stderr) {
                    salary_lookup.load_data();
                }
            }
        } finally {
            salary_lookup.DATA_FILE = original_data_file;
        }
    }

    self.assertEqual(raised.exception.code, 1);
    self.assertIn("invalid JSON at line", stderr.getvalue());
    self.assertIn("tools/README_SALARY_TOOL.md", stderr.getvalue());
}

impl ValidateDataTests.test_company_entry_must_be_object -> any {
    self.assert_invalid_data({"companies": ["Example Corp"]}, "companies[1] must be an object");
}

impl ValidateDataTests.test_company_name_is_required -> any {
    self.assert_invalid_data(
        {"companies": [{"city": "Aarhus"}]}, "companies[1].company must be a non-empty string"
    );
}

impl ValidateDataTests.test_company_name_must_not_be_blank -> any {
    self.assert_invalid_data(
        {"companies": [{"company": "  "}]}, "companies[1].company must be a non-empty string"
    );
}

impl ValidateDataTests.test_city_must_be_string_when_provided -> any {
    self.assert_invalid_data(
        {"companies": [{"company": "Example Corp", "city": 123}]},
        "companies[1].city must be a string when provided",
    );
}

impl ValidateDataTests.test_categories_must_be_object_when_provided -> any {
    self.assert_invalid_data(
        {"companies": [{"company": "Example Corp", "categories": []}]},
        "companies[1].categories must be an object when provided",
    );
}

impl ValidateDataShapeTests.test_malformed_category_value_rejected -> any {
    data: any = {"companies": [{"company": "Acme", "categories": {"eng": "not_a_dict"}}]};
    self.assert_invalid_data(data, "must be an object with 'count' and/or 'index'");
}

impl ValidateDataShapeTests.test_non_numeric_count_rejected -> any {
    data: any = {"companies": [{"company": "Acme", "categories": {"eng": {"count": "many"}}}]};
    self.assert_invalid_data(data, "count must be a number");
}

impl ValidateDataShapeTests.test_duplicate_company_name_is_warning -> any {
    data: any = {
        "companies": [{"company": "Acme"}, {"company": "Other Corp"}, {"company": "Acme"}],
    };
    errors: any;
    warnings: any;
    (errors, warnings) = collect_validation_issues(data) as any;
    self.assertEqual(errors, []);
    self.assertEqual(len(warnings), 1);
    self.assertIn("Duplicate company name 'Acme'", warnings[0]);
}

impl ValidateDataShapeTests.test_valid_categories_have_no_issues -> any {
    data: any = {
        "companies": [{"company": "Acme", "categories": {"eng": {"count": 5, "index": 108.5}}}],
    };
    errors: any;
    warnings: any;
    (errors, warnings) = collect_validation_issues(data) as any;
    self.assertEqual(errors, []);
    self.assertEqual(warnings, []);
}

impl ValidateFlagTests._run_validate(payload) -> any {
    tmpdir: any;
    with tempfile.TemporaryDirectory() as tmpdir {
        data_file: any = Path(tmpdir) / "salary_data.json";
        data_file.write_text(payload, encoding="utf-8");
        original_data_file: any = salary_lookup.DATA_FILE;
        salary_lookup.DATA_FILE = data_file;
        argv_patch: any = mock.patch("sys.argv", ["salary_lookup.jac", "--validate"]);
        argv_patch.start();
        try {
            stdout: any = io.StringIO();
            raised: any;
            with self.assertRaises(SystemExit) as raised {
                with redirect_stdout(stdout) {
                    salary_lookup.main();
                }
            }
            return (raised.exception.code, stdout.getvalue());
        } finally {
            argv_patch.stop();
            salary_lookup.DATA_FILE = original_data_file;
        }
    }
}

impl ValidateFlagTests.test_validate_flag_exits_1_on_errors -> any {
    code: any;
    out: any;
    (code, out) = self._run_validate(
        "{\"companies\": [{\"company\": \"Acme\", \"categories\": {\"eng\": \"not_a_dict\"}}]}"
    ) as any;
    self.assertEqual(code, 1);
    self.assertIn("must be an object with 'count' and/or 'index'", out);
}

impl ValidateFlagTests.test_validate_flag_exits_0_on_clean -> any {
    code: any;
    out: any;
    (code, out) = self._run_validate(
        "{\"companies\": [{\"company\": \"Acme\", \"categories\": {\"eng\": {\"count\": 5}}}]}"
    ) as any;
    self.assertEqual(code, 0);
    self.assertIn("OK", out);
}

impl ValidateFlagTests.test_validate_flag_exits_0_on_duplicates_only -> any {
    code: any;
    out: any;
    (code, out) = self._run_validate(
        "{\"companies\": [{\"company\": \"Acme\"}, {\"company\": \"Acme\"}]}"
    ) as any;
    self.assertEqual(code, 0);
    self.assertIn("Duplicate company name", out);
}

impl NullShapeEndToEndTests._run_main(payload, *argv_tail_) -> any {
    argv_tail: any = tuple(argv_tail_);
    tmpdir: any;
    with tempfile.TemporaryDirectory() as tmpdir {
        data_file: any = Path(tmpdir) / "salary_data.json";
        data_file.write_text(payload, encoding="utf-8");
        original_data_file: any = salary_lookup.DATA_FILE;
        salary_lookup.DATA_FILE = data_file;
        argv_patch: any = mock.patch("sys.argv", ["salary_lookup.jac", *argv_tail]);
        argv_patch.start();
        try {
            stdout: any = io.StringIO();
            try {
                with redirect_stdout(stdout) {
                    salary_lookup.main();
                }
                return (None, stdout.getvalue());
            } except SystemExit as exc {
                return (exc.code, stdout.getvalue());
            }
        } finally {
            argv_patch.stop();
            salary_lookup.DATA_FILE = original_data_file;
        }
    }
}

impl NullShapeEndToEndTests.test_null_categories_passes_validate_then_renders -> any {
    payload: any = "{\"metadata\": {\"index_label\": \"Index\", \"index_baseline\": 100}, \"companies\": [{\"company\": \"Foo A/S\", \"city\": \"Aarhus\", \"categories\": null, \"engineering\": {\"count\": 10, \"index\": 105}}]}";

    code: any;
    out: any;
    (code, out) = self._run_main(payload, "--validate") as any;
    self.assertEqual(code, 0);
    self.assertIn("OK", out);

    (code, out) = self._run_main(payload, "Foo") as any;
    self.assertIsNone(code);
    self.assertIn("Foo A/S", out);
    self.assertRegex(out, "Engineering\\s+10\\s+105");
}

impl NullShapeEndToEndTests.test_null_metadata_passes_validate_then_renders -> any {
    payload: any = "{\"metadata\": null, \"companies\": [{\"company\": \"Foo A/S\", \"city\": \"Aarhus\", \"categories\": {\"engineering\": {\"count\": 10, \"index\": 105}}}]}";

    code: any;
    out: any;
    (code, out) = self._run_main(payload, "--validate") as any;
    self.assertEqual(code, 0);
    self.assertIn("OK", out);

    (code, out) = self._run_main(payload, "Foo") as any;
    self.assertIsNone(code);
    self.assertRegex(out, "Engineering\\s+10\\s+105");
}

impl UtilityTests.test_normalize_strips_suffix_and_noise -> any {
    self.assertEqual(normalize("Novo Nordisk A/S"), "novonordisk");
    self.assertEqual(normalize("Ørsted (VG) Holding"), "ørsted");
    self.assertEqual(normalize("Chr. Hansen, Denmark Division"), "chrhansen");
    self.assertEqual(normalize("Simple Corp ApS"), "simplecorp");
}

impl UtilityTests.test_normalize_strips_dotted_amba_suffix_same_as_undotted -> any {
    self.assertEqual(normalize("Arla Foods A.M.B.A."), normalize("Arla Foods amba"));
    self.assertEqual(normalize("Arla Foods A.M.B.A."), "arlafoods");
}

impl UtilityTests.test_anglicize_replaces_danish_chars -> any {
    self.assertEqual(anglicize("ørsted"), "orsted");
    self.assertEqual(anglicize("mærsk"), "maersk");
    self.assertEqual(anglicize("ålborg"), "aalborg");
}

impl UtilityTests.test_extract_core_words -> any {
    self.assertEqual(extract_core_words("Novo Nordisk A/S"), ["novo", "nordisk"]);
    self.assertEqual(extract_core_words("A/S"), []);
    self.assertEqual(extract_core_words("Test Company (Sub-entity)"), ["test", "company"]);
}

impl MatchScoreTests.test_exact_match_score -> any {
    self.assertEqual(match_score("Novo Nordisk", "Novo Nordisk"), 100);
    self.assertEqual(match_score("novo nordisk", "Novo Nordisk A/S"), 100);
}

impl MatchScoreTests.test_partial_match_score -> any {
    self.assertGreater(match_score("Novo", "Novo Nordisk A/S"), 80);
    self.assertEqual(match_score("Novo Nordisk", "Novo"), 75);
}

impl MatchScoreTests.test_anglicized_match_score -> any {
    self.assertEqual(match_score("Orsted", "Ørsted A/S"), 85);
}

impl MatchScoreTests.test_overlap_match_score -> any {
    self.assertGreater(match_score("Novo Tech", "Novo Nordisk Tech A/S"), 30);
}

impl MatchScoreTests.test_no_match_score -> any {
    self.assertEqual(match_score("Google", "Microsoft"), 0);
}

impl SearchCompanyRefactoredTests.setUp -> any {
    self.data = {
        "companies": [
            {"company": "Novo Nordisk A/S", "city": "Bagsværd"},
            {"company": "Ørsted", "city": "Fredericia"},
            {"company": "Vestas Wind Systems", "city": "Aarhus"},
        ],
    };
}

impl SearchCompanyRefactoredTests.test_search_by_name -> any {
    results: any = search_company(self.data, "Novo");
    self.assertEqual(len(results), 1);
    self.assertEqual(results[0]["company"], "Novo Nordisk A/S");
}

impl SearchCompanyRefactoredTests.test_search_with_city_filter -> any {
    results: any = search_company(self.data, "Ørsted", city="Fredericia");
    self.assertEqual(len(results), 1);
    results_wrong_city: any = search_company(self.data, "Ørsted", city="Bagsværd");
    self.assertEqual(len(results_wrong_city), 0);
}

impl TestSearchCompanyBasicMatch.test_exact_name_returns_match -> any {
    data: any = _make_data(_entry("Novo Nordisk", "Bagsværd"));
    results: any = search_company(data, "Novo Nordisk");
    self.assertEqual(len(results), 1);
    self.assertEqual(results[0]["company"], "Novo Nordisk");
}

impl TestSearchCompanyBasicMatch.test_no_match_returns_empty_list -> any {
    data: any = _make_data(_entry("Vestas Wind Systems", "Aarhus"));
    results: any = search_company(data, "Apple");
    self.assertEqual(results, []);
}

impl TestSearchCompanyBasicMatch.test_multiple_candidates_all_returned -> any {
    data: any = _make_data(
        _entry("Carlsberg A/S", "Copenhagen"),
        _entry("Carlsberg Danmark", "Fredericia"),
        _entry("Unrelated Corp", "Odense"),
    );
    results: any = search_company(data, "Carlsberg");
    companies: any = [r["company"] for r in results];
    self.assertIn("Carlsberg A/S", companies);
    self.assertIn("Carlsberg Danmark", companies);
    self.assertNotIn("Unrelated Corp", companies);
}

impl TestSearchCompanyCityFilter.test_matching_city_is_included -> any {
    data: any = _make_data(_entry("Novo Nordisk", "Bagsværd"), _entry("Novo Nordisk", "Aarhus"));
    results: any = search_company(data, "Novo Nordisk", city="Aarhus");
    self.assertEqual(len(results), 1);
    self.assertEqual(results[0]["city"], "Aarhus");
}

impl TestSearchCompanyCityFilter.test_non_matching_city_is_excluded -> any {
    data: any = _make_data(_entry("Novo Nordisk", "Bagsværd"));
    results: any = search_company(data, "Novo Nordisk", city="Odense");
    self.assertEqual(results, []);
}

impl TestSearchCompanyCityFilter.test_no_city_filter_returns_all_cities -> any {
    data: any = _make_data(_entry("Novo Nordisk", "Bagsværd"), _entry("Novo Nordisk", "Aarhus"));
    results: any = search_company(data, "Novo Nordisk");
    self.assertEqual(len(results), 2);
}

impl TestSearchCompanyCityFilter.test_city_filter_case_insensitive -> any {
    data: any = _make_data(_entry("Novo Nordisk", "København"));
    results: any = search_company(data, "Novo Nordisk", city="københavn");
    self.assertEqual(len(results), 1);
}

impl TestSearchCompanyCityFilter.test_anglicized_city_matches_danish_city -> any {
    data: any = _make_data(_entry("Novo Nordisk", "København"));
    results: any = search_company(data, "Novo Nordisk", city="kobenhavn");
    self.assertEqual(len(results), 1);
}

impl TestSearchCompanyScoreThreshold.test_low_score_matches_excluded -> any {
    data: any = _make_data(_entry("Novo Nordisk", "Bagsværd"));
    results: any = search_company(data, "xyz");
    self.assertEqual(results, []);
}

impl TestSearchCompanyScoreThreshold.test_results_sorted_by_relevance_descending -> any {
    data: any = _make_data(
        _entry("Novo Nordisk International", "Bagsværd"), _entry("Novo Nordisk", "Bagsværd")
    );
    results: any = search_company(data, "Novo Nordisk");
    self.assertEqual(results[0]["company"], "Novo Nordisk");
}

impl TestSalaryFileEncoding.setUp -> any {
    directory: any = tempfile.TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
    root_at(self, self.root);
    self.data_file = self.root / "salary_data.json";
    self.entry = {
        "company": "Novo Nordisk A/S",
        "city": "Bagsværd",
        "categories": {"engineering": {"count": 120, "index": 112.3}},
    };
}

impl TestSalaryFileEncoding.run_cli(*args_) -> any {
    args: any = tuple(args_);
    return subprocess.run(
        [*tool("salary_lookup"), *args],
        cwd=self.root,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=30,
    );
}

impl TestSalaryFileEncoding.test_utf8_with_and_without_bom -> any {
    payload: any = {"metadata": {"index_baseline": 100}, "companies": [self.entry]};
    for encoding in ("utf-8", "utf-8-sig") {
        with self.subTest(encoding=encoding) {
            self.data_file.write_text(json.dumps(payload, ensure_ascii=False), encoding=encoding);
            validated: any = self.run_cli("--validate");
            self.assertEqual(validated.returncode, 0, validated.stderr);
            self.assertIn("OK - no issues found.", validated.stdout);
            lookup: any = self.run_cli("Novo Nordisk", "--json");
            self.assertEqual(lookup.returncode, 0, lookup.stderr);
            self.assertEqual(json.loads(lookup.stdout), [self.entry]);
        }
    }
}

impl TestSalaryFileEncoding.test_bom_does_not_hide_invalid_json -> any {
    self.data_file.write_text("{\"companies\": [}", encoding="utf-8-sig");
    result: any = self.run_cli("--validate");
    self.assertEqual(result.returncode, 1);
    self.assertIn("invalid JSON at line 1, column 16", result.stderr);
    self.assertNotIn("Unexpected UTF-8 BOM", result.stderr);
}
