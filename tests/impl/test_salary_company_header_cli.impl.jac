impl CompanyHeaderCLI.convert(header) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any;
        output: any;
        (workbook, output) = (`root / "salary.xlsx", `root / "salary.json");
        book: any = openpyxl.Workbook();
        try {
            book.active.append(header);
            book.active.append(["Acme Corp", "Berlin", 25, 108.5]);
            book.save(workbook);
        } finally {
            book.close();
        }
        result: any = subprocess.run(
            [*TOOL, `str(workbook), "--output", `str(output)],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
        self.assertEqual(result.returncode, 0, result.stderr);
        return json.loads(output.read_text(encoding="utf-8"))["companies"];
    }
}

impl CompanyHeaderCLI.test_company_prefixed_salary_columns_do_not_replace_the_company -> any {
    self.assertEqual(
        self.convert(["Company", "City", "Company Count", "Company Index"]),
        [
            {
                "company": "Acme Corp",
                "city": "Berlin",
                "categories": {"company": {"count": 25, "index": 108.5}},
            },
        ],
    );
}

impl CompanyHeaderCLI.test_existing_named_category_control -> any {
    self.assertEqual(
        self.convert(["Company Name", "City", "Engineering Count", "Engineering Index"]),
        [
            {
                "company": "Acme Corp",
                "city": "Berlin",
                "categories": {"engineering": {"count": 25, "index": 108.5}},
            },
        ],
    );
}

impl CompanyHeaderCLI.test_city_prefixed_salary_columns_do_not_replace_the_city -> any {
    self.assertEqual(
        self.convert(["Company", "City", "City Count", "City Index"]),
        [
            {
                "company": "Acme Corp",
                "city": "Berlin",
                "categories": {"city": {"count": 25, "index": 108.5}},
            },
        ],
    );
}
