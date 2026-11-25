import json;

import shutil;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

class UnicodeSalaryCLI(unittest.TestCase) {
    def setUp -> any;

    def lookup(query) -> any;

    def test_exact_non_latin_company_can_be_found -> any;

    def test_mixed_script_companies_do_not_collapse_to_a_latin_fragment -> any;

    def test_canonically_equivalent_spelling_finds_the_same_company -> any;

    def test_ascii_control_still_matches -> any;

    def test_ascii_query_finds_accented_company -> any;

    def test_nordic_spelling_variants_survive_accent_folding -> any;

    def test_official_ascii_and_native_nordic_company_spellings_match -> any;

    def test_native_nordic_query_finds_ascii_company_data -> any;
}
