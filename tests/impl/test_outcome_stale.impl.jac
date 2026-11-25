impl OutcomeStaleBranchSpecTests.setUp -> any {
    self.text = COMMAND.read_text(encoding="utf-8");
}

impl OutcomeStaleBranchSpecTests.test_stale_argument_documented_in_step0 -> any {
    self.assertIn("`stale` or `sweep`", self.text);
    self.assertIn("`stale <N>` or `sweep <N>`", self.text);
}

impl OutcomeStaleBranchSpecTests.test_step1_suggests_stale_sweep -> any {
    self.assertIn("/outcome stale", self.text);
    self.assertIn("60+ days", self.text);
}

impl OutcomeStaleBranchSpecTests.test_step2c_section_exists -> any {
    self.assertIn("## Step 2c: Stale Sweep Branch", self.text);
}

impl OutcomeStaleBranchSpecTests.test_drafted_rows_excluded_from_stale_candidates -> any {
    `match: any = re.search(
        "## Step 2c: Stale Sweep Branch(.*?)(?=## Step 3:)", self.text, re.DOTALL
    );
    self.assertTrue(`match, "Step 2c must exist");
    step2c: any = `match.group(1);
    self.assertIn("neither final nor `drafted`", step2c);
    self.assertIn("never submitted and cannot receive a response", step2c);
}

impl OutcomeStaleBranchSpecTests.test_default_60_day_threshold -> any {
    `match: any = re.search(
        "## Step 2c: Stale Sweep Branch(.*?)(?=## Step 3:)", self.text, re.DOTALL
    );
    self.assertTrue(`match);
    step2c: any = `match.group(1);
    self.assertIn("60 days", step2c);
}

impl OutcomeStaleBranchSpecTests.test_user_confirmation_options_required -> any {
    `match: any = re.search(
        "## Step 2c: Stale Sweep Branch(.*?)(?=## Step 3:)", self.text, re.DOTALL
    );
    self.assertTrue(`match);
    step2c: any = `match.group(1);
    self.assertIn("`all`", step2c);
    self.assertIn("`select`", step2c);
    self.assertIn("`skip`", step2c);
}

impl OutcomeStaleBranchSpecTests.test_resolves_to_canonical_no_response -> any {
    `match: any = re.search(
        "## Step 2c: Stale Sweep Branch(.*?)(?=## Step 3:)", self.text, re.DOTALL
    );
    self.assertTrue(`match);
    step2c: any = `match.group(1);
    self.assertIn("no_response", step2c);
}
