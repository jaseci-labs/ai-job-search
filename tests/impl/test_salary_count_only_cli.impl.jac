impl CountOnlySalaryCLI.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
    root_at(self, self.root);
}

impl CountOnlySalaryCLI.lookup -> any {
    result: any = subprocess.run(
        [*tool("salary_lookup"), "Acme Corp"], capture_output=True, text=True, encoding="utf-8"
    );
    self.assertEqual(result.returncode, 0, result.stderr);
    return result.stdout;
}

impl CountOnlySalaryCLI.convert(headers, row) -> any {
    workbook: any = self.root / "salary.xlsx";
    book: any = openpyxl.Workbook();
    try {
        book.active.append(headers);
        book.active.append(row);
        book.save(workbook);
    } finally {
        book.close();
    }
    result: any = subprocess.run(
        [
            *tool("convert_salary_excel"),
            `str(workbook),
            "--output",
            `str(self.root / "salary_data.json"),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
    );
    self.assertEqual(result.returncode, 0, result.stderr);
}

impl CountOnlySalaryCLI.test_count_only_workbook_does_not_claim_privacy_suppression -> any {
    self.convert(["Company", "Count"], ["Acme Corp", 500]);
    output: any = self.lookup();
    self.assertRegex(output, "Count\\s+500\\s+-");
    self.assertNotIn("N/A", output);
    self.assertNotIn("privacy", output);
}

impl CountOnlySalaryCLI.test_paired_numeric_index_control -> any {
    self.convert(["Company", "Count", "Index"], ["Acme Corp", 500, 108.5]);
    output: any = self.lookup();
    self.assertIn("108.5", output);
    self.assertIn("+8.5%", output);
    self.assertNotIn("privacy", output);
}

impl CountOnlySalaryCLI.test_explicit_null_index_keeps_the_existing_suppression_marker -> any {
    (self.root / "salary_data.json").write_text(
        json.dumps({
            "companies": [
                {"company": "Acme Corp", "categories": {"small_team": {"count": 3, "index": None}}},
            ],
        }),
        encoding="utf-8",
    );
    output: any = self.lookup();
    self.assertIn("N/A*", output);
    self.assertIn("Too few employees to publish (privacy)", output);
}
