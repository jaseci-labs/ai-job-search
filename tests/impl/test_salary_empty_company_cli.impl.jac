impl EmptyCompanyWorkbookCLI.convert_and_validate(blank) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any = `root / "salary.xlsx";
        output: any = `root / "salary_data.json";
        book: any = openpyxl.Workbook();
        try {
            book.active.append(["Company", "Count", "Index"]);
            book.active.append(["Acme Corp", 12, 105]);
            book.active.append([blank, 20, 110]);
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
        root_at(self, `root);
        validation: any = subprocess.run(
            [*tool("salary_lookup"), "--validate"], capture_output=True, text=True, encoding="utf-8"
        );
        self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr);
        data: any = json.loads(output.read_text(encoding="utf-8"));
        self.assertEqual(
            data["companies"],
            [
                {
                    "company": "Acme Corp",
                    "city": "",
                    "categories": {"all_employees": {"count": 12, "index": 105.0}},
                },
            ],
        );
    }
}

impl EmptyCompanyWorkbookCLI.test_space_only_company_rows_are_skipped -> any {
    self.convert_and_validate("   ");
}

impl EmptyCompanyWorkbookCLI.test_truly_empty_company_rows_are_still_skipped -> any {
    self.convert_and_validate(None);
}
