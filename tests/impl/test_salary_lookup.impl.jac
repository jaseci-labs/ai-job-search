impl corp(categories: any, **extra: any) -> dict[str, any] {
    return {"company": "Example Corp", "city": "", "categories": categories, **extra};
}

impl LookupUnits.test_format_entry_rows_and_privacy_footnote {
    standard: dict[str, any] = {"index_baseline": 100, "index_label": "Index"};
    everyone: dict[str, any] = {"count": 500, "index": 108.5};
    salary: dict[str, any] = corp({"it": {"count": None, "index": 45000.0}});
    cases: list[tuple[dict[str, any], any, list[str], list[str]]] = [
        (
            corp({"all_employees": everyone}),
            standard,
            ["All Employees\\s+500\\s+108\\.5\\s+\\+8\\.5%"],
            ["N/A", PRIVACY_FOOTNOTE],
        ),
        (
            corp({"all_employees": everyone, "small_team": {"count": 3, "index": None}}),
            standard,
            ["Small Team\\s+3\\s+N/A\\*", "\\* N/A = Too few employees to publish \\(privacy\\)"],
            [],
        ),
        (
            corp({"public_data": {"count": 0, "index": 100.0}}),
            standard,
            ["Public Data\\s+0\\s+100\\.0"],
            [],
        ),
        (corp({"sample": {"count": 3, "index": "private"}}), standard, ["private"], []),
        (salary, {"index_baseline": 0, "index_label": "Salary"}, ["45000\\.0"], ["%"]),
        (
            salary,
            {"index_baseline": 40000, "index_label": "Salary"},
            ["45000\\.0", "\\+12\\.5%"],
            [],
        ),
        (
            corp(None, engineering={"count": 10, "index": 105.0}),
            standard,
            ["Engineering\\s+10\\s+105\\.0"],
            [],
        ),
        (corp({"eng": {"count": 5, "index": 108.0}}), None, ["Eng\\s+5\\s+108\\.0"], []),
    ];
    for (company, metadata, wanted, unwanted) in cases {
        with self.subTest(company=company, metadata=metadata) {
            rendered: str = format_entry(company, metadata);
            for pattern in wanted {
                self.assertRegex(rendered, pattern);
            }
            for text in unwanted {
                self.assertNotIn(text, rendered);
            }
        }
    }
}

impl LookupUnits.test_match_score {
    cases: list[tuple[str, str, int, int]] = [
        ("Novo Nordisk", "Novo Nordisk", 100, 100),
        ("NOVO NORDISK", "Novo Nordisk", 100, 100),
        ("novo nordisk", "Novo Nordisk A/S", 100, 100),
        ("Mærsk", "Mærsk A/S", 100, 100),
        ("Arla Foods", "Arla Foods A.M.B.A.", 100, 100),
        ("Aarsleff", "Aarsleff", 100, 100),
        ("Carlsberg", "Carlsberg Danmark A/S", 80, 100),
        ("Carlsberg Danmark", "Carlsberg", 80, 100),
        ("Novo", "Novo Nordisk A/S", 81, 100),
        ("Novo Nordisk", "Novo", 75, 75),
        ("Orsted", "Ørsted A/S", 85, 85),
        ("Maersk", "Mærsk A/S", 1, 100),
        ("IBM", "IBM Corporation", 1, 100),
        ("Novo Tech", "Novo Nordisk Tech A/S", 31, 100),
        ("ab", "Something Unrelated Company", 0, 0),
        ("Apple", "Vestas Wind Systems", 0, 0),
        ("Google", "Microsoft", 0, 0),
        ("", "Novo Nordisk", 0, 0),
        ("Novo Nordisk", "", 0, 0),
    ];
    for (query, name, low, high) in cases {
        with self.subTest(query=query, name=name) {
            score: int = match_score(query, name);
            self.assertTrue(low <= score <= high, score);
        }
    }
}

impl LookupUnits.test_text_helpers {
    cases: list[tuple[any, str, any]] = [
        (normalize, "Novo Nordisk A/S", "novonordisk"),
        (normalize, "Ørsted (VG) Holding", "ørsted"),
        (normalize, "Chr. Hansen, Denmark Division", "chrhansen"),
        (normalize, "Simple Corp ApS", "simplecorp"),
        (normalize, "Arla Foods A.M.B.A.", "arlafoods"),
        (normalize, "Arla Foods amba", "arlafoods"),
        (anglicize, "ørsted", "orsted"),
        (anglicize, "mærsk", "maersk"),
        (anglicize, "ålborg", "aalborg"),
        (extract_core_words, "Novo Nordisk A/S", ["novo", "nordisk"]),
        (extract_core_words, "A/S", []),
        (extract_core_words, "Test Company (Sub-entity)", ["test", "company"]),
    ];
    for (helper, text, expected) in cases {
        with self.subTest(helper=helper.__name__, text=text) {
            self.assertEqual(helper(text), expected);
        }
    }
}

impl LookupUnits.test_search_company_ranks_and_filters_by_city {
    novo: tuple[str, str] = ("Novo Nordisk", "Bagsværd");
    novo_aarhus: tuple[str, str] = ("Novo Nordisk", "Aarhus");
    copenhagen: tuple[str, str] = ("Novo Nordisk", "København");
    carlsberg: list[tuple[str, str]] = [
        ("Carlsberg A/S", "Copenhagen"),
        ("Carlsberg Danmark", "Fredericia"),
    ];
    cases: list[any] = [
        ([("Acme", None)], "Acme", "Aarhus", []),
        (NORDIC, "Novo", None, NORDIC[:1]),
        (NORDIC, "Ørsted", "Fredericia", NORDIC[1:2]),
        (NORDIC, "Ørsted", "Bagsværd", []),
        ([novo], "Novo Nordisk", None, [novo]),
        ([("Vestas Wind Systems", "Aarhus")], "Apple", None, []),
        ([*carlsberg, ("Unrelated Corp", "Odense")], "Carlsberg", None, carlsberg),
        ([novo, novo_aarhus], "Novo Nordisk", "Aarhus", [novo_aarhus]),
        ([novo], "Novo Nordisk", "Odense", []),
        ([novo, novo_aarhus], "Novo Nordisk", None, [novo, novo_aarhus]),
        ([copenhagen], "Novo Nordisk", "københavn", [copenhagen]),
        ([copenhagen], "Novo Nordisk", "kobenhavn", [copenhagen]),
        ([novo], "xyz", None, []),
        (
            [("Novo Nordisk International", "Bagsværd"), novo],
            "Novo Nordisk",
            None,
            [novo, ("Novo Nordisk International", "Bagsværd")],
        ),
    ];
    for (companies, query, city, expected) in cases {
        with self.subTest(query=query, city=city, companies=companies) {
            data: dict[str, any] = {
                "companies": [{"company": name, "city": place} for (name, place) in companies],
            };
            self.assertEqual(
                [(c["company"], c["city"]) for c in search_company(data, query, city)], expected
            );
        }
    }
}

impl LookupUnits.test_invalid_data_exits_with_the_first_error {
    entries: list[tuple[any, str]] = [
        ("Example Corp", "companies[1] must be an object"),
        ({"city": "Aarhus"}, "companies[1].company must be a non-empty string"),
        ({"company": "  "}, "companies[1].company must be a non-empty string"),
        (
            {"company": "Example Corp", "city": 123},
            "companies[1].city must be a string when provided",
        ),
        (corp([]), "companies[1].categories must be an object when provided"),
        (corp({"eng": "not_a_dict"}), "must be an object with 'count' and/or 'index'"),
        (corp({"eng": {"count": "many"}}), "count must be a number"),
    ];
    cases: list[tuple[any, str]] = [
        ([], "top-level JSON value must be an object"),
        ({"companies": corp({})}, "'companies' must be a list"),
        ({"metadata": [], "companies": [corp({})]}, "'metadata' must be an object when provided"),
        *[({"companies": [company]}, message) for (company, message) in entries],
    ];
    for (data, message) in cases {
        with self.subTest(data=data) {
            stderr: io.StringIO = io.StringIO();
            with self.assertRaises(SystemExit) as raised {
                with redirect_stderr(stderr) {
                    validate_data(data);
                }
            }
            self.assertEqual(raised.exception.code, 1);
            for text in (
                "Error: invalid salary_data.json",
                message,
                "tools/README_SALARY_TOOL.md",
            ) {
                self.assertIn(text, stderr.getvalue());
            }
        }
    }
}

impl LookupUnits.test_valid_data_and_duplicate_warnings {
    minimal: dict[str, any] = {"metadata": {}, "companies": [{"company": "Example Corp"}]};
    self.assertIs(validate_data(minimal), minimal);
    self.assertEqual(
        collect_validation_issues({"companies": [corp({"eng": {"count": 5, "index": 108.5}})]}),
        ([], []),
    );
    (errors, warnings) = collect_validation_issues({
        "companies": [{"company": "Acme"}, {"company": "Other Corp"}, {"company": "Acme"}],
    });
    self.assertEqual((errors, len(warnings)), ([], 1));
    self.assertIn("Duplicate company name 'Acme'", warnings[0]);
}

impl LookupCLI.setUp {
    directory: tempfile.TemporaryDirectory = tempfile.TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.home = Path(directory.name);
    root_at(self, self.home);
}

impl LookupCLI.write(data: any, encoding: str = "utf-8") -> None {
    (self.home / "salary_data.json").write_text(
        data if isinstance(data, str) else json.dumps(data, ensure_ascii=False), encoding=encoding
    );
}

impl LookupCLI.run_cli(*args: str) -> subprocess.CompletedProcess {
    return subprocess.run(
        [*tool("salary_lookup"), *args],
        cwd=self.home,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=30,
    );
}

impl LookupCLI.found(query: str) -> list[str] {
    result: subprocess.CompletedProcess = self.run_cli(query, "--json");
    self.assertEqual(result.returncode, 0, result.stderr + result.stdout);
    return [row["company"] for row in json.loads(result.stdout)];
}

impl LookupCLI.test_validate_reports_errors_and_warnings {
    cases: list[tuple[list[any], int, str]] = [
        (
            [{"company": "Acme", "categories": {"eng": "not_a_dict"}}],
            1,
            "must be an object with 'count' and/or 'index'",
        ),
        ([{"company": "Acme", "categories": {"eng": {"count": 5}}}], 0, "OK"),
        ([{"company": "Acme"}, {"company": "Acme"}], 0, "Duplicate company name"),
    ];
    for (companies, code, phrase) in cases {
        with self.subTest(phrase=phrase) {
            self.write({"companies": companies});
            result: subprocess.CompletedProcess = self.run_cli("--validate");
            self.assertEqual(result.returncode, code, result.stderr);
            self.assertIn(phrase, result.stdout);
        }
    }
}

impl LookupCLI.test_null_categories_and_null_metadata_validate_then_render {
    engineering: dict[str, any] = {"count": 10, "index": 105};
    foo: dict[str, any] = {"company": "Foo A/S", "city": "Aarhus"};
    for data in (
        {
            "metadata": {"index_label": "Index", "index_baseline": 100},
            "companies": [{**foo, "categories": None, "engineering": engineering}],
        },
        {"metadata": None, "companies": [{**foo, "categories": {"engineering": engineering}}]},
    ) {
        with self.subTest(data=data) {
            self.write(data);
            validated: subprocess.CompletedProcess = self.run_cli("--validate");
            self.assertEqual(validated.returncode, 0, validated.stderr);
            self.assertIn("OK", validated.stdout);
            rendered: subprocess.CompletedProcess = self.run_cli("Foo");
            self.assertEqual(rendered.returncode, 0, rendered.stderr);
            self.assertIn("Foo A/S", rendered.stdout);
            self.assertRegex(rendered.stdout, "Engineering\\s+10\\s+105");
        }
    }
}

impl LookupCLI.test_json_parse_errors_have_no_traceback {
    self.write("{\"companies\": [");
    lookup: subprocess.CompletedProcess = self.run_cli("Acme");
    self.assertEqual(lookup.returncode, 1);
    for text in ("invalid JSON at line", "tools/README_SALARY_TOOL.md") {
        self.assertIn(text, lookup.stderr);
    }
    self.assertNotIn("Traceback", lookup.stderr);
    self.write("{\"companies\": [}", "utf-8-sig");
    validated: subprocess.CompletedProcess = self.run_cli("--validate");
    self.assertEqual(validated.returncode, 1);
    self.assertIn("invalid JSON at line 1, column 16", validated.stderr);
    self.assertNotIn("Unexpected UTF-8 BOM", validated.stderr);
}

impl LookupCLI.test_utf8_with_and_without_bom {
    company: dict[str, any] = {
        "company": "Novo Nordisk A/S",
        "city": "Bagsværd",
        "categories": {"engineering": {"count": 120, "index": 112.3}},
    };
    for encoding in ("utf-8", "utf-8-sig") {
        with self.subTest(encoding=encoding) {
            self.write({"metadata": {"index_baseline": 100}, "companies": [company]}, encoding);
            validated: subprocess.CompletedProcess = self.run_cli("--validate");
            self.assertEqual(validated.returncode, 0, validated.stderr);
            self.assertIn("OK - no issues found.", validated.stdout);
            lookup: subprocess.CompletedProcess = self.run_cli("Novo Nordisk", "--json");
            self.assertEqual(lookup.returncode, 0, lookup.stderr);
            self.assertEqual(json.loads(lookup.stdout), [company]);
        }
    }
}

impl LookupCLI.test_unusable_metadata_is_rejected {
    cases: list[tuple[str, any, str]] = [
        ("index_baseline", "150", "--validate"),
        ("index_baseline", "150", "Acme"),
        ("index_label", ["Salary"], "--validate"),
        *[
            ("index_baseline", baseline, "--validate")
            for baseline in [True, None, float("inf"), float("nan"), 10 ** 400]
        ],
    ];
    for (field, value, arg) in cases {
        with self.subTest(field=field, value=value, arg=arg) {
            self.write({"metadata": {field: value}, "companies": [{"company": "Acme"}]});
            result: subprocess.CompletedProcess = self.run_cli(arg);
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
            self.assertIn(field, result.stdout if arg == "--validate" else result.stderr);
            self.assertNotIn("Traceback", result.stderr);
        }
    }
}

impl LookupCLI.test_baseline_and_optional_metadata_controls {
    cases: list[tuple[any, str | None]] = [
        ({"index_baseline": 150, "index_label": "Salary"}, "+10.0%"),
        ({"index_baseline": 0}, None),
        ({}, "+65.0%"),
        (None, "+65.0%"),
    ];
    for (metadata, percentage) in cases {
        with self.subTest(metadata=metadata) {
            self.write({
                "metadata": metadata,
                "companies": [{"company": "Acme", "categories": {"all_employees": {"index": 165}}}],
            });
            result: subprocess.CompletedProcess = self.run_cli("Acme");
            self.assertEqual(result.returncode, 0, result.stderr);
            if percentage {
                self.assertIn(percentage, result.stdout);
            } else {
                self.assertNotIn("%", result.stdout);
            }
        }
    }
}

impl LookupCLI.test_explicit_null_index_keeps_the_suppression_marker {
    self.write({"companies": [corp({"small_team": {"count": 3, "index": None}})]});
    result: subprocess.CompletedProcess = self.run_cli("Example Corp");
    self.assertEqual(result.returncode, 0, result.stderr);
    for text in ("N/A*", "Too few employees to publish (privacy)") {
        self.assertIn(text, result.stdout);
    }
}

impl LookupCLI.test_unicode_and_nordic_spellings_find_the_company {
    thekking: str = "Þekkingarmiðlun ehf.";
    cases: list[tuple[str, str]] = [
        ("腾讯", "腾讯"),
        ("Café Étoile", "Café Étoile"),
        ("acme", "Acme Corp"),
        ("Nestle", "Nestlé Danmark A/S"),
        ("Orsted", "Ørsted A/S"),
        ("Maersk", "Mærsk A/S"),
        ("Aaland", "Åland A/S"),
        ("Thekkingarmidlun", thekking),
        ("THEKKINGARMIDLUN", thekking),
        ("Þekkingarmiðlun", thekking),
        ("ÞEKKINGARMIÐLUN", thekking),
    ];
    self.write({"companies": [{"company": name, "categories": INDEXED} for name in UNICODE_NAMES]});
    for (query, expected) in cases {
        with self.subTest(query=query) {
            self.assertEqual(self.found(query), [expected]);
        }
    }
    self.assertEqual(self.found("東京 AI")[0], "東京 AI");
    self.write({"companies": [{"company": "Thekkingarmidlun", "categories": INDEXED}]});
    for query in ("Þekkingarmiðlun", "ÞEKKINGARMIÐLUN") {
        with self.subTest(query=query, data="ascii") {
            self.assertEqual(self.found(query), ["Thekkingarmidlun"]);
        }
    }
}
