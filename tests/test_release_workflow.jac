import unittest;

class ReleaseWorkflowTests(unittest.TestCase) {
    def test_release_runs_only_on_upstream_with_job_level_write_access {
        text: str = doc(".github/workflows/release.yml");
        (top_level, jobs) = text.split("\njobs:", 1);
        self.assertIn("if: github.repository == 'ai-job-search-dev/ai-job-search'", text);
        self.assertIn("permissions:\n  contents: read", top_level);
        self.assertIn("contents: write", jobs);
    }

    def test_actions_are_sha_pinned {
        for line in doc(".github/workflows/release.yml").splitlines() {
            if line.strip().startswith(("- uses:", "uses:")) {
                ref: str = line.split("uses:", 1)[1].strip();
                self.assertRegex(
                    ref.split("@", 1)[1].split()[0],
                    "^[0-9a-f]{40}$",
                    f"action not SHA-pinned: {ref}",
                );
            }
        }
    }
}
