import json, subprocess, unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob openpyxl: any = None,
     BarChart: any = None,
     Reference: any = None,
     PLAIN: list[any] = ["Company", "Count", "Index"],
     NOTES: list[list[str]] = [
         ["About this data"],
         ["Each row is one company in the 2025 survey."],
         ["Indexes are relative to the national median."],
         ["Categories with fewer than five respondents are suppressed."],
     ];

with entry {
    try {
        import openpyxl;
        import from openpyxl.chart { BarChart, Reference }
    } except ImportError {}
}

def both(count: any, index: any) -> dict[str, any] {
    return {"count": count, "index": index};
}

def everyone(count: any, index: any) -> dict[str, any] {
    return {"all_employees": both(count, index)};
}

@unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
class SalaryWorkbookCLI(unittest.TestCase) {
    def setUp {
        directory: TemporaryDirectory = TemporaryDirectory();
        self.addCleanup(directory.cleanup);
        self.home = Path(directory.name);
        root_at(self, self.home);
        self.workbook = self.home / "salary input.xlsx";
        self.output = self.home / "salary_data.json";
    }

    def build(sheets: dict[str, list[any]]) -> any {
        book: any = openpyxl.Workbook();
        book.remove(book.active);
        for (title, rows) in sheets.items() {
            sheet: any = book.create_sheet(title);
            for row in rows {
                sheet.append(row);
            }
        }
        return book;
    }

    def convert(book: any, *args: str) -> subprocess.CompletedProcess {
        try {
            book.save(self.workbook);
        } finally {
            book.close();
        }
        return capture(
            [
                *tool("convert_salary_excel"),
                str(self.workbook),
                "--output",
                str(self.output),
                *args,
            ],
            cwd=self.home,
            encoding="utf-8",
        );
    }

    def converted(sheets: any, *args: str) -> dict[str, any] {
        result: subprocess.CompletedProcess = self.convert(
            self.build(sheets if isinstance(sheets, dict) else {"Sheet": sheets}), *args
        );
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
        return json.loads(self.output.read_text(encoding="utf-8"), parse_constant=self.fail);
    }

    def companies(sheets: any) -> list[tuple[str, str, any]] {
        return [
            (c["company"], c["city"], c["categories"])
            for c in self.converted(sheets)["companies"]
        ];
    }

    def lookup(*args: str) -> subprocess.CompletedProcess {
        return capture([*tool("salary_lookup"), *args], cwd=self.home, encoding="utf-8");
    }

    def test_cells_and_headers_convert_to_categories {
        acme: list[any] = ["Acme Corp", "Berlin", 25, 108.5];
        wrapped: list[any] = ["Acme", "Aarhus", 12, 104.5];
        grouped: dict[str, any] = everyone(1234, 42000.5);
        cases: list[any] = [
            (
                [
                    ["Company", "City", "Count", "Index", "Verified"],
                    ["Logical Pair", "Berlin", True, False, True],
                    ["Logical Count", "Berlin", False, 108.5, False],
                    ["Logical Index", "Berlin", 12, True, None],
                    ["Numeric Values", "Berlin", 0, 1, 0],
                    ["Numeric Count", "Berlin", 1, 0, 1],
                ],
                [
                    ("Logical Pair", "Berlin", {}),
                    ("Logical Count", "Berlin", everyone(None, 108.5)),
                    ("Logical Index", "Berlin", everyone(12, None)),
                    ("Numeric Values", "Berlin", {**everyone(0, 1.0), "verified": {"index": 0.0}}),
                    ("Numeric Count", "Berlin", {**everyone(1, 0.0), "verified": {"index": 1.0}}),
                ],
            ),
            *[
                (
                    [[name, "City", f"{prefix} Count", f"{prefix} Index"], acme],
                    [("Acme Corp", "Berlin", {prefix.lower(): both(25, 108.5)})],
                )
                for (name, prefix) in [
                    ("Company", "Company"),
                    ("Company Name", "Engineering"),
                    ("Company", "City"),
                ]
            ],
            (
                [
                    ["Company", "Count", "Salary"],
                    ["Narrow Space Corp", "1 234", "42 000,50"],
                    ["Thin Space Corp", "2 234", "52 000.50"],
                    ["ASCII Corp", "1 234", "42 000,50"],
                    ["NBSP Corp", "1 234", "42 000.50"],
                    ["Numeric Corp", 1234, 42000.5],
                    ["Ambiguous Corp", "1,234", "42.000"],
                ],
                [
                    ("Narrow Space Corp", "", grouped),
                    ("Thin Space Corp", "", everyone(2234, 52000.5)),
                    ("ASCII Corp", "", grouped),
                    ("NBSP Corp", "", grouped),
                    ("Numeric Corp", "", grouped),
                    ("Ambiguous Corp", "", {}),
                ],
            ),
            (
                [
                    PLAIN,
                    ["Invalid Count", "Infinity", 108.5],
                    ["Valid Control", 12, 102.5],
                    ["Acme", 12, "NaN"],
                ],
                [
                    ("Invalid Count", "", everyone(None, 108.5)),
                    ("Valid Control", "", everyone(12, 102.5)),
                    ("Acme", "", everyone(12, None)),
                ],
            ),
            ([["Company", "Count"], ["Acme", "NaN"]], [("Acme", "", {})]),
            *[
                ([header, wrapped], [("Acme", "Aarhus", categories)])
                for (header, categories) in [
                    (["Company", "City", "Employees", "Median salary"], everyone(12, 104.5)),
                    (["Company", "City", "Employees", "Median\nsalary"], everyone(12, 104.5)),
                    (["Firma", "By", "Antal\nmedarbejdere", "Løn-\nindeks"], everyone(12, 104.5)),
                    (
                        ["Company", "City", "Count\nengineers", "Index\nengineers"],
                        {"engineers": both(12, 104.5)},
                    ),
                ]
            ],
        ];
        for (rows, expected) in cases {
            with self.subTest(header=rows[0]) {
                self.assertEqual(self.companies(rows), expected);
            }
        }
    }

    def test_nonfinite_baseline_is_rejected_without_overwriting_output {
        for baseline in ("nan", "inf", "-inf", "1e309") {
            with self.subTest(baseline=baseline) {
                self.output.write_text("existing salary data\n", encoding="utf-8");
                result: subprocess.CompletedProcess = self.convert(
                    self.build({"Sheet": [PLAIN, ["Acme", 12, 108.5]]}), f"--baseline={baseline}"
                );
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr);
                for text in ("--baseline", "finite") {
                    self.assertIn(text, result.stderr);
                }
                self.assertNotIn("Traceback", result.stderr);
                self.assertEqual(self.output.read_text(encoding="utf-8"), "existing salary data\n");
            }
        }
    }

    def test_finite_custom_and_zero_baselines_are_preserved {
        for baseline in ("150", "0") {
            with self.subTest(baseline=baseline) {
                data: dict[str, any] = self.converted(
                    [PLAIN, ["Acme", 12, 108.5]], f"--baseline={baseline}"
                );
                self.assertEqual(data["metadata"]["index_baseline"], float(baseline));
            }
        }
    }

    def test_data_worksheets_are_kept_with_or_without_a_chart_tab {
        for with_chart in (True, False) {
            with self.subTest(with_chart=with_chart) {
                book: any = self.build({
                    "Salaries": [PLAIN, ["Acme Corp", 12, 105]],
                    "Engineering": [
                        ["Company", "Engineering Count", "Engineering Index"],
                        ["Other Corp", 20, 108],
                    ],
                });
                if with_chart {
                    first: any = book["Salaries"];
                    chart: any = BarChart();
                    chart.add_data(
                        Reference(first, min_col=2, max_col=3, min_row=1, max_row=2),
                        titles_from_data=True,
                    );
                    chart.set_categories(Reference(first, min_col=1, min_row=2, max_row=2));
                    book.create_chartsheet("Overview", 0).add_chart(chart);
                }
                result: subprocess.CompletedProcess = self.convert(book);
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
                self.assertEqual(
                    json.loads(self.output.read_text(encoding="utf-8"))["companies"],
                    [
                        {"company": "Acme Corp", "city": "", "categories": everyone(12, 105.0)},
                        {
                            "company": "Other Corp",
                            "city": "",
                            "categories": {"engineering": both(20, 108.0)},
                        },
                    ],
                );
            }
        }
    }

    def test_converted_city_is_findable_with_the_city_filter {
        cases: list[tuple[list[any], list[any], tuple[str, str, any], str]] = [
            (
                ["Firmanavn og by", "Antal", "Indeks"],
                ["Ørsted A/S,Fredericia", 200, 105.2],
                ("Ørsted A/S", "Fredericia", everyone(200, 105.2)),
                "Ørsted",
            ),
            (
                ["Company", "City", "Count", "Index"],
                ["Novo Nordisk A/S", "Bagsværd", 500, 108.5],
                ("Novo Nordisk A/S", "Bagsværd", everyone(500, 108.5)),
                "Novo Nordisk",
            ),
        ];
        for (header, row, expected, query) in cases {
            with self.subTest(header=header) {
                self.assertEqual(self.companies([header, row]), [expected]);
                found: subprocess.CompletedProcess = self.lookup(query, "--city", expected[1]);
                self.assertEqual(found.returncode, 0, found.stdout + found.stderr);
                for text in expected[:2] {
                    self.assertIn(text, found.stdout);
                }
                self.assertNotIn("No results found", found.stdout);
            }
        }
    }

    def test_count_only_workbook_does_not_claim_privacy_suppression {
        cases: list[tuple[list[any], list[any], list[str], list[str]]] = [
            (["Company", "Count"], ["Acme Corp", 500], ["Count\\s+500\\s+-"], ["N/A", "privacy"]),
            (PLAIN, ["Acme Corp", 500, 108.5], ["108\\.5", "\\+8\\.5%"], ["privacy"]),
        ];
        for (header, row, wanted, unwanted) in cases {
            with self.subTest(header=header) {
                self.converted([header, row]);
                shown: subprocess.CompletedProcess = self.lookup("Acme Corp");
                self.assertEqual(shown.returncode, 0, shown.stderr);
                for pattern in wanted {
                    self.assertRegex(shown.stdout, pattern);
                }
                for text in unwanted {
                    self.assertNotIn(text, shown.stdout);
                }
            }
        }
    }

    def test_blank_company_rows_are_skipped_and_the_result_validates {
        for blank in ("   ", None) {
            with self.subTest(blank=blank) {
                self.assertEqual(
                    self.companies([PLAIN, ["Acme Corp", 12, 105], [blank, 20, 110]]),
                    [("Acme Corp", "", everyone(12, 105.0))],
                );
                validation: subprocess.CompletedProcess = self.lookup("--validate");
                self.assertEqual(validation.returncode, 0, validation.stdout + validation.stderr);
            }
        }
    }

    def test_notes_tab_sentences_are_not_listed_as_companies {
        result: subprocess.CompletedProcess = self.convert(
            self.build({
                "Data": [["Company", "City", "Count", "Index"], ["Acme", "Aarhus", 10, 105]],
                "Notes": NOTES,
            }),
        );
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
        self.assertIn("Skipping sheet 'Notes'", result.stderr);
        companies: list[any] = json.loads(self.output.read_text(encoding="utf-8"))["companies"];
        self.assertEqual([c["company"] for c in companies], ["Acme"]);
        self.assertEqual(self.lookup("--list-all").stdout.splitlines(), ["Acme (Aarhus)"]);
    }

    def test_workbook_without_a_salary_table_fails_without_writing_output {
        for rows in (NOTES, [["Notes", "Comments"], ["No salary data", "Just a worksheet"]]) {
            with self.subTest(rows=rows) {
                result: subprocess.CompletedProcess = self.convert(self.build({"Notes": rows}));
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
                self.assertIn("No data could be parsed", result.stderr);
                self.assertFalse(self.output.exists());
            }
        }
    }

    def test_real_workbook_round_trips_multiple_sheets_and_metadata {
        data: dict[str, any] = self.converted(
            {
                "All employees": [
                    ["Company", "City", "Count", "Index"],
                    ["Acme Corp", "Copenhagen", 500, 108.5],
                    ["Café Étoile", "Paris", 12, "102,5"],
                ],
                "Engineering": [
                    ["Company", "City", "Engineering Count", "Engineering Index"],
                    ["Other Corp", "Berlin", 8, 112.5],
                ],
            },
            "--source",
            "Integration fixture",
            "--baseline",
            "100",
            "--baseline-desc",
            "Index 100 = median salary",
        );
        self.assertEqual(
            data,
            {
                "metadata": {
                    "source": "Integration fixture",
                    "index_baseline": 100,
                    "index_label": "Index",
                    "baseline_description": "Index 100 = median salary",
                },
                "companies": [
                    {
                        "company": "Acme Corp",
                        "city": "Copenhagen",
                        "categories": everyone(500, 108.5),
                    },
                    {"company": "Café Étoile", "city": "Paris", "categories": everyone(12, 102.5)},
                    {
                        "company": "Other Corp",
                        "city": "Berlin",
                        "categories": {"engineering": both(8, 112.5)},
                    },
                ],
            },
        );
        self.assertEqual(collect_validation_issues(data), ([], []));
        rendered: str = format_entry(data["companies"][0], data["metadata"]);
        for text in ("All Employees", "+8.5%") {
            self.assertIn(text, rendered);
        }
        self.assertNotIn("N/A*", rendered);
    }
}
