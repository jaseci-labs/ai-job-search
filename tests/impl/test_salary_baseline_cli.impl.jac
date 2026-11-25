impl BaselineCLI.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.root = Path(directory.name);
    self.workbook = self.root / "salary.xlsx";
    self.output = self.root / "salary.json";
    book: any = openpyxl.Workbook();
    try {
        book.active.append(["Company", "Count", "Index"]);
        book.active.append(["Acme", 12, 108.5]);
        book.save(self.workbook);
    } finally {
        book.close();
    }
}

impl BaselineCLI.convert(baseline) -> any {
    return subprocess.run(
        [*TOOL, `str(self.workbook), "--output", `str(self.output), f"--baseline={baseline}"],
        capture_output=True,
        text=True,
        encoding="utf-8",
    );
}

impl BaselineCLI.test_nonfinite_baseline_is_rejected_without_overwriting_output -> any {
    for baseline in ("nan", "inf", "-inf", "1e309") {
        with self.subTest(baseline=baseline) {
            self.output.write_text("existing salary data\n", encoding="utf-8");
            result: any = self.convert(baseline);
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr);
            self.assertIn("--baseline", result.stderr);
            self.assertIn("finite", result.stderr);
            self.assertNotIn("Traceback", result.stderr);
            self.assertEqual(self.output.read_text(encoding="utf-8"), "existing salary data\n");
        }
    }
}

impl BaselineCLI.test_finite_custom_and_zero_baselines_are_preserved -> any {
    for baseline in ("150", "0") {
        with self.subTest(baseline=baseline) {
            result: any = self.convert(baseline);
            self.assertEqual(result.returncode, 0, result.stderr);
            data: any = json.loads(self.output.read_text(encoding="utf-8"));
            self.assertEqual(data["metadata"]["index_baseline"], `float(baseline));
        }
    }
}
