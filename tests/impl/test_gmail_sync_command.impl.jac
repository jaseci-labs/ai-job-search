impl TestGmailQueryOperators.setUp -> any {
    self.text = GMAIL_SYNC.read_text(encoding="utf-8");
}

impl TestGmailQueryOperators.test_query_excludes_sent_and_drafts_explicitly -> any {
    self.assertIn(
        "-in:sent -in:drafts",
        self.text,
        "the query must exclude sent/drafts with negative operators, which keep archived and label-filtered mail in scope",
    );
}

impl TestGmailQueryOperators.test_query_never_restricts_to_the_inbox -> any {
    self.assertNotIn(
        "in:inbox",
        self.text.replace("-in:sent", "").replace("-in:drafts", ""),
        "in:inbox silently drops archived mail and everything a label-and-archive filter routed past the inbox - exactly the mail the label search in Step 3.1 exists to find",
    );
}
