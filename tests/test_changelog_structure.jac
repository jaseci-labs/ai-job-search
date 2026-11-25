"""CHANGELOG.md is frozen at 1.7.4; releases after it are documented in GitHub Releases.

Every PR used to add an entry under `## [Unreleased]`, and PRs opened before the
freeze still carry one. Most of those entries sit mid-section, so git merges
them cleanly into the frozen 1.7.4 section - a heading check would not notice.
Pinning the file's content does: any edit fails here and points the author at
the PR title, which is what the release notes are generated from.
"""

import hashlib;

import unittest;

import from pathlib { Path }

glob CHANGELOG: any;

glob FROZEN_SHA256: any;

with entry {
    CHANGELOG = Path(__file__).resolve().parent.parent / "CHANGELOG.md";
    FROZEN_SHA256 = "5a4f9ce8270ad872a3154fb872a7e287c27023d68a1b58c6415e2ec21b4b3815";
}

@unittest.skipIf(
    not is_upstream_checkout(), "the freeze guards the upstream changelog; forks may keep their own"
)
class FrozenChangelogTests(unittest.TestCase) {
    def test_changelog_is_unchanged -> any;
}

with entry:__main__ {
    unittest.main();
}
