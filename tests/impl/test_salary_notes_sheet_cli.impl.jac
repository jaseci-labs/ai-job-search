impl NotesSheetCLI.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
    root_at(self, self.root);
    self.output = self.root / "salary_data.json";
}

impl NotesSheetCLI.convert(with_data) -> any {
    workbook: any = self.root / "salary.xlsx";
    book: any = openpyxl.Workbook();
    try {
        sheet: any = book.active;
        if with_data {
            sheet.title = "Data";
            sheet.append(["Company", "City", "Count", "Index"]);
            sheet.append(["Acme", "Aarhus", 10, 105]);
            sheet = book.create_sheet("Notes");
        } else {
            sheet.title = "Notes";
        }
        for line in NOTES {
            sheet.append(line);
        }
        book.save(workbook);
    } finally {
        book.close();
    }
    return subprocess.run(
        [*tool("convert_salary_excel"), `str(workbook), "--output", `str(self.output)],
        cwd=self.root,
        capture_output=True,
        text=True,
    );
}

impl NotesSheetCLI.test_notes_tab_sentences_are_not_listed_as_companies -> any {
    result: any = self.convert(with_data=True);
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    self.assertIn("Skipping sheet 'Notes'", result.stderr);
    companies: any = json.loads(self.output.read_text(encoding="utf-8"))["companies"];
    self.assertEqual([`entry["company"] for `entry in companies], ["Acme"]);
    listed: any = subprocess.run(
        [*tool("salary_lookup"), "--list-all"], cwd=self.root, capture_output=True, text=True
    );
    self.assertEqual(listed.stdout.splitlines(), ["Acme (Aarhus)"]);
}

impl NotesSheetCLI.test_notes_only_workbook_fails_without_writing_output -> any {
    result: any = self.convert(with_data=False);
    self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
    self.assertIn("No data could be parsed", result.stderr);
    self.assertFalse(self.output.exists());
}
