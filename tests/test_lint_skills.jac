import builtins;

import json;

import shutil;

import subprocess;

import sys;

import tempfile;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
}

def run_linter(`root: Path) -> subprocess.CompletedProcess;

class LinterRepoFixture(unittest.TestCase) {
    def setUp -> any;

    def write_settings(data) -> any;
}

class SettingsShapeTests(LinterRepoFixture) {
    def test_valid_settings_pass -> any;

    def test_invalid_json_fails_cleanly -> any;

    def test_non_object_root_fails_cleanly -> any;

    def test_non_object_permissions_fails_cleanly -> any;

    def test_non_list_allow_fails_cleanly -> any;
}

"""check_skill()/check_command() are the linter's main job and were
    previously untested - only check_settings() had coverage, so deleting
    e.g. the missing-allowed-tools error survived the whole suite (review
    finding F23, 2026-08-19)."""
class SkillAndCommandCheckTests(LinterRepoFixture) {
    def write_skill(frontmatter: builtins.str) -> any;

    def test_allowed_tools_referencing_a_missing_file_fails -> any;

    def test_allowed_tools_referencing_an_existing_file_passes -> any;

    def test_frontmatter_missing_description_fails -> any;

    def test_command_without_slash_title_fails -> any;
}

with entry:__main__ {
    unittest.main();
}
