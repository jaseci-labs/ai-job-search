import unittest;

class NotionSyncCommandSpec(unittest.TestCase) {
    def test_command_file_is_substantive_and_keeps_its_privacy_rule {
        text: str = doc(NOTION_SYNC);
        self.assertTrue(text.startswith("# /notion-sync"), text[:40]);
        expect(
            self,
            text,
            "## Step 0",
            "## Step 4",
            "## Important Rules",
            "never upload, attach, or embed",
        );
    }

    def test_personal_sync_state_is_gitignored {
        expect(self, doc(".gitignore"), "job_scraper/notion_sync.json");
    }

    def test_step2_join_names_the_field_ranked_entries_actually_carry {
        line: str = [
            ln
            for ln in doc(NOTION_SYNC).splitlines()
            if "matched to `job_scraper/seen_jobs.json` entries" in ln
        ][0];
        expect(self, line, "company + title", "`title`", "`role`");
        expect_not(self, line, "company + role");
    }

    def test_expired_jobs_are_update_only_and_never_create_or_rebuild_pages {
        text: str = doc(NOTION_SYNC);
        expect(
            self,
            between(text, "## Step 2:", "## Step 3:"),
            "entries with status `expired` join the sync set regardless of score as update-only candidates",
            "An entry selected only because it is `expired` and has no matching tracker row",
            "If a matching tracker row exists, it remains an ordinary sync item and tracker status precedence applies.",
        );
        expect(
            self,
            between(text, "## Step 3:", "## Step 4:"),
            "sync set contains only expired-only entries",
            "stop without asking where to create a database",
            "without creating the database or writing `job_scraper/notion_sync.json`",
        );
        expect(
            self,
            between(text, "## Step 4:", "## Step 5:"),
            "if the job is an expired-only entry, skip it - do not create a page or write a body",
            "Match, expired-only entry** → update **Status only** to `expired`",
        );
        expect(
            self,
            between(text, "## Step 5:", "## Step 6:"),
            "Never write or rebuild a body for an expired-only entry, including when `--rebuild` is set.",
        );
    }

    def test_key_miss_falls_back_to_an_exact_url_match_and_rekeys_the_row {
        text: str = doc(NOTION_SYNC);
        expect(
            self,
            between(text, "## Step 4:", "## Step 5:"),
            "**No match on `Key`** → fall back to the posting URL before creating anything",
            "whose `URL` equals the job's URL exactly",
            "**Exactly one URL match** → re-key it: set its `Key` to the job's key",
            "If the row's current `Key` is the key of another job in this sync set, it is not drifted; treat it like a multiple match instead.",
            "**More than one URL match** → create nothing and update nothing for this job",
            "**No URL match** → if the job is an expired-only entry, skip it",
            "**and** whose `Key` is non-empty",
            "invisible to this command, including to the URL fallback",
        );
        expect(
            self,
            between(text, "## Step 6:", "## Important Rules"),
            "<R> re-keyed by URL",
            "<A> skipped (ambiguous URL match)",
        );
        expect(
            self,
            between(text, "## Important Rules", "## Adapting"),
            "never on fuzzy title comparison",
            "exact match on the `URL` property",
        );
    }

    def test_lint_skills_passes {
        lint_skills_passes(self);
    }
}
