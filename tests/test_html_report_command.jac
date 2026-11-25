import csv;
import datetime;
import io;
import json;
import os;
import re;
import subprocess;
import unicodedata;
import unittest;
import from importlib.util { find_spec }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob REPO_ROOT: Path = Path(__file__).resolve().parent.parent,
     COMMANDS: Path = REPO_ROOT / ".claude" / "commands",
     COMMAND_TEXT: str = (COMMANDS / "html-report.md").read_text(encoding="utf-8"),
     HEADER: list[str] = re.search(
         "^\\s*(date,company,[a-z_,]+)$", (COMMANDS / "apply.md").read_text(encoding="utf-8"), re.M
     ).group(1).split(","),
     PAYLOAD: str = "x' onmouseover='alert(1)' \" onfocus=\"alert(2)\" <img src=x onerror=alert(3)>",
     SCREEN: str = "- [x] Phone screen\n",
     INTERVIEWED: str = "- [x] Phone screen\n- [x] Technical interview\n";

def row(
    company: str,
    role: str,
    status: str,
    source: str = "",
    date: str = "2026-10-01",
    sector: str = "AI",
    notes: str = "",
) -> list[str];

def tracker(rows: list[list[str]]) -> str;

def folder(company: str, role: str) -> str;

def table(html: str, caption: str) -> dict[str, str];

class HtmlReportCommandFile(unittest.TestCase) {
    def test_command_file_has_its_header_and_a_body;
    def test_step1_parses_every_canonical_tracker_column;
    def test_command_file_states_the_table_order_and_the_figure_rules;
    def test_reports_folder_is_gitignored;
}

class HtmlReportScript(unittest.TestCase) {
    def site(text: str | bytes | None, archives: dict[str, any] = {}) -> Path;
    def launch(
        base: Path, out: str | Path = "out.html", **kwargs: any
    ) -> subprocess.CompletedProcess;
    def render(rows: list[list[str]], archives: dict[str, any] = {}) -> tuple[str, str];
    def test_fixture_tracker_pins_every_figure;
    def test_values_are_escaped_and_page_is_offline;
    def test_out_must_be_an_html_file;
    def test_out_expands_a_quoted_home_path;
    def test_settings_and_guards_allow_the_script;
    def test_trackers_are_read_or_refused_with_a_message;
    def test_archive_folders_match_only_their_own_application;
    def test_rendered_figures;
    def test_malformed_dates_are_not_charted_and_dates_sort_chronologically;
}

@unittest.skipUnless(
    find_spec("yaml"),
    "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
)
class HtmlReportLintIntegration(unittest.TestCase) {
    def test_lint_passes_on_real_repo;
}

with entry:__main__ {
    unittest.main();
}
