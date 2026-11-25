import unittest;

class OutcomeFollowupBranchSpec(unittest.TestCase) {
    def test_followup_branch_and_its_rules_are_documented {
        expect(
            self,
            doc(OUTCOME),
            "## Step 2b: Follow-Up Branch",
            "`followup <N>`",
            "draft only, never send",
            "no new claims",
            "Maximum two follow-ups per application",
            "30-day staleness flag",
        );
    }

    def test_followup_candidates_reuse_the_open_pipeline_quiet_clock {
        branch: str = between(doc(OUTCOME), "## Step 2b: Follow-Up Branch", "## Step 2c:");
        expect(
            self,
            between(branch, "**Candidates.**", "**Threshold.**"),
            "latest dated entry in `notes`",
            "whichever is more recent",
        );
    }

    def test_lint_skills_passes {
        lint_skills_passes(self);
    }
}
