impl FrozenChangelogTests.test_changelog_is_unchanged -> any {
    content: any = CHANGELOG.read_bytes().replace(b"\r\n", b"\n");
    self.assertEqual(
        hashlib.sha256(content).hexdigest(),
        FROZEN_SHA256,
        "CHANGELOG.md is frozen at 1.7.4: drop your edit and describe the change in the PR title instead (release notes are generated from PR titles). A deliberate fix to the frozen text updates FROZEN_SHA256 in the same PR.",
    );
}
