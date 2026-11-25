import csv, io, unittest;

glob HEADER: str = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline",
     CV: str = "cv/main_acme_data_scientist.tex",
     COVER: str = "cover_letters/cover_acme_data_scientist.tex",
     SUBJECT: str = "Re: Your application, Data Scientist - \"next steps\"";

def parse(notes: str) -> list[any] {
    row: str = f"2026-09-01,Acme,tech,Data Scientist,full_time,portal,applied,,8,{notes},{CV},{COVER},linkedin,2026-09-30";
    return list(csv.DictReader(io.StringIO(f"{HEADER}\n{row}\n")));
}

class TrackerNotesStayCsvSafe(unittest.TestCase) {
    def test_rule_is_stated_where_the_append_happens {
        cases: list[tuple[str, str, str, str]] = [
            (
                "gmail-sync",
                "### Step 7a: Write Approved Updates",
                "append to `notes`",
                "with every comma, double quote and line break deleted from the subject first",
            ),
            (
                "outcome",
                "## Step 4: Update the Tracker",
                "append a short dated note",
                "containing no commas, double quotes or line breaks",
            ),
        ];
        for (name, heading, anchor, rule) in cases {
            with self.subTest(command=name) {
                lines: list[str] = [
                    line
                    for line in under(command(name), heading).splitlines()
                    if anchor in line
                ];
                self.assertEqual(len(lines), 1, "expected one append instruction");
                self.assertIn(rule, lines[0]);
            }
        }
    }

    def test_sanitised_note_keeps_the_row_parseable {
        safe: str = SUBJECT.replace(",", "").replace("\"", "");
        rows: list[any] = parse(f"2026-09-12 gmail-sync: acknowledged (\"{safe}\")");
        self.assertEqual(len(rows), 1, "the note must not end the row early");
        self.assertIsNone(rows[0].get(None), "the row must be no wider than the header");
        self.assertEqual(
            [rows[0][column] for column in ("cv_file", "cover_letter_file", "source")],
            [CV, COVER, "linkedin"],
        );
    }

    def test_a_comma_in_the_note_shifts_the_columns {
        for note in (
            f"2026-09-12 gmail-sync: acknowledged (\"{SUBJECT}\")",
            "2026-09-12 rejected, no feedback given",
        ) {
            with self.subTest(note=note) {
                row: dict[any, any] = parse(note)[0];
                self.assertIsNotNone(row.get(None), "the comma must widen the row");
                self.assertNotEqual(row["cv_file"], CV);
                self.assertNotEqual(row["source"], "linkedin");
            }
        }
    }

    def test_a_line_break_in_the_note_splits_the_row_in_two {
        rows: list[any] = parse("2026-09-12 gmail-sync: acknowledged (\"Re: update\nlater\")");
        self.assertEqual(len(rows), 2);
        self.assertIsNone(rows[0]["cv_file"], "the first row ends mid-note");
    }
}
