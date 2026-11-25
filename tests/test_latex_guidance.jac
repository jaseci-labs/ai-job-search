import re;
import unittest;
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

def offending(rel: str, bad: Callable[[str], bool]) -> list[str];

class TestLatexGuidance(unittest.TestCase) {
    def test_no_bracket_labelled_bullets;
    def test_guides_document_the_special_character_escapes;
    def test_pdftotext_commands_pin_utf8;
    def test_fontenc_is_guarded_for_pdflatex;
    def test_missing_package_rule_is_stated_and_every_compile_loop_points_to_it;
    def test_cv_guide_and_example_cv_share_geometry_scale;
}
