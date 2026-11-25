impl UnicodeSalaryCLI.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
    root_at(self, self.root);
    names: any = [
        "腾讯",
        "東京 AI",
        "北京 AI",
        "Acme Corp",
        "Café Étoile",
        "Nestlé Danmark A/S",
        "Ørsted A/S",
        "Mærsk A/S",
        "Åland A/S",
        "Þekkingarmiðlun ehf.",
    ];
    data: any = {
        "companies": [
            {"company": name, "categories": {"all_employees": {"index": 105}}}
            for name in names
        ],
    };
    (self.root / "salary_data.json").write_text(
        json.dumps(data, ensure_ascii=False), encoding="utf-8"
    );
}

impl UnicodeSalaryCLI.lookup(query) -> any {
    result: any = subprocess.run(
        [*tool("salary_lookup"), query, "--json"], capture_output=True, text=True, encoding="utf-8"
    );
    self.assertEqual(result.returncode, 0, result.stderr + result.stdout);
    return [row["company"] for row in json.loads(result.stdout)];
}

impl UnicodeSalaryCLI.test_exact_non_latin_company_can_be_found -> any {
    self.assertEqual(self.lookup("腾讯"), ["腾讯"]);
}

impl UnicodeSalaryCLI.test_mixed_script_companies_do_not_collapse_to_a_latin_fragment -> any {
    self.assertEqual(self.lookup("東京 AI")[0], "東京 AI");
}

impl UnicodeSalaryCLI.test_canonically_equivalent_spelling_finds_the_same_company -> any {
    self.assertEqual(self.lookup("Café Étoile"), ["Café Étoile"]);
}

impl UnicodeSalaryCLI.test_ascii_control_still_matches -> any {
    self.assertEqual(self.lookup("acme"), ["Acme Corp"]);
}

impl UnicodeSalaryCLI.test_ascii_query_finds_accented_company -> any {
    self.assertEqual(self.lookup("Nestle"), ["Nestlé Danmark A/S"]);
}

impl UnicodeSalaryCLI.test_nordic_spelling_variants_survive_accent_folding -> any {
    for (query, expected) in [
        ("Orsted", "Ørsted A/S"),
        ("Maersk", "Mærsk A/S"),
        ("Aaland", "Åland A/S"),
    ] {
        with self.subTest(query=query) {
            self.assertEqual(self.lookup(query), [expected]);
        }
    }
}

impl UnicodeSalaryCLI.test_official_ascii_and_native_nordic_company_spellings_match -> any {
    for query in ("Thekkingarmidlun", "THEKKINGARMIDLUN", "Þekkingarmiðlun", "ÞEKKINGARMIÐLUN") {
        with self.subTest(query=query) {
            self.assertEqual(self.lookup(query), ["Þekkingarmiðlun ehf."]);
        }
    }
}

impl UnicodeSalaryCLI.test_native_nordic_query_finds_ascii_company_data -> any {
    (self.root / "salary_data.json").write_text(
        json.dumps({
            "companies": [
                {"company": "Thekkingarmidlun", "categories": {"all_employees": {"index": 105}}},
            ],
        }),
        encoding="utf-8",
    );
    for query in ("Þekkingarmiðlun", "ÞEKKINGARMIÐLUN") {
        with self.subTest(query=query) {
            self.assertEqual(self.lookup(query), ["Thekkingarmidlun"]);
        }
    }
}
