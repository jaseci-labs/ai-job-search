import json;

import from pathlib { Path }

import shutil;

import subprocess;

import sys;

import from tempfile { TemporaryDirectory }

import unittest;

glob openpyxl: any;

glob REPO: any;

glob NOTES: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }

    REPO = Path(__file__).resolve().parent.parent;

    NOTES = [
        ["About this data"],
        ["Each row is one company in the 2025 survey."],
        ["Indexes are relative to the national median."],
        ["Categories with fewer than five respondents are suppressed."],
    ];
}

@unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
class NotesSheetCLI(unittest.TestCase) {
    def setUp -> any;

    def convert(with_data) -> any;

    def test_notes_tab_sentences_are_not_listed_as_companies -> any;

    def test_notes_only_workbook_fails_without_writing_output -> any;
}

with entry:__main__ {
    unittest.main();
}
