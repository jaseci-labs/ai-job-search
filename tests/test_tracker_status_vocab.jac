import unittest;

glob VOCAB: str = "## Tracker status vocabulary",
     CASES: list[tuple[str, str, list[str], list[str]]] = [
         ("outcome", "", [VOCAB], []),
         (
             "outcome",
             VOCAB,
             [
                 "`no_response`",
                 "`offer_declined`",
                 "no response",
                 "offer declined",
                 "same values",
                 "not separate statuses",
                 "equally",
                 "everything else",
                 "underscores, never spaces",
                 "Final",
             ],
             [],
         ),
         (
             "outcome",
             "## Step 1: Load State and Identify the Application",
             ["With an argument", "Without an argument", "Derive the archive"],
             [],
         ),
         ("outcome", "## Step 4: Update the Tracker", ["no_response", "offer_declined"], []),
         (
             "html-report",
             "## Step 1: Collect Data",
             [
                 "no response",
                 "no_response",
                 "offer declined",
                 "offer_declined",
                 "anything else",
                 "unrecognised",
             ],
             ["interview_only"],
         ),
         (
             "html-report",
             "## Step 2: Compute Summary Stats",
             ["excluded from every statistic below"],
             [],
         ),
         ("gmail-sync", "## Step 2: Load State", ["Tracker status vocabulary"], ["no response"]),
         ("gmail-sync", "## Step 9: Staleness Check", ["Skip `drafted` rows here"], []),
         (
             "notion-sync",
             "## Step 3: Load Sync State and Locate the Database",
             ["no_response", "offer_declined"],
             ["no response"],
         ),
         (
             "notion-sync",
             "## Step 4: Upsert Database Rows",
             ["never push a space form", "Tracker status vocabulary"],
             [],
         ),
         ("apply", "### Step 6b: Record the Application", ["Tracker status vocabulary"], []),
         ("interview", "## Step 0: Parse Input", ["Tracker status vocabulary"], []),
     ];

class TrackerStatusVocabulary(unittest.TestCase) {
    def test_each_section_states_its_status_spellings;
}
