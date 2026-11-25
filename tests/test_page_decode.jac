"""tools/page_decode.jac decodes a saved page by the charset it declares.

Why this test exists: fetch_page.jac saves bodies as the server sent them, and
posting_guard.jac --html and fetch_page.jac --text used to decode every file as
UTF-8 with replacement. A posting served in EUC-KR (job.incruit.com serves its
postings that way) reached the gate and the scorer as replacement characters.
These tests pin that declared legacy charsets are honoured, and that anything
which decoded cleanly before still decodes to exactly the same string.
"""

import builtins;

import sys;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
}

def page(body: builtins.str, head: builtins.str = "") -> builtins.str;

class LegacyCharsets(unittest.TestCase) {
    def test_http_equiv_euc_kr_is_read_as_cp949 -> any;

    def test_meta_charset_shift_jis -> any;

    def test_iso_8859_1_label_is_read_as_windows_1252 -> any;

    def test_windows_1251_cyrillic -> any;

    def test_utf16_byte_order_mark -> any;
}

class UnchangedBehaviour(unittest.TestCase) {
    def test_valid_utf8_is_unchanged -> any;

    def test_valid_utf8_wins_over_a_wrong_meta_label -> any;

    def test_utf8_bom_is_kept_for_the_invisible_character_count -> any;

    def test_undeclared_legacy_bytes_fall_back_to_utf8_with_replacement -> any;

    def test_unknown_and_unsafe_labels_are_ignored -> any;

    def test_meta_after_the_prescan_window_is_ignored -> any;
}

with entry:__main__ {
    unittest.main();
}
