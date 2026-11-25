import re;
import unittest;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parent.parent,
     APPLY: str = (REPO / ".claude" / "commands" / "apply.md").read_text(encoding="utf-8"),
     VERIFY_LAYOUT: Path = REPO / "tools" / "verify_layout.jac";

"""The text under `heading`, up to the next heading."""
def section(text: str, heading: str) -> str;

"""(pdf, pages) of every `verify_pdf <pdf> --pages <n>` command line."""
def page_count_invocations(text: str) -> list[tuple[str, str]];

class ApplyRunsThePageCountCheck(unittest.TestCase) {
    def test_step_5b_checks_both_documents_before_measuring_layout;
    def test_no_step_defers_the_check_to_a_step_that_does_not_run_it;
    def test_layout_tools_deferral_is_backed_by_a_runnable_invocation;
}
