import csv;
import io;
import unittest;

glob HEADER: str = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline",
     CV: str = "cv/main_acme_data_scientist.tex",
     COVER: str = "cover_letters/cover_acme_data_scientist.tex",
     SUBJECT: str = "Re: Your application, Data Scientist - \"next steps\"";

def parse(notes: str) -> list[any];

class TrackerNotesStayCsvSafe(unittest.TestCase) {
    def test_rule_is_stated_where_the_append_happens;
    def test_sanitised_note_keeps_the_row_parseable;
    def test_a_comma_in_the_note_shifts_the_columns;
    def test_a_line_break_in_the_note_splits_the_row_in_two;
}
