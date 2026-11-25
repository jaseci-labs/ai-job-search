import re, unittest;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parent.parent,
     APPLY: str = (REPO / ".claude" / "commands" / "apply.md").read_text(encoding="utf-8"),
     VERIFY_LAYOUT: Path = REPO / "tools" / "verify_layout.jac";

"""The text under `heading`, up to the next heading."""
def section(text: str, heading: str) -> str {
    rest: str = text[text.index(heading) + len(heading):];
    end: any = re.search("^#{1,4} ", rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

"""(pdf, pages) of every `verify_pdf <pdf> --pages <n>` command line."""
def page_count_invocations(text: str) -> list[tuple[str, str]] {
    return re.findall(
        "^neojac run jobsearch -- verify_pdf (\\S+) --pages (\\d+)\\s*$", text, re.MULTILINE
    );
}

class ApplyRunsThePageCountCheck(unittest.TestCase) {
    def test_step_5b_checks_both_documents_before_measuring_layout {
        step_5b: str = section(APPLY, "### 5b. Inspect layout");
        invocations: dict[str, str] = dict(page_count_invocations(step_5b));
        self.assertEqual(
            invocations.get("cv/main_<company>_<role>.pdf"),
            "2",
            "Step 5b must run verify_pdf.jac --pages 2 on the CV - the hard 2-page limit has no other mechanical check",
        );
        self.assertEqual(
            invocations.get("cover_letters/cover_<company>_<role>.pdf"),
            "1",
            "Step 5b must run verify_pdf.jac --pages 1 on the cover letter",
        );
        self.assertLess(step_5b.index("--pages"), step_5b.index("-- verify_layout"));
    }

    def test_no_step_defers_the_check_to_a_step_that_does_not_run_it {
        self.assertNotIn(
            "Step 5d already runs it",
            APPLY,
            "Step 5d's only verify_pdf call is --dump-text; the page-count invocation lives in 5b and the prose must point there",
        );
    }

    def test_layout_tools_deferral_is_backed_by_a_runnable_invocation {
        self.assertIn("verify_pdf.jac --pages", VERIFY_LAYOUT.read_text(encoding="utf-8"));
        self.assertGreaterEqual(
            len(page_count_invocations(APPLY)),
            2,
            "verify_layout.jac defers page count to verify_pdf.jac --pages, so /apply must actually invoke it",
        );
    }
}
