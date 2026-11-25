"""Replay /reset's actual Bash commands against isolated document files."""

import from jaclang.comptime { target as target_ }

import errno;

import os;

import re;

import shutil;

import subprocess;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob COMMAND: any;

glob FOLDERS: any;

glob BASH: any;

glob SHELLS: any;

glob SYMLINKS: any;

with entry {
    COMMAND = Path(__file__).resolve().parent.parent / ".claude/commands/reset.md";
    FOLDERS = ("cv", "linkedin", "diplomas", "references", "projects", "postings", "applications");
    BASH = find_bash();
    SHELLS = [
        path
        for path in (BASH, shutil.which("zsh"), shutil.which("sh"), shutil.which("dash"))
        if path
    ];
}

"""Probe only the filesystem capability needed by the scope controls."""
def symlinks_available -> any;

with entry {
    SYMLINKS = `bool(BASH) and symlinks_available();
}

@unittest.skipUnless(BASH, "requires Bash to replay the documented /reset command")
class ResetDocuments(unittest.TestCase) {
    def reset_script -> any;

    def run_reset(populated) -> any;

    def run_reset_with(shell, populated) -> any;

    def test_all_document_entries_are_removed_without_removing_the_scaffold -> any;

    def test_empty_document_folders_remain_usable -> any;

    def test_a_missing_folder_is_skipped_and_the_rest_are_still_cleared -> any;

    def test_block_uses_no_bash_only_builtins -> any;

    @unittest.skipUnless(SYMLINKS, "requires filesystem symlinks and Windows symlink privilege")
    def test_symlinked_roots_stop_before_any_deletion -> any;

    @unittest.skipUnless(SYMLINKS, "requires filesystem symlinks and Windows symlink privilege")
    def test_internal_symlink_is_removed_without_following_its_target -> any;
}
