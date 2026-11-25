impl NotionSyncCommandSpec.test_command_file_exists_with_lint_compliant_header -> any {
    self.assertTrue(COMMAND.is_file(), "command spec missing");
    first_line: any = COMMAND.read_text(encoding="utf-8").splitlines()[0];
    self.assertTrue(
        first_line.startswith("# /notion-sync"),
        f"header must start with '# /notion-sync' (lint_skills.jac enforces it), got: {first_line!r}",
    );
}

impl NotionSyncCommandSpec.test_command_file_is_substantive -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    for section in ("## Step 0", "## Step 4", "## Important Rules") {
        self.assertIn(section, text, f"spec lost its {section!r} section");
    }
}

impl NotionSyncCommandSpec.test_personal_sync_state_is_gitignored -> any {
    self.assertIn(
        "job_scraper/notion_sync.json",
        GITIGNORE.read_text(encoding="utf-8"),
        "notion_sync.json is personal state and must never be committable",
    );
}

impl NotionSyncCommandSpec.test_step2_join_names_the_field_ranked_entries_actually_carry -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    line: any = next(
        l for l in text.splitlines() if "matched to `job_scraper/seen_jobs.json` entries" in l
    );
    self.assertIn("company + title", line);
    self.assertIn("`title`", line);
    self.assertIn("`role`", line);
    self.assertNotIn("company + role", line);
}

impl NotionSyncCommandSpec.test_privacy_rule_documents_never_sync -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn(
        "never upload, attach, or embed",
        text,
        "spec lost the rule that CV/cover-letter content never syncs to Notion",
    );
}

impl NotionSyncCommandSpec.test_expired_jobs_are_update_only_and_never_create_or_rebuild_pages -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    step2: any = text.split("## Step 2:", 1)[1].split("## Step 3:", 1)[0];
    step3: any = text.split("## Step 3:", 1)[1].split("## Step 4:", 1)[0];
    step4: any = text.split("## Step 4:", 1)[1].split("## Step 5:", 1)[0];
    step5: any = text.split("## Step 5:", 1)[1].split("## Step 6:", 1)[0];

    self.assertIn(
        "entries with status `expired` join the sync set regardless of score as update-only candidates",
        step2,
    );
    self.assertIn(
        "An entry selected only because it is `expired` and has no matching tracker row", step2
    );
    self.assertIn(
        "If a matching tracker row exists, it remains an ordinary sync item and tracker status precedence applies.",
        step2,
    );
    self.assertIn("sync set contains only expired-only entries", step3);
    self.assertIn("stop without asking where to create a database", step3);
    self.assertIn("without creating the database or writing `job_scraper/notion_sync.json`", step3);
    self.assertIn(
        "if the job is an expired-only entry, skip it - do not create a page or write a body", step4
    );
    self.assertIn("Match, expired-only entry** → update **Status only** to `expired`", step4);
    self.assertIn(
        "Never write or rebuild a body for an expired-only entry, including when `--rebuild` is set.",
        step5,
    );
}

impl NotionSyncCommandSpec.test_key_miss_falls_back_to_an_exact_url_match_and_rekeys_the_row -> any {
    text: any = COMMAND.read_text(encoding="utf-8");
    step4: any = text.split("## Step 4:", 1)[1].split("## Step 5:", 1)[0];
    step6: any = text.split("## Step 6:", 1)[1].split("## Important Rules", 1)[0];
    rules: any = text.split("## Important Rules", 1)[1].split("## Adapting", 1)[0];

    self.assertIn(
        "**No match on `Key`** → fall back to the posting URL before creating anything", step4
    );
    self.assertIn("whose `URL` equals the job's URL exactly", step4);
    self.assertIn("**Exactly one URL match** → re-key it: set its `Key` to the job's key", step4);
    self.assertIn(
        "If the row's current `Key` is the key of another job in this sync set, it is not drifted; treat it like a multiple match instead.",
        step4,
    );
    self.assertIn(
        "**More than one URL match** → create nothing and update nothing for this job", step4
    );
    self.assertIn("**No URL match** → if the job is an expired-only entry, skip it", step4);
    self.assertIn("**and** whose `Key` is non-empty", step4);
    self.assertIn("invisible to this command, including to the URL fallback", step4);
    self.assertIn("<R> re-keyed by URL", step6);
    self.assertIn("<A> skipped (ambiguous URL match)", step6);
    self.assertIn("never on fuzzy title comparison", rules);
    self.assertIn("exact match on the `URL` property", rules);
}

impl NotionSyncCommandSpec.test_lint_skills_passes -> any {
    result: any = subprocess.run([*tool("lint_skills")], cwd=REPO, capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
}
