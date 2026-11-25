impl ReleaseWorkflowTests.setUp -> any {
    self.text = WORKFLOW.read_text(encoding="utf-8");
}

impl ReleaseWorkflowTests.test_release_runs_only_on_upstream -> any {
    self.assertIn("if: github.repository == 'ai-job-search-dev/ai-job-search'", self.text);
}

impl ReleaseWorkflowTests.test_write_access_is_granted_to_the_job_not_the_workflow -> any {
    top_level: any = self.text.split("\njobs:", 1)[0];
    self.assertIn("permissions:\n  contents: read", top_level);
    self.assertIn("contents: write", self.text.split("\njobs:", 1)[1]);
}

impl ReleaseWorkflowTests.test_actions_are_sha_pinned -> any {
    for line in self.text.splitlines() {
        stripped: any = line.strip();
        if stripped.startswith(("- uses:", "uses:")) {
            ref: any = stripped.split("uses:", 1)[1].strip();
            self.assertRegex(
                ref.split("@", 1)[1].split()[0], "^[0-9a-f]{40}$", f"action not SHA-pinned: {ref}"
            );
        }
    }
}
