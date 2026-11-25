impl section(path, heading) -> any {
    text: any = path.read_text(encoding="utf-8");
    start: any = text.index(heading) + len(heading);
    rest: any = text[start:];
    end: any = re.search("^#{1,4} ", rest, re.MULTILINE);
    return rest[:end.start()] if end else rest;
}

impl FreeFormNotesWritersStateTheRule.test_rule_is_stated_where_the_append_happens -> any {
    for (path, heading, anchor, rule, why) in self.CASES {
        with self.subTest(path=path.name, heading=heading) {
            lines: any = [l for l in section(path, heading).splitlines() if anchor in l];
            self.assertEqual(len(lines), 1, f"expected one append instruction: {why}");
            self.assertIn(rule, lines[0], why);
        }
    }
}

impl NotesShapeUnderTheShippedReader.test_sanitised_note_keeps_the_row_parseable -> any {
    safe: any = self.SUBJECT.replace(",", "").replace("\"", "");
    rows: any = self._parse(f"2026-09-12 gmail-sync: acknowledged (\"{safe}\")");

    self.assertEqual(len(rows), 1, "the note must not end the row early");
    row: any = rows[0];
    self.assertIsNone(row.get(None), "the row must be no wider than the header");
    self.assertEqual(row["cv_file"], "cv/main_acme_data_scientist.tex");
    self.assertEqual(row["cover_letter_file"], "cover_letters/cover_acme_data_scientist.tex");
    self.assertEqual(row["source"], "linkedin");
}

impl NotesShapeUnderTheShippedReader.test_a_comma_in_the_note_shifts_the_columns -> any {
    for note in (
        f"2026-09-12 gmail-sync: acknowledged (\"{self.SUBJECT}\")",
        "2026-09-12 rejected, no feedback given",
    ) {
        with self.subTest(note=note) {
            row: any = self._parse(note)[0];
            self.assertIsNotNone(row.get(None), "the comma must widen the row");
            self.assertNotEqual(row["cv_file"], "cv/main_acme_data_scientist.tex");
            self.assertNotEqual(row["source"], "linkedin");
        }
    }
}

impl NotesShapeUnderTheShippedReader.test_a_line_break_in_the_note_splits_the_row_in_two -> any {
    rows: any = self._parse("2026-09-12 gmail-sync: acknowledged (\"Re: update\nlater\")");
    self.assertEqual(len(rows), 2);
    self.assertIsNone(rows[0]["cv_file"], "the first row ends mid-note");
}

impl NotesShapeUnderTheShippedReader._parse(notes) -> any {
    stream: any = io.StringIO(TRACKER_HEADER + "\n" + cls._row(notes) + "\n");
    return `list(csv.DictReader(stream));
}

impl NotesShapeUnderTheShippedReader._row(notes) -> any {
    return ",".join([
        "2026-09-01",
        "Acme",
        "tech",
        "Data Scientist",
        "full_time",
        "portal",
        "applied",
        "",
        "8",
        notes,
        "cv/main_acme_data_scientist.tex",
        "cover_letters/cover_acme_data_scientist.tex",
        "linkedin",
        "2026-09-30",
    ]);
}
