impl CombinedCityWorkbookCLI.convert_and_lookup(headers, row, *lookup_args_) -> any {
    lookup_args: any = tuple(lookup_args_);
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any = `root / "salary.xlsx";
        output: any = `root / "salary_data.json";
        book: any = openpyxl.Workbook();
        try {
            book.active.append(headers);
            book.active.append(row);
            book.save(workbook);
        } finally {
            book.close();
        }
        conversion: any = subprocess.run(
            [*tool("convert_salary_excel"), `str(workbook), "--output", `str(output)],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
        self.assertEqual(conversion.returncode, 0, conversion.stderr);
        companies: any = json.loads(output.read_text(encoding="utf-8"))["companies"];
        root_at(self, `root);
        lookup: any = subprocess.run(
            [*tool("salary_lookup"), *lookup_args], capture_output=True, text=True, encoding="utf-8"
        );
        return (companies, lookup);
    }
}

impl CombinedCityWorkbookCLI.test_ida_firmanavn_og_by_row_is_findable_with_city_filter -> any {
    companies: any;
    lookup: any;
    (companies, lookup) = self.convert_and_lookup(
        ["Firmanavn og by", "Antal", "Indeks"],
        ["Ørsted A/S,Fredericia", 200, 105.2],
        "Ørsted",
        "--city",
        "Fredericia",
    ) as any;
    self.assertEqual(
        companies,
        [
            {
                "company": "Ørsted A/S",
                "city": "Fredericia",
                "categories": {"all_employees": {"count": 200, "index": 105.2}},
            },
        ],
    );
    self.assertEqual(lookup.returncode, 0, lookup.stdout + lookup.stderr);
    self.assertIn("Ørsted A/S", lookup.stdout);
    self.assertIn("Fredericia", lookup.stdout);
    self.assertNotIn("No results found", lookup.stdout);
}

impl CombinedCityWorkbookCLI.test_separate_city_column_is_unchanged -> any {
    companies: any;
    lookup: any;
    (companies, lookup) = self.convert_and_lookup(
        ["Company", "City", "Count", "Index"],
        ["Novo Nordisk A/S", "Bagsværd", 500, 108.5],
        "Novo Nordisk",
        "--city",
        "Bagsværd",
    ) as any;
    self.assertEqual(companies[0]["company"], "Novo Nordisk A/S");
    self.assertEqual(companies[0]["city"], "Bagsværd");
    self.assertEqual(lookup.returncode, 0, lookup.stdout + lookup.stderr);
    self.assertIn("Novo Nordisk A/S", lookup.stdout);
}
