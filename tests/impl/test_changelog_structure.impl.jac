impl FrozenChangelogTests.test_changelog_is_unchanged {
    content: bytes = (REPO / "CHANGELOG.md").read_bytes().replace(b"\r\n", b"\n");
    self.assertEqual(
        hashlib.sha256(content).hexdigest(),
        "5a4f9ce8270ad872a3154fb872a7e287c27023d68a1b58c6415e2ec21b4b3815",
        "CHANGELOG.md is frozen at 1.7.4: describe the change in the PR title instead, or update this hash in the same PR for a deliberate fix",
    );
}
