impl line(
    top: builtins.float,
    left: builtins.float = 50.0,
    height: builtins.float = 10.0,
    text: builtins.str = "x",
) -> Line {
    return Line(top=top, bottom=top + height, left=left, height=height, text=text);
}

impl TestGapAndBottomSpace.setUp -> any {
    self.holed = Page(A4_HEIGHT, [line(50), line(64), line(78), line(400), line(770, text="1/2")]);
}

impl TestGapAndBottomSpace.test_largest_gap_reports_size_and_position -> any {
    gap: any;
    y: any;
    (gap, y) = self.holed.largest_gap() as any;
    self.assertEqual((round(gap), round(y)), (322, 78));
}

impl TestGapAndBottomSpace.test_bottom_space_ignores_the_footer_band -> any {
    self.assertEqual(round(self.holed.bottom_space), 432);
}

impl TestGapAndBottomSpace.test_page_with_no_body_lines_is_empty -> any {
    self.assertTrue(Page(A4_HEIGHT, []).empty);
}

impl TestGapAndBottomSpace.test_report_flags_the_hole -> any {
    with redirect_stdout(io.StringIO()) {
        problems: any = `report(Path("synthetic"), [self.holed]);
    }
    self.assertTrue(`any("hole" in m for m in problems), problems);
}

impl TestFooterBand.test_single_line_in_band_is_just_the_page_number -> any {
    self.assertFalse(Page(A4_HEIGHT, [line(50), line(800, text="2/2")]).footer_crowded);
}

impl TestFooterBand.test_two_lines_in_band_means_body_text_spilled_in -> any {
    self.assertTrue(Page(A4_HEIGHT, [line(50), line(780), line(800)]).footer_crowded);
}

impl TestHeadingAndIndentDetection.setUp -> any {
    self.page = Page(
        A4_HEIGHT,
        [
            line(50, height=16.0, text="Professional Experience"),
            line(80, left=50.0),
            line(94, left=70.0),
        ],
    );
}

impl TestHeadingAndIndentDetection.test_taller_line_is_a_heading -> any {
    self.assertTrue(self.page.is_heading(self.page.body[0]));
    self.assertFalse(self.page.is_heading(self.page.body[1]));
}

impl TestHeadingAndIndentDetection.test_left_edge_separates_bullets_from_headers -> any {
    self.assertTrue(self.page.is_indented(self.page.body[2]));
    self.assertFalse(self.page.is_indented(self.page.body[1]));
}

impl TestOrphans.test_page_ending_on_a_section_heading -> any {
    p1: any = Page(A4_HEIGHT, [line(50), line(64), line(700, height=16.0, text="Education")]);
    p2: any = Page(A4_HEIGHT, [line(60, text="Example University"), line(74, left=70.0)]);
    self.assertTrue(`any("ends on the section heading" in m for m in find_orphans([p1, p2])));
}

impl TestOrphans.test_entry_header_orphaned_from_its_bullets -> any {
    q1: any = Page(A4_HEIGHT, [line(50), line(700, left=50.0, text="Software Engineer")]);
    q2: any = Page(A4_HEIGHT, [line(60, left=70.0, text="- built the thing")]);
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([q1, q2])));
}

impl TestOrphans.test_lone_list_marker_is_a_split_bullet_not_an_orphaned_header -> any {
    m1: any = Page(A4_HEIGHT, [line(50), line(700, left=50.0, text="●")]);
    m2: any = Page(A4_HEIGHT, [line(60, left=70.0, text="continued item text here")]);
    self.assertTrue(`any("lone list marker" in m for m in find_orphans([m1, m2])));
}

impl TestOrphans.test_clean_break_reports_nothing -> any {
    r1: any = Page(A4_HEIGHT, [line(50), line(700, left=50.0)]);
    r2: any = Page(A4_HEIGHT, [line(60, left=50.0)]);
    self.assertEqual(find_orphans([r1, r2]), []);
}

impl TestOrphans.test_indent_is_judged_against_the_document_margin -> any {
    s1: any = Page(A4_HEIGHT, [line(50, left=50.0), line(700, left=50.0, text="Data Analyst")]);
    s2: any = Page(A4_HEIGHT, [line(60, left=70.0, text="- first bullet")]);
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([s1, s2])));
}

impl at(top, left, text, text_left=None, bottom=None) -> any {
    bottom = top + 14.0 if bottom is None else bottom;
    return Line(
        top=top, bottom=bottom, left=left, height=bottom - top, text=text, text_left=text_left
    );
}

impl TestOrphansReadTextX.test_bullet_wrapping_across_the_break_is_not_an_orphaned_header -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(50, 59.5, "Plant Grower Example Garden 1981-1990"),
            at(700, 58.9, "• Replanted the long border with plants raised", 72.1),
        ],
    );
    p2: any = Page(A4_HEIGHT, [at(60, 72.1, "from seed, lifting the old clumps")]);
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_bullet_whose_text_opens_with_a_symbol_is_still_a_wrapped_bullet -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(50, 59.5, "Plant Grower Example Garden 1981-1990"),
            at(700, 58.9, "• (in winter) relaid the gravel paths along", 72.1),
        ],
    );
    p2: any = Page(A4_HEIGHT, [at(60, 72.1, "the old orchard wall and round the pond")]);
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_continuation_opening_with_a_dash_is_still_a_wrapped_bullet -> any {
    p1: any = Page(A4_HEIGHT, [at(700, 58.9, "• Laid a new cobbled path, so", 72.1)]);
    p2: any = Page(A4_HEIGHT, [at(60, 72.1, "— that rain ran off into the borders")]);
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_header_level_with_merged_bullets_is_an_orphan -> any {
    p1: any = Page(A4_HEIGHT, [at(700, 59.5, "Kitchen Gardener 1975-1980")]);
    p2: any = Page(A4_HEIGHT, [at(60, 58.9, "• Worked in the kitchen garden", 71.6)]);
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([p1, p2])));
}

impl TestOrphansReadTextX.test_stock_header_whose_outer_marker_is_its_own_line -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(323, 59.5, "Professional Experience"),
            at(695.9, 59.0, "○", bottom=707.6),
            at(700.5, 70.4, "[Job Title] [YYYY-YYYY]"),
        ],
    );
    p2: any = Page(
        A4_HEIGHT,
        [at(62.4, 71.5, "-", bottom=79.5), at(64.4, 81.3, "[Achievement or responsibility 1]")],
    );
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([p1, p2])));
}

impl TestOrphansReadTextX.test_stock_header_with_its_outer_marker_merged_in -> any {
    p1: any = Page(A4_HEIGHT, [at(700, 59.0, "○ [Job Title] [YYYY-YYYY]")]);
    p2: any = Page(
        A4_HEIGHT, [at(62.4, 71.5, "-", bottom=79.5), at(64.4, 81.3, "[Achievement 1]")]
    );
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([p1, p2])));
}

impl TestOrphansReadTextX.test_stock_degree_and_description_stay_reported_with_the_marker_merged -> any {
    p1: any = Page(A4_HEIGHT, [at(700, 59.0, "○ [Degree] in [Field] [YYYY-YYYY]")]);
    p2: any = Page(A4_HEIGHT, [at(60, 70.4, "[Brief description or key topics.]")]);
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([p1, p2])));
}

impl TestOrphansReadTextX.test_outer_marker_set_below_a_whole_item_is_not_a_split_bullet -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(50, 59.5, "Core Competencies", bottom=70.5),
            at(728.81, 70.4, "[Skill Category 4]: [Domain expertise, methods.]", bottom=743.4),
            at(730.09, 59.0, "🟤", bottom=741.8),
        ],
    );
    p2: any = Page(
        A4_HEIGHT,
        [
            at(66.8, 70.4, "[Skill Category 5]: [Tools, platforms, software.]", bottom=81.4),
            at(68.1, 59.0, "🟤", bottom=79.8),
        ],
    );
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_two_line_item_wrapping_across_the_break_is_read_like_a_wrapped_bullet -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(696.4, 59.5, "Honors and Awards", bottom=716.9),
            at(722.13, 70.4, "[Award Name] for the long-running community orchard", bottom=736.7),
            at(723.41, 59.0, "🟤", bottom=735.09),
        ],
    );
    p2: any = Page(A4_HEIGHT, [at(66.8, 69.4, "– [Event/Organization] ([Year]).")]);
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_a_printed_line_split_by_font_is_read_as_one -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(721.44, 125.6, "operations for the data team and later modules.]"),
            at(721.64, 70.4, "Kubernetes Terraform"),
        ],
    );
    p2: any = Page(A4_HEIGHT, [at(66.8, 70.4, "[Skill Category 3]: [Specific skills]")]);
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_stock_bullet_wrapping_across_the_break -> any {
    p1: any = Page(A4_HEIGHT, [at(700, 81.3, "[Achievement or responsibility 1 - be")]);
    p2: any = Page(A4_HEIGHT, [at(60, 81.3, "specific, use numbers where possible]")]);
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_a_running_header_on_the_next_page_is_not_where_the_body_resumes -> any {
    p1: any = Page(
        A4_HEIGHT,
        [
            at(50, 59.5, "Professional Experience"),
            at(700, 81.3, "[Achievement or responsibility 2]"),
        ],
    );
    p2: any = Page(
        A4_HEIGHT, [at(27, 459.8, "[First] [Last] – CV"), at(62, 70.4, "[Company] [City, Country]")]
    );
    self.assertEqual(find_orphans([p1, p2]), []);
}

impl TestOrphansReadTextX.test_an_orphan_behind_a_running_header_is_still_found -> any {
    p1: any = Page(
        A4_HEIGHT, [at(50, 59.5, "Professional Experience"), at(700, 70.4, "[Job Title]")]
    );
    p2: any = Page(
        A4_HEIGHT,
        [
            at(27, 459.8, "[First] [Last] – CV"),
            at(62.4, 71.5, "-", bottom=79.5),
            at(64.4, 81.3, "[Achievement or responsibility 1]"),
        ],
    );
    self.assertTrue(`any("orphaned from its bullets" in m for m in find_orphans([p1, p2])));
}

impl TestTextStart.test_a_leading_list_marker_is_set_aside -> any {
    self.assertEqual(text_start([(58.9, 0, 1, "•"), (72.1, 0, 1, "Laid")]), 72.1);
}

impl TestTextStart.test_no_marker_means_no_separate_text_start -> any {
    self.assertIsNone(text_start([(59.5, 0, 1, "Kitchen"), (94.9, 0, 1, "Gardener")]));
}

impl TestTextStart.test_ascii_dashes_and_other_glyphs_are_text -> any {
    for glyph in ("-", "*", "–", "—", "○") {
        with self.subTest(glyph=glyph) {
            self.assertIsNone(text_start([(69.4, 0, 1, glyph), (77.7, 0, 1, "[Event]")]));
        }
    }
}

impl TestTextStart.test_a_bare_marker_has_no_text -> any {
    self.assertIsNone(text_start([(59.0, 0, 1, "•")]));
}

impl TestExtractorFailure.setUp -> any {
    super.setUp();
    getattr(verify_layout.find_pdftotext as any, "cache_clear")();
}

impl TestExtractorFailure.tearDown -> any {
    super.tearDown();
    getattr(verify_layout.find_pdftotext as any, "cache_clear")();
}

impl TestExtractorFailure.test_pdftotext_without_bbox_raises_a_skippable_error -> any {
    failure: any = subprocess.CalledProcessError(99, "pdftotext", stderr="Error: unknown flag");
    with patch("tools.verify_layout.shutil.which", return_value="/usr/bin/pdftotext"), patch(
        "tools.verify_layout.subprocess.run", side_effect=failure
    ) {
        with self.assertRaisesRegex(RuntimeError, "bounding boxes") {
            parse_pdf(Path("cv/main_example.pdf"));
        }
    }
}

impl TestExtractorFailure.test_first_candidate_lacks_bbox_and_second_has_it -> any {
    def fake_which(cmd, path=None) -> any {
        if path == "/git/bin" {
            return "/git/bin/pdftotext";
        }
        if path == "/miktex/bin" {
            return "/miktex/bin/pdftotext";
        }
        return None;
    }

    def fake_run(cmd, *args_, **kwargs) -> any {
        args: any = tuple(args_);
        binary: any = cmd[0];
        if "-h" in cmd {
            if binary == "/git/bin/pdftotext" {
                return subprocess.CompletedProcess(
                    cmd, 99, stdout="", stderr="Usage: pdftotext ..."
                );
            }
            if binary == "/miktex/bin/pdftotext" {
                return subprocess.CompletedProcess(
                    cmd, 99, stdout="", stderr="Usage: pdftotext ...\n  -bbox : output bounding box"
                );
            }
        }
        if "-bbox" in cmd {
            return subprocess.CompletedProcess(
                cmd, 0, stdout="<page width=\"100\" height=\"100\"></page>", stderr=""
            );
        }
        raise AssertionError(f"unexpected command: {cmd}");
    }

    mock_run: any;
    with patch(
        "tools.verify_layout.os.get_exec_path", return_value=["/git/bin", "/miktex/bin"]
    ), patch("tools.verify_layout.shutil.which", side_effect=fake_which), patch(
        "tools.verify_layout.subprocess.run", side_effect=fake_run
    ) as mock_run {
        pages: any = parse_pdf(Path("cv/main_example.pdf"));
        self.assertEqual(len(pages), 1);
        bbox_calls: any = [call for call in mock_run.call_args_list if "-bbox" in call[0][0]];
        self.assertEqual(len(bbox_calls), 1);
        self.assertEqual(bbox_calls[0][0][0][0], "/miktex/bin/pdftotext");
    }
}

impl TestExtractorFailure.test_no_candidate_has_bbox_keeps_skip_path -> any {
    failure: any;
    def fake_which(cmd, path=None) -> any {
        if path == "/git/bin" {
            return "/git/bin/pdftotext";
        }
        if path == "/other/bin" {
            return "/other/bin/pdftotext";
        }
        return None;
    }

    failure = subprocess.CalledProcessError(99, "/git/bin/pdftotext", stderr="Error: unknown flag");

    def fake_run(cmd, *args__, **kwargs) -> any {
        args: any = tuple(args__);
        if "-h" in cmd {
            return subprocess.CompletedProcess(
                cmd, 99, stdout="", stderr="Usage: pdftotext (xpdf, no bbox)"
            );
        }
        if "-bbox" in cmd {
            raise failure;
        }
        raise AssertionError(f"unexpected command: {cmd}");
    }

    with patch(
        "tools.verify_layout.os.get_exec_path", return_value=["/git/bin", "/other/bin"]
    ), patch("tools.verify_layout.shutil.which", side_effect=fake_which), patch(
        "tools.verify_layout.subprocess.run", side_effect=fake_run
    ) {
        ctx: any;
        with self.assertRaisesRegex(RuntimeError, "bounding boxes") as ctx {
            parse_pdf(Path("cv/main_example.pdf"));
        }
        message: any = `str(ctx.exception);
        self.assertIn("xpdf", message);
        self.assertIn("Poppler aborted", message);
    }
}

impl TestExtractorFailure.test_find_pdftotext_deduplicates_path_candidates -> any {
    h_calls: any;
    def fake_which(cmd, path=None) -> any {
        return "/same/pdftotext";
    }

    h_calls = [];

    def fake_run(cmd, *args___, **kwargs) -> any {
        args: any = tuple(args___);
        if "-h" in cmd {
            h_calls.append(cmd[0]);
            return subprocess.CompletedProcess(
                cmd, 99, stdout="", stderr="Usage: pdftotext ...\n  -bbox : output bounding box"
            );
        }
        raise AssertionError(f"unexpected command: {cmd}");
    }

    with patch(
        "tools.verify_layout.os.get_exec_path", return_value=["/bin1", "/bin2", "/bin3"]
    ), patch("tools.verify_layout.shutil.which", side_effect=fake_which), patch(
        "tools.verify_layout.subprocess.run", side_effect=fake_run
    ) {
        selected: any = verify_layout.find_pdftotext();
        self.assertEqual(selected, "/same/pdftotext");
        self.assertEqual(h_calls, ["/same/pdftotext"]);
    }
}

impl TestExtractorFailure.test_find_pdftotext_caches_resolution -> any {
    h_calls: any;
    bbox_calls: any;
    def fake_which(cmd, path=None) -> any {
        return "/miktex/bin/pdftotext";
    }

    h_calls = [];
    bbox_calls = [];

    def fake_run(cmd, *args____, **kwargs) -> any {
        args: any = tuple(args____);
        binary: any = cmd[0];
        if "-h" in cmd {
            h_calls.append(binary);
            return subprocess.CompletedProcess(
                cmd, 0, stdout="Usage: pdftotext ...\n  -bbox : output bounding box", stderr=""
            );
        }
        if "-bbox" in cmd {
            bbox_calls.append(binary);
            return subprocess.CompletedProcess(
                cmd, 0, stdout="<page width=\"100\" height=\"100\"></page>", stderr=""
            );
        }
        raise AssertionError(f"unexpected command: {cmd}");
    }

    with patch("tools.verify_layout.os.get_exec_path", return_value=["/miktex/bin"]), patch(
        "tools.verify_layout.shutil.which", side_effect=fake_which
    ), patch("tools.verify_layout.subprocess.run", side_effect=fake_run) {
        pages1: any = parse_pdf(Path("cv/main_example.pdf"));
        pages2: any = parse_pdf(Path("cv/main_example.pdf"));
        self.assertEqual(len(pages1), 1);
        self.assertEqual(len(pages2), 1);
        self.assertEqual(h_calls, ["/miktex/bin/pdftotext"]);
        self.assertEqual(bbox_calls, ["/miktex/bin/pdftotext", "/miktex/bin/pdftotext"]);
    }
}

impl TestExtractorFailure.test_poppler_abort_on_empty_info_string_names_that_cause_too -> any {
    failure: any = subprocess.CalledProcessError(
        1,
        "pdftotext",
        stderr="libc++abi: terminating due to uncaught exception of type std::out_of_range: basic_string",
    );
    with patch("tools.verify_layout.shutil.which", return_value="/usr/bin/pdftotext"), patch(
        "tools.verify_layout.subprocess.run", side_effect=failure
    ) {
        ctx: any;
        with self.assertRaisesRegex(RuntimeError, "bounding boxes") as ctx {
            parse_pdf(Path("cv/main_example.pdf"));
        }
    }
    message: any = `str(ctx.exception);
    self.assertIn("xpdf", message);
    self.assertIn("Poppler aborted", message);
    self.assertIn("hyperref", message);
}

impl TestExtractorFailure.test_missing_poppler_raises_a_skippable_error -> any {
    with patch("tools.verify_layout.shutil.which", return_value=None) {
        with self.assertRaisesRegex(RuntimeError, "not found") {
            parse_pdf(Path("cv/main_example.pdf"));
        }
    }
}

impl TestExtractorFailure.test_extractor_failure_exits_2_not_1 -> any {
    with patch("tools.verify_layout.parse_pdf", side_effect=RuntimeError("no -bbox")), patch(
        "sys.argv", ["verify_layout.jac", __file__]
    ) {
        err: any = io.StringIO();
        with redirect_stdout(io.StringIO()), patch("sys.stderr", err) {
            self.assertEqual(main(), 2);
        }
        self.assertIn("skipped:", err.getvalue());
    }
}
