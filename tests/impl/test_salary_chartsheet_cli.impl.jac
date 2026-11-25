impl ChartsheetCLI.convert(with_chart) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        workbook: any = `root / "salary report.xlsx";
        output: any = `root / "salary output.json";
        book: any = openpyxl.Workbook();
        try {
            first: any = book.active;
            first.title = "Salaries";
            first.append(["Company", "Count", "Index"]);
            first.append(["Acme Corp", 12, 105]);
            second: any = book.create_sheet("Engineering");
            second.append(["Company", "Engineering Count", "Engineering Index"]);
            second.append(["Other Corp", 20, 108]);
            if with_chart {
                chart: any = BarChart();
                chart.add_data(
                    Reference(first, min_col=2, max_col=3, min_row=1, max_row=2),
                    titles_from_data=True,
                );
                chart.set_categories(Reference(first, min_col=1, min_row=2, max_row=2));
                overview: any = book.create_chartsheet("Overview", 0);
                overview.add_chart(chart);
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
        data: any = json.loads(output.read_text(encoding="utf-8"));
        self.assertEqual(
            data["companies"],
            [
                {
                    "company": "Acme Corp",
                    "city": "",
                    "categories": {"all_employees": {"count": 12, "index": 105.0}},
                },
                {
                    "company": "Other Corp",
                    "city": "",
                    "categories": {"engineering": {"count": 20, "index": 108.0}},
                },
            ],
        );
    }
}

impl ChartsheetCLI.test_chart_only_tab_does_not_abort_salary_conversion -> any {
    self.convert(with_chart=True);
}

impl ChartsheetCLI.test_all_data_worksheets_are_preserved_without_chart_tabs -> any {
    self.convert(with_chart=False);
}
