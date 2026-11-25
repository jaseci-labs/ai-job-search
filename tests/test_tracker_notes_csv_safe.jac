import csv;

import io;

import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob COMMANDS: any;

glob GMAIL_SYNC: any;

glob OUTCOME: any;

glob TRACKER_HEADER: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    COMMANDS = REPO / ".claude" / "commands";
    GMAIL_SYNC = COMMANDS / "gmail-sync.md";
    OUTCOME = COMMANDS / "outcome.md";

    TRACKER_HEADER = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline";
}

def section(path, heading) -> any;

class FreeFormNotesWritersStateTheRule(unittest.TestCase) {
    static has CASES: any = [
        (
            GMAIL_SYNC,
            "### Step 7a: Write Approved Updates",
            "append to `notes`",
            "with every comma, double quote and line break deleted from the subject first",
            "Step 7a item 2 deliberately keeps the subject verbatim in `outcome.md`, so the rule must sit on the tracker append, not anywhere in the step",
        ),
        (
            OUTCOME,
            "## Step 4: Update the Tracker",
            "append a short dated note",
            "containing no commas, double quotes or line breaks",
            "Step 4 is the primary status-update path and its note is written free-form - `rejected, no feedback given` is the natural sentence",
        ),
    ];

    def test_rule_is_stated_where_the_append_happens -> any;
}

class NotesShapeUnderTheShippedReader(unittest.TestCase) {
    static has SUBJECT: any = "Re: Your application, Data Scientist - \"next steps\"";

    def test_sanitised_note_keeps_the_row_parseable -> any;

    def test_a_comma_in_the_note_shifts_the_columns -> any;

    def test_a_line_break_in_the_note_splits_the_row_in_two -> any;

    class def _parse(notes) -> any;

    static def _row(notes) -> any;
}

with entry:__main__ {
    unittest.main();
}
