impl OutcomeStaleBranchSpecTests.test_stale_sweep_is_documented_and_suggested {
    expect(
        self,
        doc(OUTCOME),
        "`stale` or `sweep`",
        "`stale <N>` or `sweep <N>`",
        "/outcome stale",
        "60+ days",
    );
}

impl OutcomeStaleBranchSpecTests.test_step2c_candidates_threshold_confirmation_and_resolution {
    expect(
        self,
        between(doc(OUTCOME), "## Step 2c: Stale Sweep Branch", "## Step 3:"),
        "neither final nor `drafted`",
        "never submitted and cannot receive a response",
        "60 days",
        "`all`",
        "`select`",
        "`skip`",
        "no_response",
    );
}
