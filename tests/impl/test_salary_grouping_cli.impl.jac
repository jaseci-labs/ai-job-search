impl GroupingCLI.convert(rows) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any;
        output: any;
        (workbook, output) = (`root / "salary.xlsx", `root / "salary_data.json");
        book: any = openpyxl.Workbook();
        try {
            book.active.append(["Company", "Count", "Salary"]);
            for row in rows {
                book.active.append(row);
            }
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
        return json.loads(output.read_text(encoding="utf-8"))["companies"];
    }
}

impl GroupingCLI.test_unicode_space_grouping_preserves_count_and_salary -> any {
    rows: any = [
        ["Narrow Space Corp", "1 234", "42 000,50"],
        ["Thin Space Corp", "2 234", "52 000.50"],
    ];
    companies: any = self.convert(rows);
    self.assertEqual(
        [`entry["categories"] for `entry in companies],
        [
            {"all_employees": {"count": 1234, "index": 42000.5}},
            {"all_employees": {"count": 2234, "index": 52000.5}},
        ],
    );
}

impl GroupingCLI.test_existing_space_groups_and_ambiguous_separators_are_unchanged -> any {
    rows: any = [
        ["ASCII Corp", "1 234", "42 000,50"],
        ["NBSP Corp", "1 234", "42 000.50"],
        ["Numeric Corp", 1234, 42000.5],
        ["Ambiguous Corp", "1,234", "42.000"],
    ];
    companies: any = self.convert(rows);
    expected: any = {"all_employees": {"count": 1234, "index": 42000.5}};
    self.assertEqual([`entry["categories"] for `entry in companies[:3]], [expected] * 3);
    self.assertEqual(companies[3]["categories"], {});
}
