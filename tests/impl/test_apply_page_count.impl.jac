impl section(path, heading) -> any {
    text: any = path.read_text(encoding="utf-8");
    start: any = text.index(heading) + len(heading);
    rest: any = text[start:];
    end: any = re.search("^#{1,4} ", rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

impl page_count_invocations(text) -> any {
    return re.findall(
        "^neojac run jobsearch -- verify_pdf (\\S+) --pages (\\d+)\\s*$", text, re.MULTILINE
    );
}

impl ApplyRunsThePageCountCheck.setUp -> any {
    self.step_5b = section(APPLY, "### 5b. Inspect layout");
}

impl ApplyRunsThePageCountCheck.test_step_5b_checks_both_documents_with_the_guides_page_limits -> any {
    invocations: any = `dict(page_count_invocations(self.step_5b));
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
}

impl ApplyRunsThePageCountCheck.test_page_count_runs_before_the_layout_measurement -> any {
    first_pages: any = self.step_5b.index("--pages");
    first_layout: any = self.step_5b.index("-- verify_layout");
    self.assertLess(first_pages, first_layout);
}

impl ApplyRunsThePageCountCheck.test_no_step_defers_the_check_to_a_step_that_does_not_run_it -> any {
    text: any = APPLY.read_text(encoding="utf-8");
    self.assertNotIn(
        "Step 5d already runs it",
        text,
        "Step 5d's only verify_pdf call is --dump-text; the page-count invocation lives in 5b and the prose must point there",
    );
}

impl ApplyRunsThePageCountCheck.test_layout_tools_deferral_is_backed_by_a_runnable_invocation -> any {
    docstring: any = VERIFY_LAYOUT.read_text(encoding="utf-8");
    self.assertIn("verify_pdf.jac --pages", docstring);
    self.assertGreaterEqual(
        len(page_count_invocations(APPLY.read_text(encoding="utf-8"))),
        2,
        "verify_layout.jac defers page count to verify_pdf.jac --pages, so /apply must actually invoke it",
    );
}
