impl FakeWorksheet.iter_rows(
    min_row: int = 1, max_row: int | None = None, values_only: bool = False
) -> list[any] {
    rows: list[any] = self.rows[min_row - 1:]
        if max_row is None
        else self.rows[min_row - 1:max_row];
    return rows if values_only else [self[n] for n in range(min_row, min_row + len(rows))];
}

impl FakeWorksheet.__getitem__(row_number: int) -> list[any] {
    return [SimpleNamespace(value=value) for value in self.rows[row_number - 1]];
}

impl parsed(*rows: any) -> list[tuple[str, str, any]] {
    return [
        (c["company"], c["city"], c["categories"])
        for c in parse_sheet(FakeWorksheet(list(rows)))
    ];
}

impl both(count: any, index: any) -> dict[str, any] {
    return {"count": count, "index": index};
}

impl ConverterUnits.test_header_classification {
    kinds: list[tuple[str, str | None]] = [
        ("Index", "index"),
        ("Salary Index", "index"),
        ("Engineering Index", "index"),
        ("Median salary", "index"),
        ("Accounting Index", "index"),
        ("Lønindeks", "index"),
        ("Count", "count"),
        ("Engineering Count", "count"),
        ("Antal medarbejdere", "count"),
        ("Employee n", "count"),
        ("Engineering", None),
        ("Accounting Total", None),
    ];
    for (header, kind) in kinds {
        with self.subTest(header=header) {
            self.assertEqual(detect_column_type(header), kind);
        }
    }
    matches: list[tuple[str, set[str], bool]] = [
        ("lønindeks", INDEX_PATTERNS, True),
        ("salaryindex", INDEX_PATTERNS, False),
        ("salary index", INDEX_PATTERNS, True),
        ("Firmanavn og by", COMPANY_PATTERNS, True),
    ];
    for (header, patterns, expected) in matches {
        with self.subTest(header=header) {
            self.assertEqual(header_matches(header, patterns), expected);
        }
    }
}

impl ConverterUnits.test_parse_numeric_cell_locales {
    for (text, number) in [
        ("1,234.56", 1234.56),
        ("1,234,567.89", 1234567.89),
        ("1.234,56", 1234.56),
        ("1.234.567,89", 1234567.89),
    ] {
        with self.subTest(text=text) {
            self.assertEqual(parse_numeric_cell(text), number);
        }
    }
}

impl ConverterUnits.test_parse_sheet_finds_columns_and_pairs_categories {
    salary: dict[str, any] = {"salary_index": {"index": 105.5}};
    everyone: dict[str, any] = {"all_employees": both(25, 108.5)};
    combined: tuple[str, str, str] = ("Firmanavn og by", "Antal", "Indeks");
    danish: tuple[str, str, str, str] = ("Firma", "By", "Antal alle", "Lønindeks alle");
    novo: tuple[str, str, int, float] = ("Novo Nordisk A/S", "Bagsværd", 500, 108.5);
    novo_parsed: tuple[str, str, any] = (
        "Novo Nordisk A/S",
        "Bagsværd",
        {"alle": both(500, 108.5)},
    );
    cases: list[any] = [
        *[
            (
                [("Company", f"{name} Count", f"{name} Index"), ("Example Corp", 12, 105.5)],
                [("Example Corp", "", {name.lower().replace(" ", "_"): both(12, 105.5)})],
            )
            for name in ("Engineering", "Accounting", "Software Engineering")
        ],
        *[
            (
                [(header, "Salary"), ("Example Corp", 105.5)],
                [("Example Corp", "", {"salary": {"index": 105.5}})],
            )
            for header in ("Company", "Company Name", "Employer Name")
        ],
        *[
            (
                [("Company", header, "Salary"), ("Example Corp", "Aarhus", 105.5)],
                [("Example Corp", "Aarhus", {"salary": {"index": 105.5}})],
            )
            for header in ("City", "City Name", "Kommune", "City/Kommune")
        ],
        (
            [combined, ("Example A/S,Aarhus", 12, 105.0)],
            [("Example A/S", "Aarhus", {"all_employees": both(12, 105.0)})],
        ),
        (
            [("Company", "Antal", "Indeks"), ("Acme, Inc.", 12, 105.0)],
            [("Acme, Inc.", "", {"all_employees": both(12, 105.0)})],
        ),
        (
            [("Company and City", "Count", "Index"), ("Ørsted A/S,Kongens Lyngby", 200, 105.2)],
            [("Ørsted A/S", "Kongens Lyngby", {"all_employees": both(200, 105.2)})],
        ),
        (
            [
                combined,
                ("Rambøll Danmark A/S, Odense,Odense C", 12, 105.0),
                ("Ørsted A/S,Fredericia", 200, 105.2),
            ],
            [
                ("Rambøll Danmark A/S, Odense", "Odense C", {"all_employees": both(12, 105.0)}),
                ("Ørsted A/S", "Fredericia", {"all_employees": both(200, 105.2)}),
            ],
        ),
        ([combined, ("Acme A/S", 25, 108.5)], [("Acme A/S", "", everyone)]),
        (
            [
                ("Company", "City", "Engineering Count", "Engineering Index"),
                ("Example Corp",),
                ("Other Corp", "Aarhus", 12, 105.5),
            ],
            [("Example Corp", "", {}), ("Other Corp", "Aarhus", {"engineering": both(12, 105.5)})],
        ),
        (
            [("Notes", "Company", "Salary Index"), ("stray",), ("", "Example Corp", 105.5)],
            [("Example Corp", "", salary)],
        ),
        (
            [("Company", "Salary Index", "Notes"), ("Example Corp", 105.5, "good")],
            [("Example Corp", "", salary)],
        ),
        (
            [("Company", "Salary Index", "Id"), ("Example Corp", 105.5, 7)],
            [("Example Corp", "", salary)],
        ),
        ([("Company", "Salary Index"), ("Example Corp", 105.5)], [("Example Corp", "", salary)]),
        (
            [
                ("Company", "Engineering Count", "Engineering Index"),
                ("Example Corp", "12,0", "108,5"),
            ],
            [("Example Corp", "", {"engineering": both(12, 108.5)})],
        ),
        *[
            (
                [("Company", "Salary Index"), ("Example Corp", text)],
                [("Example Corp", "", categories)],
            )
            for (text, categories) in [
                ("1.234,5", {"salary_index": {"index": 1234.5}}),
                ("1,234.56", {"salary_index": {"index": 1234.56}}),
                ("1,234", {}),
                ("1.234", {}),
            ]
        ],
        (
            [
                ("Company", "Antal kvinder", "Antal mænd", "Kvinder indeks", "Mænd indeks"),
                ("Example Corp", 15, 20, 95.0, 108.0),
            ],
            [("Example Corp", "", {"kvinder": both(15, 95.0), "mænd": both(20, 108.0)})],
        ),
        (
            [("Company", "Antal", "IT Count", "IT Index"), ("Example Corp", 250, 30, 108.5)],
            [("Example Corp", "", {"antal": {"count": 250}, "it": both(30, 108.5)})],
        ),
        (
            [
                ("Company", "Count_A", "Count_B", "Index_A", "Index_B"),
                ("Example Corp", 10, 20, 100.0, 200.0),
            ],
            [("Example Corp", "", {"a": both(10, 100.0), "b": both(20, 200.0)})],
        ),
        (
            [
                ("Lønstatistik 2025",),
                ("Kilde: Medlemsundersøgelse opdelt efter arbejdsgiver og branche",),
                (),
                danish,
                novo,
                ("Ørsted A/S", "Fredericia", 200, 105.2),
            ],
            [novo_parsed, ("Ørsted A/S", "Fredericia", {"alle": both(200, 105.2)})],
        ),
        (
            [
                ("Lønstatistik 2025",),
                ("Kilde: undersøgelse opdelt efter arbejdsgiver, antal svar 1234",),
                (),
                danish,
                novo,
            ],
            [novo_parsed],
        ),
        (
            [("Company", "Base pay 2025", "Bonus 2025"), ("Example Corp", 55000, 5000)],
            [
                (
                    "Example Corp",
                    "",
                    {"base_pay_2025": {"index": 55000.0}, "bonus_2025": {"index": 5000.0}},
                ),
            ],
        ),
        (
            [("Company", "City", "Count", "Index"), ("Acme Corp", "Copenhagen", 500, 108.5)],
            [("Acme Corp", "Copenhagen", {"all_employees": both(500, 108.5)})],
        ),
        (
            [("Firma", "By", "Antal", "Lønindeks"), ("Acme Corp", "Aarhus", 500, 108.5)],
            [("Acme Corp", "Aarhus", {"all_employees": both(500, 108.5)})],
        ),
        (
            [
                ("Company", "Antal", "IT Count", "IT Index", "Lønindeks"),
                ("Acme Corp", 500, 30, 112.0, 108.5),
            ],
            [("Acme Corp", "", {"all_employees": both(500, 108.5), "it": both(30, 112.0)})],
        ),
        (
            [
                ("Company Name", "City", "Company Count", "Company Index"),
                ("Acme Corp", "Berlin", 25, 108.5),
            ],
            [("Acme Corp", "Berlin", {"company": both(25, 108.5)})],
        ),
        (
            [("Firmanavn og by", "Antal", "Firmaets indeks"), ("Acme A/S", 25, 108.5)],
            [("Acme A/S", "", {"antal": {"count": 25}, "firmaets_indeks": {"index": 108.5}})],
        ),
        (
            [("Company Name", "Company", "Salary Index"), ("Acme Corp (legal)", "Acme", 108.5)],
            [("Acme", "", {"salary_index": {"index": 108.5}})],
        ),
        (
            [
                ("Company and city", "City name", "Count", "Index"),
                ("Acme Corp", "Berlin", 25, 108.5),
            ],
            [("Acme Corp", "Berlin", everyone)],
        ),
        (
            [
                ("Firmanavn og by", "City name", "Antal", "Indeks"),
                ("Acme A/S", "Aarhus", 25, 108.5),
            ],
            [("Acme A/S", "Aarhus", everyone)],
        ),
        (
            [("Firma", "Antal alle", "Lønindeks alle"), ("Example Corp", 12, 118.0)],
            [("Example Corp", "", {"alle": both(12, 118.0)})],
        ),
    ];
    for (rows, expected) in cases {
        with self.subTest(rows=rows) {
            self.assertEqual(parsed(*rows), expected);
        }
    }
}

impl ConverterUnits.test_parse_sheet_warns_when_no_salary_columns_detected {
    stderr: io.StringIO = io.StringIO();
    with redirect_stderr(stderr) {
        companies: list[tuple[str, str, any]] = parsed(
            ("Company", "City"), ("Example Corp", "Aarhus")
        );
    }
    self.assertEqual(companies, [("Example Corp", "Aarhus", {})]);
    self.assertIn("No salary data columns detected", stderr.getvalue());
}

impl ConverterUnits.test_lookup_renders_a_bare_pair_as_one_row {
    company: dict[str, any] = parse_sheet(
        FakeWorksheet([
            ("Company", "City", "Count", "Index"),
            ("Acme Corp", "Copenhagen", 500, 108.5),
        ]),
    )[0];
    rendered: str = format_entry(company, {"index_baseline": 100, "index_label": "Index"});
    self.assertNotIn("N/A*", rendered.split("* N/A =")[0]);
    self.assertRegex(rendered, "All Employees\\s+500\\s+108\\.5\\s+\\+8\\.5%");
    self.assertNotRegex(rendered, "^\\s*Count\\s+500");
}
