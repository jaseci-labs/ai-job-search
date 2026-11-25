import builtins;

import re;

import subprocess;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob REPO: any;

glob RESET: any;

glob SETUP: any;

glob BASH: any;

glob SKILL_DIR: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    RESET = REPO / ".claude" / "commands" / "reset.md";
    SETUP = REPO / ".claude" / "commands" / "setup.md";
    BASH = find_bash();
}

def tracked_document_subfolders -> any;

class TestResetCoversEveryDocumentsSubfolder(unittest.TestCase) {
    def setUp -> any;

    def test_preview_lists_every_subfolder -> any;

    @unittest.skipUnless(BASH, "requires Bash to replay the documented /reset command")
    def test_delete_block_removes_every_subfolder -> any;
}

def section(text: builtins.str, start: builtins.str, end: builtins.str) -> builtins.str;

def setup_step3_skill_files -> any;

def setup_path_a_inference_rules -> any;

class TestResetCoversPathAInferredContent(unittest.TestCase) {
    def setUp -> any;

    def test_step1_reads_every_path_a_file -> any;

    def test_preview_lists_every_path_a_file -> any;

    def test_preserved_list_claims_no_path_a_file_is_framework_only -> any;

    def test_execution_removes_every_section_path_a_adds -> any;
}

class TestResetCoversEveryPersonalizedSkillFile(unittest.TestCase) {
    def setUp -> any;

    def test_preview_lists_every_personalized_skill_file -> any;

    def test_execution_clears_every_personalized_skill_file -> any;

    def test_preserved_list_claims_no_personalized_file_is_framework_only -> any;
}

with entry {
    SKILL_DIR = REPO / ".claude" / "skills" / "job-application-assistant";
}

def skeleton_step(reset_text, filename) -> any;

def skeleton_block(reset_text, filename) -> any;

def frontmatter(text) -> any;

def h2_headings(text) -> any;

def appear_in_order(needles, haystack) -> any;

class TestResetTargetsTheHeadingsTheShippedFilesHave(unittest.TestCase) {
    def setUp -> any;

    def test_full_file_skeletons_keep_the_shipped_headings -> any;

    def test_fork_heading_check_rejects_a_renamed_dropped_or_reordered_heading -> any;

    def test_full_file_skeletons_keep_the_framework_version_frontmatter -> any;

    def test_candidate_skeleton_keeps_the_languages_table_under_identity -> any;

    def test_partial_anchors_exist_in_the_files_they_target -> any;
}

with entry:__main__ {
    unittest.main();
}
