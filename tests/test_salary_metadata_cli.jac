import json;

import shutil;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

class SalaryMetadataCLI(unittest.TestCase) {
    def run_lookup(metadata, *args_) -> any;

    def test_preflight_rejects_a_text_baseline -> any;

    def test_lookup_rejects_a_text_baseline_without_a_traceback -> any;

    def test_preflight_rejects_a_non_text_index_label -> any;

    def test_preflight_rejects_unusable_numeric_baselines -> any;

    def test_numeric_baseline_and_optional_metadata_controls -> any;
}
