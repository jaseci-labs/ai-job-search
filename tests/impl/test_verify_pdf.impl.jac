impl poppler(text: str, pages: int = 1) -> any {
    return patch("tools.verify_pdf.run_tool", side_effect=[text, f"Pages:          {pages}\n"]);
}

impl TextHelpers.test_parse_page_count {
    self.assertEqual(parse_page_count("Title: Example\nPages:          2\n"), 2);
    with self.assertRaisesRegex(VerificationError, "did not contain a page count") {
        parse_page_count("Title: Example\n");
    }
}

impl TextHelpers.test_normalize_text_folds {
    cases: list[tuple[str, str]] = [
        ("Master’s degree", "Master's degree"),
        ("‘quoted’", "'quoted'"),
        ("“Six Sigma”", "\"Six Sigma\""),
        ("2016–2024", "2016-2024"),
        ("role—title", "role-title"),
        ("EUR 600k", "EUR 600k"),
        (unicodedata.normalize("NFD", "Genève Université"), "Genève Université"),
        ("Professional\n   Experience ", "Professional Experience"),
        ("Master's", "Master's"),
    ];
    for (raw, folded) in cases {
        with self.subTest(raw=raw) {
            self.assertEqual(normalize_text(raw), folded);
        }
    }
}

impl FindNonAsciiDateRanges.test_every_unicode_dash_is_reported_with_its_line {
    for dash in "‐‑‒–—―−" {
        with self.subTest(dash=dash) {
            self.assertEqual(
                find_non_ascii_date_ranges(f"Six Sigma Green Belt, 2016{dash}2024.\n"),
                [(f"Six Sigma Green Belt, 2016{dash}2024.", dash)],
            );
        }
    }
    self.assertEqual(find_non_ascii_date_ranges("2016–2024 (120000 users)")[0][1], "–");
}

impl FindNonAsciiDateRanges.test_date_ranges_are_caught {
    cases: list[str] = [
        "Mar 2016 – Jul 2016",
        "2016 – Present",
        "– 2024",
        "03/2016–07/2024",
        "01.2016 – 12.2024",
        "2016-03–2024-07",
        "2016/17–2018/19",
        "2016/03–2024/07",
        "01.03.2016–31.07.2024",
        "2016–07/2024",
        "MSc Physics, 2016–17",
        "Sep 2016–17",
        "2019–20 season",
        "2016 – 17",
        "2016–2024",
        "1990–2010 programme",
        "Roles 2000–2024",
        "1988 – 1994",
    ];
    for text in cases {
        with self.subTest(text=text) {
            self.assertEqual(len(find_non_ascii_date_ranges(text)), 1);
        }
    }
}

impl FindNonAsciiDateRanges.test_ascii_ranges_quantities_and_line_breaks_are_clean {
    money: list[str] = [
        text
        for s in "€£$¥"
        for text in (
            f"Budget {s}2000–{s}5000 per month",
            f"Budget 1500{s}–2000{s} per month",
            f"Budget {s}2000–{s}2024 per month",
        )
    ];
    cases: list[str] = [
        "2016-2024\nMar 2016 - Jul 2016\n",
        "EUR 600k–1M, 12–15 people",
        "Grew budget DKK 120000–200000",
        "Scaled ingestion from 12000–15000 events/s",
        "Salary EUR 1500–2000 per month",
        "Scaled the API to serve 2000–5000 requests per second",
        "Grew users from 2000–5000",
        "Budget 1.5–2.0M, headcount 20–25",
        "items 17–2016",
        "Heading 1988-1994\n– note\n",
        "Six Sigma –\n2016 onwards\n",
    ];
    for text in cases + money {
        with self.subTest(text=text) {
            self.assertEqual(find_non_ascii_date_ranges(text), []);
        }
    }
}

impl FindNonAsciiDateRanges.test_hits_are_reported_in_document_order_one_per_range {
    text: str = "2016–2024 role\nmore text\nJan 2010 – Dec 2012 degree\n";
    self.assertEqual(
        [line for (line, _) in find_non_ascii_date_ranges(text)],
        ["2016–2024 role", "Jan 2010 – Dec 2012 degree"],
    );
}

impl VerifyPdf.setUp {
    self.temp_dir = tempfile.TemporaryDirectory();
    self.addCleanup(self.temp_dir.cleanup);
    self.pdf = Path(self.temp_dir.name) / "example.pdf";
    self.pdf.touch();
    self.dump = Path(self.temp_dir.name) / "dump.txt";
    no_pypdf: any = patch("tools.verify_pdf._extract_pypdf", return_value=None);
    no_pypdf.start();
    self.addCleanup(no_pypdf.stop);
}


impl VerifyPdf.test_accepts {
    cases: list[tuple[str, int, dict[str, any]]] = [
        (
            "Professional\nExperience   [your.email@example.com]\n",
            2,
            {
                "expected_pages": 2,
                "min_chars": 20,
                "required_text": ("Professional Experience", "[your.email@example.com]"),
            },
        ),
        (
            "Master’s degree in Statistics. Six Sigma Green Belt, 2016–2024.\n",
            1,
            {"required_text": ("Master's degree", "2016-2024")},
        ),
        (
            unicodedata.normalize("NFD", "Université de Genève\n"),
            1,
            {"required_text": ("Université de Genève",)},
        ),
        ("Role Title 2016–2024\n", 1, {"required_text": ("2016-2024",)}),
        ("Role Title 2016-2024\nMar 2016 - Jul 2016\n", 1, {"ascii_dates": True}),
    ];
    for (layer, pages, checks) in cases {
        with self.subTest(layer=layer), poppler(layer, pages) {
            self.assertEqual(verify_pdf(self.pdf, **checks), ("pdftotext", layer, pages));
        }
    }
}

impl VerifyPdf.test_rejects {
    cases: list[tuple[str, int, dict[str, any], str]] = [
        ("ok", 3, {"expected_pages": 2}, "expected 2 page.*found 3"),
        ("short", 1, {"min_chars": 20}, "expected at least 20"),
        (
            "Readable text, but not the expected section.",
            1,
            {"required_text": ("Professional Experience",)},
            "Professional Experience",
        ),
        (
            "Role Title 2016–2024\n",
            1,
            {"required_text": ("2016-2024",), "ascii_dates": True},
            "U\\+2013.*2016\\u20132024",
        ),
    ];
    for (layer, pages, checks, message) in cases {
        with self.subTest(message=message), poppler(layer, pages) {
            with self.assertRaisesRegex(VerificationError, message) {
                verify_pdf(self.pdf, **checks);
            }
        }
    }
    with self.assertRaisesRegex(VerificationError, "PDF does not exist") {
        verify_pdf(Path(self.temp_dir.name) / "missing.pdf");
    }
}

impl VerifyPdf.test_dump_text_is_the_raw_layer_and_is_written_before_a_failure {
    with poppler("2016–2024\n") {
        verify_pdf(self.pdf, required_text=("2016-2024",), dump_text=self.dump);
    }
    self.assertEqual(self.dump.read_text(encoding="utf-8"), "2016–2024\n");
    self.dump.unlink();
    with poppler("2016–2024\n"), self.assertRaises(VerificationError) {
        verify_pdf(self.pdf, dump_text=self.dump, ascii_dates=True);
    }
    self.assertEqual(self.dump.read_text(encoding="utf-8"), "2016–2024\n");
}

impl VerifyPdf.test_ascii_dates_flag_is_off_by_default_and_parses {
    self.assertFalse(build_parser().parse_args(["x.pdf"]).ascii_dates);
    self.assertTrue(build_parser().parse_args(["x.pdf", "--ascii-dates"]).ascii_dates);
}

impl VerifyPdf.test_pypdf_is_preferred_over_poppler {
    with patch("tools.verify_pdf._extract_pypdf", return_value=("Hello ATS body", 1)) {
        self.assertEqual(extract_text_layer(self.pdf), ("Hello ATS body", 1, "pypdf"));
    }
}

impl VerifyPdf.test_falls_back_to_pdftotext {
    with poppler("poppler text", 2) as run {
        self.assertEqual(extract_text_layer(self.pdf), ("poppler text", 2, "pdftotext"));
    }
    self.assertEqual(run.call_args_list[0][0][0][:3], ["pdftotext", "-layout", "-enc"]);
}

impl VerifyPdf.test_run_tool_reports_failures {
    unreadable: any = subprocess.CalledProcessError(
        1, ["pdfinfo", "example.pdf"], stderr="invalid PDF"
    );
    for (failure, message) in [(FileNotFoundError, "neojac install"), (unreadable, "invalid PDF")] {
        with self.subTest(message=message) {
            with patch("tools.verify_pdf.subprocess.run", side_effect=failure) {
                with self.assertRaisesRegex(VerificationError, message) {
                    run_tool(["pdfinfo", "example.pdf"]);
                }
            }
        }
    }
}

impl DumpTarget.setUp {
    self.temp_dir = tempfile.TemporaryDirectory();
    self.addCleanup(self.temp_dir.cleanup);
    self.base = Path(self.temp_dir.name);
    (self.base / "cv").mkdir();
}

impl DumpTarget.test_documented_target_is_allowed {
    self.assertIsNone(check_dump_target(self.base / "cv" / "main_acme_analyst.txt", self.base));
    self.assertIsNone(check_dump_target(ROOT / "cv" / "main_acme_analyst.txt"));
}

impl DumpTarget.test_targets_outside_the_output_dirs_are_refused {
    cases: list[tuple[Path, str]] = [
        (self.base.parent / "elsewhere.txt", "inside this repo's cv/"),
        (self.base / "tools" / "notes.txt", "inside this repo's cv/"),
        (self.base / "cv" / ".." / "tools" / "x.txt", "inside this repo's cv/"),
        (self.base / "cv" / "main_acme.py", "must name a .txt file"),
        (Path.home() / ".zshrc", "must name a .txt file"),
    ];
    for (path, reason) in cases {
        with self.subTest(path=path) {
            self.assertIn(reason, check_dump_target(path, self.base));
        }
    }
}

impl DumpTarget.test_symlink_out_of_cv_is_refused {
    link: Path = self.base / "cv" / "main_acme.txt";
    try {
        link.symlink_to(self.base / "outside.txt");
    } except OSError as exc {
        self.skipTest(f"cannot create symlinks here: {exc}");
    }
    self.assertEqual(check_dump_target(link, self.base), "must not be a symlink");
}

impl DumpTarget.test_cli_refuses_before_extracting_or_writing {
    target: Path = self.base / "victim" / "rc.txt";
    with patch("tools.verify_pdf.verify_pdf") as verify, patch("sys.stderr") {
        self.assertEqual(main(["cv/main_example.pdf", "--dump-text", str(target)]), 1);
    }
    verify.assert_not_called();
    self.assertFalse(target.parent.exists(), "the CLI must not create the parent directory");
}
