import unittest;

import from pathlib { Path }

glob REPO: any;

glob GMAIL_SYNC: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    GMAIL_SYNC = REPO / ".claude" / "commands" / "gmail-sync.md";
}

class TestGmailQueryOperators(unittest.TestCase) {
    def setUp -> any;

    def test_query_excludes_sent_and_drafts_explicitly -> any;

    def test_query_never_restricts_to_the_inbox -> any;
}

with entry:__main__ {
    unittest.main();
}
