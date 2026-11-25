import argparse;
import contextlib;
import io;
import json;
import tempfile;
import unittest;
import from pathlib { Path }

glob DETAILS: dict[str, any] = {
    "first_seen": "2026-10-21",
    "posted_date": None,
    "deadline": None,
    "fit": "high",
    "status": "new",
    "portal": "example-search",
    "source": "cli",
};

def hit(title: str, company: any, path: str, **more: any) -> dict[str, any];

class ScrapeStateTests(unittest.TestCase) {
    def setUp;
    def seed(seen: dict[str, any]) -> None;
    def stored -> dict[str, any];
    def call(**fields: any) -> any;
    def run_tool(command: str, jobs: list[any]) -> any;
    def test_candidates_excludes_history_tracker_and_repeated_hits_before_detail;
    def test_one_malformed_portal_hit_does_not_stop_other_candidates;
    def test_unnamed_employer_is_a_posting_not_a_malformed_hit;
    def test_store_adds_only_new_jobs_and_preserves_ranked_history;
    def test_candidates_and_store_fold_hits_that_share_a_canonical_key;
    def test_c_sharp_and_c_plus_plus_titles_are_different_postings;
    def test_store_creates_missing_history_and_rejects_partial_entries_without_writing;
    def test_history_counts_portal_and_legacy_host_without_emitting_entries;
}
