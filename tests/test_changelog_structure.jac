import hashlib;
import unittest;

@unittest.skipIf(
    not is_upstream_checkout(), "the freeze guards the upstream changelog; forks may keep their own"
)
class FrozenChangelogTests(unittest.TestCase) {
    def test_changelog_is_unchanged;
}
