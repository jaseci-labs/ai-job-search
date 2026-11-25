impl WrappedHeaderCLI.convert(header) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any;
        output: any;
        (workbook, output) = (`root / "salary.xlsx", `root / "salary_data.json");
        book: any = openpyxl.Workbook();
        try {
            book.active.append(header);
            book.active.append(["Acme", "Aarhus", 12, 104.5]);
            book.save(workbook);
        } finally {
            book.close();
        }
        result: any = subprocess.run(
            [*TOOL, `str(workbook), "--output", `str(output)],
            cwd=`root,
            capture_output=True,
            text=True,
        );
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
        return json.loads(output.read_text(encoding="utf-8"))["companies"][0]["categories"];
    }
}

impl WrappedHeaderCLI.test_wrapped_headers_pair_like_their_single_line_spelling -> any {
    expected: any = {"all_employees": {"count": 12, "index": 104.5}};
    self.assertEqual(self.convert(["Company", "City", "Employees", "Median salary"]), expected);
    self.assertEqual(self.convert(["Company", "City", "Employees", "Median\nsalary"]), expected);
    self.assertEqual(
        self.convert(["Firma", "By", "Antal\nmedarbejdere", "Løn-\nindeks"]), expected
    );
}

impl WrappedHeaderCLI.test_wrapped_category_name_has_no_line_break -> any {
    categories: any = self.convert(["Company", "City", "Count\nengineers", "Index\nengineers"]);
    self.assertEqual(categories, {"engineers": {"count": 12, "index": 104.5}});
}
