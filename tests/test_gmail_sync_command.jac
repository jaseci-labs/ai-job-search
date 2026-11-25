import unittest;

class TestGmailQueryOperators(unittest.TestCase) {
    def test_query_excludes_sent_and_drafts_and_never_restricts_to_the_inbox {
        text: str = command("gmail-sync");
        self.assertIn("-in:sent -in:drafts", text);
        self.assertNotIn("in:inbox", text.replace("-in:sent", "").replace("-in:drafts", ""));
    }
}
