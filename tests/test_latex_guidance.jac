"""Guards for the LaTeX authoring guidance and the example documents.

Three silent-failure modes live here, all found by the 2026-08-19 review
(F9, F31, F34). Each one produces a clean compile and a green CI run
while the rendered document or its ATS extraction is wrong, so the spec
files and the example sources are the only place a test can catch them:

- F9: a bullet written as `\\item [text]` is parsed as moderncv's
  optional label, rendered off the left page edge, and dropped from the
  PDF text layer. The example CV shipped that way for months.
- F31: an unescaped `%` in body text silently truncates the rest of the
  line (`&` at least fails loudly). The guidance must name the escapes.
- F34: `pdftotext` without `-enc UTF-8` emits Latin-1 on Xpdf builds,
  so a correct Danish CV fails the documented "no replacement
  characters" check and the agent is sent to "fix" a healthy document.
"""

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

"""Return the body of a markdown section up to the next heading."""
def section(text, heading) -> any;

"""F9: no document or template doc may teach `\\item [text]`."""
class TestBulletBracketTrap(unittest.TestCase) {
    def assert_no_unbraced_bracket_items(path) -> any;

    def test_example_cv_has_no_bracket_labelled_bullets -> any;

    def test_example_cover_letter_has_no_bracket_labelled_bullets -> any;

    def test_cover_letter_guide_does_not_teach_the_broken_pattern -> any;

    def test_cv_guide_does_not_teach_the_broken_pattern -> any;
}

"""F31: both template guides must document the LaTeX escapes."""
class TestSpecialCharacterGuidance(unittest.TestCase) {
    def assert_escapes_documented(path) -> any;

    def test_cv_guide_documents_the_escapes -> any;

    def test_cover_letter_guide_documents_the_escapes -> any;

    def test_cv_guide_warns_that_percent_truncates_silently -> any;
}

"""F34: every documented extraction command must pin the encoding."""
class TestAtsExtractionEncoding(unittest.TestCase) {
    def assert_pdftotext_commands_pin_utf8(path) -> any;

    def test_apply_extraction_command_pins_utf8 -> any;

    def test_cv_guide_extraction_command_pins_utf8 -> any;
}

"""#384: the pdflatex fallback must load T1 fontenc, and only under pdflatex.

    Without T1, pdflatex stores accented letters decomposed in the text layer
    (`e` + U+0300), so an ATS keyword match on `Genève` fails while the PDF
    looks right. moderncv 2.5 loads T1 itself; the apt-packaged 2.3.1 does not.
    The line must be guarded so the documented lualatex path is untouched.
    """
class TestPdflatexFontEncodingGuard(unittest.TestCase) {
    static has GUARDED_FONTENC: any = re.compile(
        "\\\\ifpdftex\\s*\\\\usepackage\\[T1\\]\\{fontenc\\}\\s*\\\\fi"
    );

    def assert_has_guarded_fontenc(path) -> any;

    def test_example_cv_guards_fontenc_for_pdflatex -> any;

    def test_cv_guide_preamble_guards_fontenc_for_pdflatex -> any;
}

"""A minimal TeX install only behaves like a full one if every compile
    loop installs a missing package instead of editing the source around it.
    The rule lives once in 05-cv-templates.md; every agent compile loop (05, 06,
    /apply, /add-template) points to it. SETUP.md's smoke tests are run by people
    and list every package up front, so they carry no pointer."""
class TestMissingPackageGuidance(unittest.TestCase) {
    static has HEADING: any = "Missing LaTeX packages";

    def test_cv_guide_states_the_rule -> any;

    def test_every_compile_loop_points_to_the_rule -> any;
}

"""The geometry scale specified in 05-cv-templates.md must match cv/main_example.tex."""
class TestGeometryScaleAlignment(unittest.TestCase) {
    static has GEOMETRY_SCALE: any = re.compile(
        "\\\\usepackage\\[scale=([0-9.]+)\\]\\{geometry\\}"
    );

    def test_cv_guide_and_example_cv_share_geometry_scale -> any;
}

with entry:__main__ {
    unittest.main();
}
