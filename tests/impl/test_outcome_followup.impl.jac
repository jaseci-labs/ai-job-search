impl OutcomeFollowupBranchSpec.test_followup_branch_exists -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "## Step 2b: Follow-Up Branch", text, "outcome.md lost its follow-up branch section"
    );
}

impl OutcomeFollowupBranchSpec.test_followup_argument_documented -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn("`followup <N>`", text, "spec lost the /outcome followup argument forms");
}

impl OutcomeFollowupBranchSpec.test_draft_only_rule_present -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "draft only, never send",
        text,
        "spec lost the rule that the follow-up branch never sends anything on the user's behalf",
    );
}

impl OutcomeFollowupBranchSpec.test_no_new_claims_rule_present -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "no new claims",
        text,
        "spec lost the rule that follow-ups only reuse claims from the archived submitted materials",
    );
}

impl OutcomeFollowupBranchSpec.test_two_followup_cap_present -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "Maximum two follow-ups per application",
        text,
        "spec lost the cap that stops the follow-up branch from nagging indefinitely",
    );
}

impl OutcomeFollowupBranchSpec.test_followup_candidates_reuse_the_open_pipeline_quiet_clock -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    branch: any = text.split("## Step 2b: Follow-Up Branch", 1)[1].split("## Step 2c:", 1)[0];
    candidates: any = branch.split("**Candidates.**", 1)[1].split("**Threshold.**", 1)[0];
    self.assertIn("latest dated entry in `notes`", candidates);
    self.assertIn("whichever is more recent", candidates);
}

impl OutcomeFollowupBranchSpec.test_threshold_contrast_with_gmail_sync_documented -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "30-day staleness flag",
        text,
        "spec lost the rationale for the 10-day nudge vs /gmail-sync's 30-day alarm",
    );
}

impl OutcomeFollowupBranchSpec.test_lint_skills_passes -> any {
    result: any = subprocess.run([*tool("lint_skills")], cwd=REPO, capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
}
