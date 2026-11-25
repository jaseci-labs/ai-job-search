"""Guards for /gmail-sync's Gmail query semantics.

The command's stated intent is "skip sent/drafts - status signals come
from what employers send you". `in:inbox` does not mean that: it matches
only messages currently IN the inbox, so it also excludes every archived
message - and, self-defeatingly, the mail matched by the very
job-search label Step 3.1 hunts for, because the standard filter that
applies such a label also archives ("skip the inbox"). The correct
operators for the stated intent are `-in:sent -in:drafts` (review
finding F18, 2026-08-19). The failure mode is silent under-detection: a
missed rejection or interview invite just looks like "no updates".
"""

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
