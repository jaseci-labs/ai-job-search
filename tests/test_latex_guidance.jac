import re, unittest;
import from typing { Callable }

glob SKILLS: str = ".claude/skills/job-application-assistant/",
     CV_GUIDE: str = SKILLS + "05-cv-templates.md",
     COVER_GUIDE: str = SKILLS + "06-cover-letter-templates.md",
     APPLY: str = ".claude/commands/apply.md",
     EXAMPLE_CV: str = "cv/main_example.tex",
     GUARDED_FONTENC: re.Pattern = re.compile(
         "\\\\ifpdftex\\s*\\\\usepackage\\[T1\\]\\{fontenc\\}\\s*\\\\fi"
     ),
     MISSING_PACKAGES: str = "Missing LaTeX packages";

def offending(rel: str, bad: Callable[[str], bool]) -> list[str] {
    return [
        f"{rel}:{number}: {line.strip()}"
        for (number, line) in enumerate(doc(rel).splitlines(), 1)
        if bad(line)
    ];
}

class TestLatexGuidance(unittest.TestCase) {
    def test_no_bracket_labelled_bullets {
        for rel in (EXAMPLE_CV, "cover_letters/cover_example.tex", COVER_GUIDE, CV_GUIDE) {
            with self.subTest(file=rel) {
                found: list[str] = offending(
                    rel, lambda (line: str) -> bool { bool(re.search("\\\\item\\s*\\[", line)) }
                );
                self.assertEqual(found, [], "write \\item {[...]}: \\item [ clips the text");
            }
        }
    }

    def test_guides_document_the_special_character_escapes {
        for rel in (CV_GUIDE, COVER_GUIDE) {
            with self.subTest(file=rel) {
                check(
                    self,
                    under(doc(rel), "# LaTeX Special Characters"),
                    ["\\&", "\\%", "\\$", "\\#", "\\_"],
                );
            }
        }
        self.assertRegex(
            under(doc(CV_GUIDE), "# LaTeX Special Characters"), re.compile("silent", re.IGNORECASE)
        );
    }

    def test_pdftotext_commands_pin_utf8 {
        for rel in (APPLY, CV_GUIDE) {
            with self.subTest(file=rel) {
                found: list[str] = offending(
                    rel,
                    lambda (line: str) -> bool {
                        "pdftotext" in line and "-layout" in line and "-enc UTF-8" not in line
                    },
                );
                self.assertEqual(found, [], "pdftotext needs -enc UTF-8");
            }
        }
    }

    def test_fontenc_is_guarded_for_pdflatex {
        for rel in (EXAMPLE_CV, CV_GUIDE) {
            with self.subTest(file=rel) {
                self.assertRegex(doc(rel), GUARDED_FONTENC);
                found: list[str] = offending(
                    rel,
                    lambda (line: str) -> bool {
                        "fontenc" in line
                            and not line.lstrip().startswith("%")
                            and not GUARDED_FONTENC.search(line)
                    },
                );
                self.assertEqual(found, [], "fontenc must stay inside the \\ifpdftex guard");
            }
        }
    }

    def test_missing_package_rule_is_stated_and_every_compile_loop_points_to_it {
        rule: str = under(doc(CV_GUIDE), f"# {MISSING_PACKAGES}");
        self.assertIn("tlmgr search --global --file", rule);
        self.assertIn("never run `sudo`", rule.lower());
        for rel in (COVER_GUIDE, APPLY, ".claude/commands/add-template.md") {
            with self.subTest(file=rel) {
                self.assertIn(MISSING_PACKAGES, doc(rel));
            }
        }
    }

    def test_cv_guide_and_example_cv_share_geometry_scale {
        scales: list[list[str]] = [
            re.findall("\\\\usepackage\\[scale=([0-9.]+)\\]\\{geometry\\}", doc(rel))[:1]
            for rel in (EXAMPLE_CV, CV_GUIDE)
        ];
        self.assertTrue(scales[0], "cv/main_example.tex must declare geometry scale");
        self.assertEqual(scales[1], scales[0]);
    }
}
