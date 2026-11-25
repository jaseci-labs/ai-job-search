impl ParsePageCountTests.test_parses_pdfinfo_page_count -> any {
    self.assertEqual(parse_page_count("Title: Example\nPages:          2\n"), 2);
}

impl ParsePageCountTests.test_rejects_output_without_page_count -> any {
    with self.assertRaisesRegex(VerificationError, "did not contain a page count") {
        parse_page_count("Title: Example\n");
    }
}

impl NormalizeTextTests.test_folds_curly_apostrophe_to_ascii -> any {
    self.assertEqual(normalize_text("Master’s degree"), "Master's degree");
    self.assertEqual(normalize_text("‘quoted’"), "'quoted'");
}

impl NormalizeTextTests.test_folds_curly_double_quotes_to_ascii -> any {
    self.assertEqual(normalize_text("“Six Sigma”"), "\"Six Sigma\"");
}

impl NormalizeTextTests.test_folds_en_and_em_dashes_to_hyphen -> any {
    self.assertEqual(normalize_text("2016–2024"), "2016-2024");
    self.assertEqual(normalize_text("role—title"), "role-title");
}

impl NormalizeTextTests.test_folds_no_break_space_to_space -> any {
    self.assertEqual(normalize_text("EUR 600k"), "EUR 600k");
}

impl NormalizeTextTests.test_folds_decomposed_accents_to_nfc -> any {
    decomposed: any = "Genève Université";
    precomposed: any = "Genève Université";
    self.assertEqual(normalize_text(decomposed), precomposed);
}

impl NormalizeTextTests.test_still_collapses_whitespace -> any {
    self.assertEqual(normalize_text("Professional\n   Experience "), "Professional Experience");
}

impl NormalizeTextTests.test_fold_is_symmetric -> any {
    self.assertEqual(normalize_text("Master’s"), normalize_text("Master's"));
}

impl FindNonAsciiDateRangesTests.test_en_dash_between_years_is_reported_with_its_code_point -> any {
    hits: any = find_non_ascii_date_ranges("Six Sigma Green Belt, 2016–2024.\n");
    self.assertEqual(hits, [("Six Sigma Green Belt, 2016–2024.", "–")]);
}

impl FindNonAsciiDateRangesTests.test_ascii_hyphen_range_is_clean -> any {
    self.assertEqual(find_non_ascii_date_ranges("2016-2024\nMar 2016 - Jul 2016\n"), []);
}

impl FindNonAsciiDateRangesTests.test_a_year_on_either_side_of_the_dash_is_enough -> any {
    for text in ("Mar 2016 – Jul 2016", "2016 – Present", "– 2024") {
        with self.subTest(text=text) {
            self.assertEqual(len(find_non_ascii_date_ranges(text)), 1);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_other_unicode_dashes_and_the_minus_sign_are_caught -> any {
    for dash in ("‐", "‑", "‒", "—", "―", "−") {
        with self.subTest(dash=dash) {
            self.assertEqual(find_non_ascii_date_ranges(f"2016{dash}2024")[0][1], dash);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_numeric_range_without_a_year_is_not_a_date -> any {
    self.assertEqual(find_non_ascii_date_ranges("EUR 600k–1M, 12–15 people"), []);
}

impl FindNonAsciiDateRangesTests.test_year_like_digits_inside_a_longer_number_are_not_a_year -> any {
    for text in ("Grew budget DKK 120000–200000", "Scaled ingestion from 12000–15000 events/s") {
        with self.subTest(text=text) {
            self.assertEqual(find_non_ascii_date_ranges(text), []);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_numeric_range_with_year_shaped_ends_is_a_quantity_not_a_date -> any {
    for text in (
        "Salary EUR 1500–2000 per month",
        "Scaled the API to serve 2000–5000 requests per second",
        "Grew users from 2000–5000",
        "Budget 1.5–2.0M, headcount 20–25",
    ) {
        with self.subTest(text=text) {
            self.assertEqual(find_non_ascii_date_ranges(text), []);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_attached_currency_symbols_make_numeric_ranges_quantities -> any {
    for symbol in ("€", "£", "$", "¥") {
        for text in (
            f"Budget {symbol}2000–{symbol}5000 per month",
            f"Budget 1500{symbol}–2000{symbol} per month",
            f"Budget {symbol}2000–{symbol}2024 per month",
        ) {
            with self.subTest(text=text) {
                self.assertEqual(find_non_ascii_date_ranges(text), []);
            }
        }
    }
}

impl FindNonAsciiDateRangesTests.test_numerically_formatted_date_ranges_are_still_caught -> any {
    for text in (
        "03/2016–07/2024",
        "01.2016 – 12.2024",
        "2016-03–2024-07",
        "2016/17–2018/19",
        "2016/03–2024/07",
        "01.03.2016–31.07.2024",
        "2016–07/2024",
    ) {
        with self.subTest(text=text) {
            self.assertEqual(len(find_non_ascii_date_ranges(text)), 1);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_year_and_two_digit_year_is_a_date_range -> any {
    for text in ("MSc Physics, 2016–17", "Sep 2016–17", "2019–20 season", "2016 – 17") {
        with self.subTest(text=text) {
            self.assertEqual(len(find_non_ascii_date_ranges(text)), 1);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_two_digit_number_before_a_year_is_still_a_quantity -> any {
    self.assertEqual(find_non_ascii_date_ranges("items 17–2016"), []);
}

impl FindNonAsciiDateRangesTests.test_two_years_joined_by_a_dash_are_still_a_date_range -> any {
    for text in ("2016–2024", "1990–2010 programme", "Roles 2000–2024") {
        with self.subTest(text=text) {
            self.assertEqual(len(find_non_ascii_date_ranges(text)), 1);
        }
    }
}

impl FindNonAsciiDateRangesTests.test_a_standalone_year_next_to_a_longer_number_is_still_caught -> any {
    self.assertEqual(find_non_ascii_date_ranges("2016–2024 (120000 users)")[0][1], "–");
}

impl FindNonAsciiDateRangesTests.test_year_ending_a_line_is_not_joined_to_the_next_lines_dash -> any {
    text: any = "Heading 1988-1994\n– note\n";
    self.assertEqual(find_non_ascii_date_ranges(text), []);
}

impl FindNonAsciiDateRangesTests.test_dash_ending_a_line_is_not_joined_to_the_next_lines_year -> any {
    text: any = "Six Sigma –\n2016 onwards\n";
    self.assertEqual(find_non_ascii_date_ranges(text), []);
}

impl FindNonAsciiDateRangesTests.test_same_line_spaces_around_the_dash_are_still_caught -> any {
    self.assertEqual(len(find_non_ascii_date_ranges("1988 – 1994")), 1);
}

impl FindNonAsciiDateRangesTests.test_hits_are_reported_in_document_order_one_per_range -> any {
    text: any = "2016–2024 role\nmore text\nJan 2010 – Dec 2012 degree\n";
    self.assertEqual(
        [line for (line, _) in find_non_ascii_date_ranges(text)],
        ["2016–2024 role", "Jan 2010 – Dec 2012 degree"],
    );
}

impl VerifyPdfTests.setUp -> any {
    self.temp_dir = tempfile.TemporaryDirectory();
    self.pdf = Path(self.temp_dir.name) / "example.pdf";
    self.pdf.touch();
}

impl VerifyPdfTests.tearDown -> any {
    self.temp_dir.cleanup();
}

impl VerifyPdfTests.test_accepts_expected_pages_and_text(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = [
        "Professional\nExperience   [your.email@example.com]\n",
        "Pages:          2\n",
    ];

    verify_pdf(
        self.pdf,
        expected_pages=2,
        min_chars=20,
        required_text=("Professional Experience", "[your.email@example.com]"),
    );
}

impl VerifyPdfTests.test_rejects_wrong_page_count(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = ["ok", "Pages:          3\n"];

    with self.assertRaisesRegex(VerificationError, "expected 2 page.*found 3") {
        verify_pdf(self.pdf, expected_pages=2);
    }
}

impl VerifyPdfTests.test_rejects_too_little_extractable_text(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = ["short", "Pages:          1\n"];

    with self.assertRaisesRegex(VerificationError, "expected at least 20") {
        verify_pdf(self.pdf, min_chars=20);
    }
}

impl VerifyPdfTests.test_rejects_missing_required_text(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = [
        "Readable text, but not the expected section.",
        "Pages:          1\n",
    ];

    with self.assertRaisesRegex(VerificationError, "Professional Experience") {
        verify_pdf(self.pdf, required_text=("Professional Experience",));
    }
}

impl VerifyPdfTests.test_required_text_matches_latex_typographic_substitutions(
    mock_run_tool, _pypdf
) -> any {
    mock_run_tool.side_effect = [
        "Master’s degree in Statistics. Six Sigma Green Belt, 2016–2024.\n",
        "Pages:          1\n",
    ];

    verify_pdf(self.pdf, required_text=("Master's degree", "2016-2024"));
}

impl VerifyPdfTests.test_required_text_matches_decomposed_pdflatex_accents(
    mock_run_tool, _pypdf
) -> any {
    mock_run_tool.side_effect = ["Université de Genève\n", "Pages:          1\n"];

    verify_pdf(self.pdf, required_text=("Université de Genève",));
}

impl VerifyPdfTests.test_dump_text_keeps_the_raw_layer_unfolded(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = ["2016–2024\n", "Pages:          1\n"];
    dump: any = Path(self.temp_dir.name) / "dump.txt";

    verify_pdf(self.pdf, required_text=("2016-2024",), dump_text=dump);

    self.assertEqual(dump.read_text(encoding="utf-8"), "2016–2024\n");
}

impl VerifyPdfTests.test_ascii_dates_rejects_the_en_dash_range_that_contains_accepts(
    mock_run_tool, _pypdf
) -> any {
    layer: any = "Role Title 2016–2024\n";
    mock_run_tool.side_effect = [layer, "Pages:          1\n", layer, "Pages:          1\n"];

    verify_pdf(self.pdf, required_text=("2016-2024",));

    with self.assertRaisesRegex(VerificationError, "U\\+2013.*2016\\u20132024") {
        verify_pdf(self.pdf, required_text=("2016-2024",), ascii_dates=True);
    }
}

impl VerifyPdfTests.test_ascii_dates_accepts_hyphen_ranges(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = [
        "Role Title 2016-2024\nMar 2016 - Jul 2016\n",
        "Pages:          1\n",
    ];

    verify_pdf(self.pdf, ascii_dates=True);
}

impl VerifyPdfTests.test_ascii_dates_still_writes_the_dump_before_failing(
    mock_run_tool, _pypdf
) -> any {
    mock_run_tool.side_effect = ["2016–2024\n", "Pages:          1\n"];
    dump: any = Path(self.temp_dir.name) / "dump.txt";

    with self.assertRaises(VerificationError) {
        verify_pdf(self.pdf, dump_text=dump, ascii_dates=True);
    }

    self.assertEqual(dump.read_text(encoding="utf-8"), "2016–2024\n");
}

impl VerifyPdfTests.test_ascii_dates_flag_is_off_by_default_and_parses -> any {
    self.assertFalse(build_parser().parse_args(["x.pdf"]).ascii_dates);
    self.assertTrue(build_parser().parse_args(["x.pdf", "--ascii-dates"]).ascii_dates);
}

impl VerifyPdfTests.test_rejects_missing_pdf -> any {
    with self.assertRaisesRegex(VerificationError, "PDF does not exist") {
        verify_pdf(Path(self.temp_dir.name) / "missing.pdf");
    }
}

impl VerifyPdfTests.test_pypdf_is_preferred_over_poppler(_pypdf) -> any {
    text: any;
    pages: any;
    extractor: any;
    (text, pages, extractor) = extract_text_layer(self.pdf) as any;
    self.assertEqual(extractor, "pypdf");
    self.assertEqual(text, "Hello ATS body");
    self.assertEqual(pages, 1);
}

impl VerifyPdfTests.test_falls_back_to_pdftotext(mock_run_tool, _pypdf) -> any {
    mock_run_tool.side_effect = ["poppler text", "Pages:          2\n"];
    text: any;
    pages: any;
    extractor: any;
    (text, pages, extractor) = extract_text_layer(self.pdf) as any;
    self.assertEqual(extractor, "pdftotext");
    self.assertEqual(text, "poppler text");
    self.assertEqual(pages, 2);
    self.assertEqual(mock_run_tool.call_args_list[0][0][0][:3], ["pdftotext", "-layout", "-enc"]);
}

impl RunToolTests.test_reports_missing_poppler_command(_mock_run) -> any {
    with self.assertRaisesRegex(VerificationError, "neojac install") {
        run_tool(["pdftotext", "example.pdf", "-"]);
    }
}

impl RunToolTests.test_reports_unreadable_pdf(mock_run) -> any {
    mock_run.side_effect = subprocess.CalledProcessError(
        1, ["pdfinfo", "example.pdf"], stderr="invalid PDF"
    );

    with self.assertRaisesRegex(VerificationError, "invalid PDF") {
        run_tool(["pdfinfo", "example.pdf"]);
    }
}

impl DumpTargetTests.setUp -> any {
    self.temp_dir = tempfile.TemporaryDirectory();
    self.addCleanup(self.temp_dir.cleanup);
    self.root = Path(self.temp_dir.name);
    (self.root / "cv").mkdir();
}

impl DumpTargetTests.test_documented_target_is_allowed -> any {
    self.assertIsNone(check_dump_target(self.root / "cv" / "main_acme_analyst.txt", self.root));
    self.assertIsNone(check_dump_target(ROOT / "cv" / "main_acme_analyst.txt"));
}

impl DumpTargetTests.test_targets_outside_the_output_dirs_are_refused -> any {
    outside: any = Path(self.temp_dir.name).parent / "elsewhere.txt";
    for (path, reason) in [
        (outside, "inside this repo's cv/"),
        (self.root / "tools" / "notes.txt", "inside this repo's cv/"),
        (self.root / "cv" / ".." / "tools" / "x.txt", "inside this repo's cv/"),
        (self.root / "cv" / "main_acme.py", "must name a .txt file"),
        (Path.home() / ".zshrc", "must name a .txt file"),
    ] {
        with self.subTest(path=path) {
            self.assertIn(reason, check_dump_target(path, self.root));
        }
    }
}

impl DumpTargetTests.test_symlink_out_of_cv_is_refused -> any {
    link: any = self.root / "cv" / "main_acme.txt";
    try {
        link.symlink_to(self.root / "outside.txt");
    } except OSError as exc {
        self.skipTest(f"cannot create symlinks here: {exc}");
    }
    self.assertEqual(check_dump_target(link, self.root), "must not be a symlink");
}

impl DumpTargetTests.test_cli_refuses_before_extracting_or_writing(mock_verify) -> any {
    target: any = Path(self.temp_dir.name) / "victim" / "rc.txt";
    with patch("sys.stderr") {
        code: any = main(["cv/main_example.pdf", "--dump-text", `str(target)]);
    }
    self.assertEqual(code, 1);
    mock_verify.assert_not_called();
    self.assertFalse(target.parent.exists(), "the CLI must not create the parent directory");
}
