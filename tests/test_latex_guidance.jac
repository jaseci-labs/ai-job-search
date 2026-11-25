import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob SKILL_DIR: any;

glob CV_TEMPLATES: any;

glob COVER_TEMPLATES: any;

glob APPLY: any;

glob EXAMPLE_CV: any;

glob EXAMPLE_COVER: any;

glob UNBRACED_BRACKET_ITEM: any;

glob REQUIRED_ESCAPES: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    SKILL_DIR = REPO / ".claude" / "skills" / "job-application-assistant";
    CV_TEMPLATES = SKILL_DIR / "05-cv-templates.md";
    COVER_TEMPLATES = SKILL_DIR / "06-cover-letter-templates.md";
    APPLY = REPO / ".claude" / "commands" / "apply.md";
    EXAMPLE_CV = REPO / "cv" / "main_example.tex";
    EXAMPLE_COVER = REPO / "cover_letters" / "cover_example.tex";
    UNBRACED_BRACKET_ITEM = re.compile("\\\\item\\s*\\[");
    REQUIRED_ESCAPES = ["\\&", "\\%", "\\$", "\\#", "\\_"];
}

def section(text, heading) -> any;

class TestBulletBracketTrap(unittest.TestCase) {
    def assert_no_unbraced_bracket_items(path) -> any;

    def test_example_cv_has_no_bracket_labelled_bullets -> any;

    def test_example_cover_letter_has_no_bracket_labelled_bullets -> any;

    def test_cover_letter_guide_does_not_teach_the_broken_pattern -> any;

    def test_cv_guide_does_not_teach_the_broken_pattern -> any;
}

class TestSpecialCharacterGuidance(unittest.TestCase) {
    def assert_escapes_documented(path) -> any;

    def test_cv_guide_documents_the_escapes -> any;

    def test_cover_letter_guide_documents_the_escapes -> any;

    def test_cv_guide_warns_that_percent_truncates_silently -> any;
}

class TestAtsExtractionEncoding(unittest.TestCase) {
    def assert_pdftotext_commands_pin_utf8(path) -> any;

    def test_apply_extraction_command_pins_utf8 -> any;

    def test_cv_guide_extraction_command_pins_utf8 -> any;
}

class TestPdflatexFontEncodingGuard(unittest.TestCase) {
    static has GUARDED_FONTENC: any = re.compile(
        "\\\\ifpdftex\\s*\\\\usepackage\\[T1\\]\\{fontenc\\}\\s*\\\\fi"
    );

    def assert_has_guarded_fontenc(path) -> any;

    def test_example_cv_guards_fontenc_for_pdflatex -> any;

    def test_cv_guide_preamble_guards_fontenc_for_pdflatex -> any;
}

class TestMissingPackageGuidance(unittest.TestCase) {
    static has HEADING: any = "Missing LaTeX packages";

    def test_cv_guide_states_the_rule -> any;

    def test_every_compile_loop_points_to_the_rule -> any;
}

class TestGeometryScaleAlignment(unittest.TestCase) {
    static has GEOMETRY_SCALE: any = re.compile(
        "\\\\usepackage\\[scale=([0-9.]+)\\]\\{geometry\\}"
    );

    def test_cv_guide_and_example_cv_share_geometry_scale -> any;
}

with entry:__main__ {
    unittest.main();
}
