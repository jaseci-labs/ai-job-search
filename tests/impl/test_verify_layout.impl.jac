impl line(top: float, left: float = 50.0, height: float = 10.0, text: str = "x") -> Line {
    return Line(top=top, bottom=top + height, left=left, height=height, text=text);
}

impl at(
    top: float, left: float, text: str, text_left: float | None = None, bottom: float | None = None
) -> Line {
    end: float = top + 14.0 if bottom is None else bottom;
    return Line(top=top, bottom=end, left=left, height=end - top, text=text, text_left=text_left);
}

impl fake_path(
    fixture: unittest.TestCase,
    binaries: dict[str, str],
    with_bbox: tuple[str, ...] = (),
    help_on: str = "stderr",
    failure: Exception | None = None,
) -> list[list[str]] {
    calls: list[list[str]] = [];

    def fake_run(cmd: list[str], **kwargs: any) -> any {
        calls.append(cmd);
        if "-h" in cmd {
            usage: str = "Usage: pdftotext ..."
                + ("\n  -bbox : output bounding box" if cmd[0] in with_bbox else "");
            return subprocess.CompletedProcess(
                cmd, 99, **{"stdout": "", "stderr": "", help_on: usage}
            );
        }
        if "-bbox" not in cmd {
            raise AssertionError(f"unexpected command: {cmd}");
        }
        if failure {
            raise failure;
        }
        return subprocess.CompletedProcess(
            cmd, 0, stdout="<page width=\"100\" height=\"100\"></page>", stderr=""
        );
    }

    for patcher in (
        patch("tools.verify_layout.os.get_exec_path", return_value=list(binaries)),
        patch(
            "tools.verify_layout.shutil.which",
            side_effect=lambda (cmd: str, path: str | None = None) -> str | None {
                binaries.get(path)
            },
        ),
        patch("tools.verify_layout.subprocess.run", side_effect=fake_run),
    ) {
        patcher.start();
        fixture.addCleanup(patcher.stop);
    }
    return calls;
}

impl PageGeometry.test_gap_and_bottom_space {
    holed: Page = Page(A4, [line(50), line(64), line(78), line(400), line(770, text="1/2")]);
    (gap, y) = holed.largest_gap();
    self.assertEqual((round(gap), round(y)), (322, 78));
    self.assertEqual(round(holed.bottom_space), 432);
    self.assertTrue(Page(A4, []).empty);
    with redirect_stdout(io.StringIO()) {
        problems: list[str] = `report(Path("synthetic"), [holed]);
    }
    self.assertTrue(any(["hole" in m for m in problems]), problems);
}

impl PageGeometry.test_footer_band {
    self.assertFalse(Page(A4, [line(50), line(800, text="2/2")]).footer_crowded);
    self.assertTrue(Page(A4, [line(50), line(780), line(800)]).footer_crowded);
}

impl PageGeometry.test_heading_and_indent_detection {
    page: Page = Page(
        A4, [line(50, height=16.0, text="Professional Experience"), line(80), line(94, left=70.0)]
    );
    (heading, header, bullet) = page.body;
    self.assertTrue(page.is_heading(heading));
    self.assertFalse(page.is_heading(header));
    self.assertTrue(page.is_indented(bullet));
    self.assertFalse(page.is_indented(header));
}

impl PageGeometry.test_text_start {
    self.assertEqual(text_start([(58.9, 0, 1, "•"), (72.1, 0, 1, "Laid")]), 72.1);
    unmarked: list[list[tuple[float, float, float, str]]] = [
        [(59.5, 0, 1, "Kitchen"), (94.9, 0, 1, "Gardener")],
        [(59.0, 0, 1, "•")],
        *[[(69.4, 0, 1, glyph), (77.7, 0, 1, "[Event]")] for glyph in ("-", "*", "–", "—", "○")],
    ];
    for words in unmarked {
        with self.subTest(words=words) {
            self.assertIsNone(text_start(words));
        }
    }
}

impl Orphans.test_breaks_that_are_reported {
    cases: list[tuple[str, list[Line], list[Line]]] = [
        (
            "ends on the section heading",
            [line(50), line(64), line(700, height=16.0, text="Education")],
            [line(60, text="Example University"), line(74, left=70.0)],
        ),
        (
            ORPHAN,
            [line(50), line(700, text="Software Engineer")],
            [line(60, left=70.0, text="- built the thing")],
        ),
        (
            "lone list marker",
            [line(50), line(700, text="●")],
            [line(60, left=70.0, text="continued item text here")],
        ),
        (
            ORPHAN,
            [line(50), line(700, text="Data Analyst")],
            [line(60, left=70.0, text="- first bullet")],
        ),
        (
            ORPHAN,
            [at(700, 59.5, "Kitchen Gardener 1975-1980")],
            [at(60, 58.9, "• Worked in the kitchen garden", 71.6)],
        ),
        (
            ORPHAN,
            [
                at(323, 59.5, "Professional Experience"),
                at(695.9, 59.0, "○", bottom=707.6),
                at(700.5, 70.4, "[Job Title] [YYYY-YYYY]"),
            ],
            [DASH, ACHIEVEMENT],
        ),
        (
            ORPHAN,
            [at(700, 59.0, "○ [Job Title] [YYYY-YYYY]")],
            [DASH, at(64.4, 81.3, "[Achievement 1]")],
        ),
        (
            ORPHAN,
            [at(700, 59.0, "○ [Degree] in [Field] [YYYY-YYYY]")],
            [at(60, 70.4, "[Brief description or key topics.]")],
        ),
        (ORPHAN, [EXPERIENCE, at(700, 70.4, "[Job Title]")], [RUNNING_HEADER, DASH, ACHIEVEMENT]),
    ];
    for (phrase, before, after) in cases {
        with self.subTest(last=before[-1].text, first=after[0].text) {
            problems: list[str] = find_orphans([Page(A4, before), Page(A4, after)]);
            self.assertTrue(any([phrase in m for m in problems]), problems);
        }
    }
}

impl Orphans.test_breaks_that_are_clean {
    cases: list[tuple[list[Line], list[Line]]] = [
        ([line(50), line(700)], [line(60)]),
        (
            [GARDEN, at(700, 58.9, "• Replanted the long border with plants raised", 72.1)],
            [at(60, 72.1, "from seed, lifting the old clumps")],
        ),
        (
            [GARDEN, at(700, 58.9, "• (in winter) relaid the gravel paths along", 72.1)],
            [at(60, 72.1, "the old orchard wall and round the pond")],
        ),
        (
            [at(700, 58.9, "• Laid a new cobbled path, so", 72.1)],
            [at(60, 72.1, "— that rain ran off into the borders")],
        ),
        (
            [
                at(50, 59.5, "Core Competencies", bottom=70.5),
                at(728.81, 70.4, "[Skill Category 4]: [Domain expertise, methods.]", bottom=743.4),
                at(730.09, 59.0, "🟤", bottom=741.8),
            ],
            [
                at(66.8, 70.4, "[Skill Category 5]: [Tools, platforms, software.]", bottom=81.4),
                at(68.1, 59.0, "🟤", bottom=79.8),
            ],
        ),
        (
            [
                at(696.4, 59.5, "Honors and Awards", bottom=716.9),
                at(
                    722.13,
                    70.4,
                    "[Award Name] for the long-running community orchard",
                    bottom=736.7,
                ),
                at(723.41, 59.0, "🟤", bottom=735.09),
            ],
            [at(66.8, 69.4, "– [Event/Organization] ([Year]).")],
        ),
        (
            [
                at(721.44, 125.6, "operations for the data team and later modules.]"),
                at(721.64, 70.4, "Kubernetes Terraform"),
            ],
            [at(66.8, 70.4, "[Skill Category 3]: [Specific skills]")],
        ),
        (
            [at(700, 81.3, "[Achievement or responsibility 1 - be")],
            [at(60, 81.3, "specific, use numbers where possible]")],
        ),
        (
            [EXPERIENCE, at(700, 81.3, "[Achievement or responsibility 2]")],
            [RUNNING_HEADER, at(62, 70.4, "[Company] [City, Country]")],
        ),
    ];
    for (before, after) in cases {
        with self.subTest(last=before[-1].text, first=after[0].text) {
            self.assertEqual(find_orphans([Page(A4, before), Page(A4, after)]), []);
        }
    }
}

impl ExtractorFailure.setUp {
    verify_layout.find_pdftotext.cache_clear();
    self.addCleanup(verify_layout.find_pdftotext.cache_clear);
}

impl ExtractorFailure.test_failing_extractor_raises_a_skippable_error_naming_both_causes {
    for (code, stderr) in [
        (99, "Error: unknown flag"),
        (
            1,
            "libc++abi: terminating due to uncaught exception of type std::out_of_range: basic_string",
        ),
    ] {
        failure: any = subprocess.CalledProcessError(code, "pdftotext", stderr=stderr);
        with self.subTest(stderr=stderr), patch(
            "tools.verify_layout.shutil.which", return_value="/usr/bin/pdftotext"
        ), patch("tools.verify_layout.subprocess.run", side_effect=failure) {
            with self.assertRaisesRegex(RuntimeError, "bounding boxes") as ctx {
                parse_pdf(CV);
            }
            for phrase in ("xpdf", "Poppler aborted", "hyperref") {
                self.assertIn(phrase, str(ctx.exception));
            }
        }
    }
}

impl ExtractorFailure.test_first_candidate_lacks_bbox_and_second_has_it {
    calls: list[list[str]] = fake_path(
        self,
        {"/git/bin": "/git/bin/pdftotext", "/miktex/bin": "/miktex/bin/pdftotext"},
        with_bbox=("/miktex/bin/pdftotext",),
    );
    self.assertEqual(len(parse_pdf(CV)), 1);
    self.assertEqual([c[0] for c in calls if "-bbox" in c], ["/miktex/bin/pdftotext"]);
}

impl ExtractorFailure.test_no_candidate_has_bbox_keeps_skip_path {
    fake_path(
        self,
        {"/git/bin": "/git/bin/pdftotext", "/other/bin": "/other/bin/pdftotext"},
        failure=subprocess.CalledProcessError(
            99, "/git/bin/pdftotext", stderr="Error: unknown flag"
        ),
    );
    with self.assertRaisesRegex(RuntimeError, "bounding boxes") as ctx {
        parse_pdf(CV);
    }
    self.assertIn("xpdf", str(ctx.exception));
    self.assertIn("Poppler aborted", str(ctx.exception));
}

impl ExtractorFailure.test_find_pdftotext_deduplicates_path_candidates {
    same: str = "/same/pdftotext";
    calls: list[list[str]] = fake_path(
        self, {"/bin1": same, "/bin2": same, "/bin3": same}, with_bbox=(same,)
    );
    self.assertEqual(verify_layout.find_pdftotext(), same);
    self.assertEqual(calls, [[same, "-h"]]);
}

impl ExtractorFailure.test_find_pdftotext_caches_resolution {
    binary: str = "/miktex/bin/pdftotext";
    calls: list[list[str]] = fake_path(
        self, {"/miktex/bin": binary}, with_bbox=(binary,), help_on="stdout"
    );
    self.assertEqual([len(parse_pdf(CV)), len(parse_pdf(CV))], [1, 1]);
    self.assertEqual(
        [c[:2] for c in calls], [[binary, "-h"], [binary, "-bbox"], [binary, "-bbox"]]
    );
}

impl ExtractorFailure.test_missing_poppler_raises_a_skippable_error {
    with patch("tools.verify_layout.shutil.which", return_value=None) {
        with self.assertRaisesRegex(RuntimeError, "not found") {
            parse_pdf(CV);
        }
    }
}

impl ExtractorFailure.test_extractor_failure_exits_2_not_1 {
    err: io.StringIO = io.StringIO();
    with patch("tools.verify_layout.parse_pdf", side_effect=RuntimeError("no -bbox")), patch(
        "sys.argv", ["verify_layout.jac", __file__]
    ), redirect_stdout(io.StringIO()), patch("sys.stderr", err) {
        self.assertEqual(main(), 2);
    }
    self.assertIn("skipped:", err.getvalue());
}
