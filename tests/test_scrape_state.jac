"""The scrape helper filters before detail fetches and never rewrites old entries."""

import argparse;

import contextlib;

import io;

import json;

import sys;

import tempfile;

import unittest;

import from pathlib { Path }

glob ROOT: any;

with entry {
    ROOT = Path(__file__).resolve().parent.parent;
}

class ScrapeStateTests(unittest.TestCase) {
    def setUp -> any;

    def run_tool(command, jobs) -> any;

    def test_candidates_excludes_history_tracker_and_repeated_hits_before_detail -> any;

    def test_one_malformed_portal_hit_does_not_stop_other_candidates -> any;

    def test_unnamed_employer_is_a_posting_not_a_malformed_hit -> any;

    def test_store_adds_only_new_jobs_and_preserves_ranked_history -> any;

    def test_candidates_and_store_fold_hits_that_share_a_canonical_key -> any;

    def test_c_sharp_and_c_plus_plus_titles_are_different_postings -> any;

    def test_store_creates_missing_history_and_rejects_partial_entries_without_writing -> any;

    def test_history_counts_portal_and_legacy_host_without_emitting_entries -> any;
}

with entry:__main__ {
    unittest.main();
}
