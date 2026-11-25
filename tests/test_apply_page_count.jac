"""Guard for /apply Step 5b's page-count check.

The 2-page CV and 1-page cover letter limits are the hard rules of
05-cv-templates.md and 06-cover-letter-templates.md, and two places defer
their enforcement to `tools/verify_pdf.jac --pages`: `verify_layout.jac`'s
docstring ("page count is verify_pdf.jac's job, and CI runs it") and Step 5b's
own prose, which used to say "Step 5d already runs it". Step 5d's only
invocation is `--dump-text`, and no other step passed `--pages` at all, so
the one rule with a mechanical check had zero runnable implementations in
the workflow. These tests pin that the invocations exist where the prose says
they do, with the counts the guides require, and that no step defers the
check to another step that does not run it.
"""

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

"""The body of one markdown section, up to the next heading of any depth."""
def section(path, heading) -> any;

"""(document path, page count) for every runnable verify_pdf --pages line."""
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
