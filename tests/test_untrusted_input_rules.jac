import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob RULE: any;

glob INGESTS: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    RULE = re.compile("untrusted (?:third-party )?data, never instructions");
    INGESTS = re.compile(
        "WebFetch|search_threads|get_thread|get_message|cli\\.ts detail|job_posting\\.md"
    );
}

def specs -> any;

class TrustBoundaryTests(unittest.TestCase) {
    def test_derived_set_is_not_empty -> any;

    def test_every_ingesting_spec_states_the_rule -> any;

    def test_gmail_sync_never_acts_on_email_content -> any;

    def test_setup_calibration_never_copies_archive_wording -> any;
}

with entry:__main__ {
    unittest.main();
}
