import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob APPLY: any;

glob VERIFY_LAYOUT: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    APPLY = REPO / ".claude" / "commands" / "apply.md";
    VERIFY_LAYOUT = REPO / "tools" / "verify_layout.jac";
}

def section(path, heading) -> any;

def page_count_invocations(text) -> any;

class ApplyRunsThePageCountCheck(unittest.TestCase) {
    def setUp -> any;

    def test_step_5b_checks_both_documents_with_the_guides_page_limits -> any;

    def test_page_count_runs_before_the_layout_measurement -> any;

    def test_no_step_defers_the_check_to_a_step_that_does_not_run_it -> any;

    def test_layout_tools_deferral_is_backed_by_a_runnable_invocation -> any;
}

with entry:__main__ {
    unittest.main();
}
