impl SalaryMetadataCLI.run_lookup(metadata, *args_) -> any {
    args: any = tuple(args_);
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        root_at(self, `root);
        (`root / "salary_data.json").write_text(
            json.dumps({
                "metadata": metadata,
                "companies": [{"company": "Acme", "categories": {"all_employees": {"index": 165}}}],
            }),
            encoding="utf-8",
        );
        return subprocess.run(
            [*tool("salary_lookup"), *args], capture_output=True, text=True, encoding="utf-8"
        );
    }
}

impl SalaryMetadataCLI.test_preflight_rejects_a_text_baseline -> any {
    result: any = self.run_lookup({"index_baseline": "150"}, "--validate");
    self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
    self.assertIn("index_baseline", result.stdout + result.stderr);
}

impl SalaryMetadataCLI.test_lookup_rejects_a_text_baseline_without_a_traceback -> any {
    result: any = self.run_lookup({"index_baseline": "150"}, "Acme");
    self.assertEqual(result.returncode, 1);
    self.assertIn("index_baseline", result.stderr);
    self.assertNotIn("Traceback", result.stderr);
}

impl SalaryMetadataCLI.test_preflight_rejects_a_non_text_index_label -> any {
    result: any = self.run_lookup({"index_label": ["Salary"]}, "--validate");
    self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
    self.assertIn("index_label", result.stdout + result.stderr);
}

impl SalaryMetadataCLI.test_preflight_rejects_unusable_numeric_baselines -> any {
    for baseline in [True, None, `float("inf"), `float("nan"), 10 ** 400] {
        with self.subTest(baseline=baseline) {
            result: any = self.run_lookup({"index_baseline": baseline}, "--validate");
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
            self.assertIn("index_baseline", result.stdout + result.stderr);
            self.assertNotIn("Traceback", result.stderr);
        }
    }
}

impl SalaryMetadataCLI.test_numeric_baseline_and_optional_metadata_controls -> any {
    for (metadata, percentage) in [
        ({"index_baseline": 150, "index_label": "Salary"}, "+10.0%"),
        ({"index_baseline": 0}, None),
        ({}, "+65.0%"),
        (None, "+65.0%"),
    ] {
        with self.subTest(metadata=metadata) {
            result: any = self.run_lookup(metadata, "Acme");
            self.assertEqual(result.returncode, 0, result.stderr);
            if percentage {
                self.assertIn(percentage, result.stdout);
            } else {
                self.assertNotIn("%", result.stdout);
            }
        }
    }
}
