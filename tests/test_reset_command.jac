import re;
import subprocess;
import unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob BASH: str | None = find_bash(),
     FULL_FILES: tuple[str, str] = ("01-candidate-profile.md", "02-behavioral-profile.md"),
     PROFILE_PREVIEW: tuple[str, str] = (
         "### If scope includes `profile`:",
         "### If scope includes `documents`:",
     ),
     PRESERVED: tuple[str, str] = ("The following files are NOT touched", "```"),
     EXECUTION: tuple[str, str] = ("### Profile reset", "### Documents reset");

def tracked_document_subfolders -> set[str];

def setup_step3_skill_files -> set[str];

def setup_path_a_inference_rules -> list[tuple[str, list[str]]];

def skeleton_step(reset_text: str, filename: str) -> tuple[str, str];

def frontmatter(text: str) -> str;

def appear_in_order(needles: list[str], haystack: list[str]) -> bool;

class TestResetCoversEveryDocumentsSubfolder(unittest.TestCase) {
    def setUp;
    def test_preview_lists_every_subfolder;

    @unittest.skipUnless(BASH, "requires Bash to replay the documented /reset command")
    def test_delete_block_removes_every_subfolder;
}

class TestResetCoversWhatSetupWrites(unittest.TestCase) {
    def setUp;
    def test_setup_targets_are_found;
    def test_every_setup_target_is_read_previewed_and_cleared;
    def test_execution_removes_every_section_path_a_adds;
}

class TestResetTargetsTheHeadingsTheShippedFilesHave(unittest.TestCase) {
    def setUp;
    def test_full_file_skeletons_keep_the_shipped_headings;
    def test_fork_heading_check_rejects_a_renamed_dropped_or_reordered_heading;
    def test_full_file_skeletons_keep_the_framework_version_frontmatter;
    def test_candidate_skeleton_keeps_the_languages_table_under_identity;
    def test_partial_anchors_exist_in_the_files_they_target;
}
