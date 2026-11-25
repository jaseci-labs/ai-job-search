impl NonFiniteWorkbookCLI.convert(headers, rows) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any;
        output: any;
        (workbook, output) = (`root / "salary.xlsx", `root / "salary.json");
        book: any = openpyxl.Workbook();
        try {
            book.active.append(headers);
            for row in rows {
                book.active.append(row);
            }
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
        def reject_constant(value) -> any {
            self.fail(f"converter emitted non-JSON numeric constant {value}");
        }
        return json.loads(
            output.read_text(encoding="utf-8"), parse_constant=reject_constant
        )["companies"];
    }
}

impl NonFiniteWorkbookCLI.test_infinite_paired_count_does_not_abort_the_workbook -> any {
    companies: any = self.convert(
        ["Company", "Count", "Index"],
        [["Invalid Count", "Infinity", 108.5], ["Valid Control", 12, 102.5]],
    );
    self.assertEqual(
        companies[0]["categories"], {"all_employees": {"count": None, "index": 108.5}}
    );
    self.assertEqual(companies[1]["categories"], {"all_employees": {"count": 12, "index": 102.5}});
}

impl NonFiniteWorkbookCLI.test_nonfinite_paired_index_is_skipped_instead_of_emitted_as_nan -> any {
    companies: any = self.convert(["Company", "Count", "Index"], [["Acme", 12, "NaN"]]);
    self.assertEqual(companies[0]["categories"], {"all_employees": {"count": 12, "index": None}});
}

impl NonFiniteWorkbookCLI.test_nonfinite_standalone_count_is_skipped -> any {
    companies: any = self.convert(["Company", "Count"], [["Acme", "NaN"]]);
    self.assertEqual(companies[0]["categories"], {});
}
