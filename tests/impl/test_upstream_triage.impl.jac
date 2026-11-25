impl TriageRepoFixture.setUp -> None {
    self.new_repo();
}

impl TriageRepoFixture.new_repo -> None {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);
    self.git("init", "-b", "master");
    self.git("config", "user.name", "Test");
    self.git("config", "user.email", "test@example.com");
    self.git("remote", "add", "upstream", f"https://github.com/{UPSTREAM_SLUG}.git");
    self.commit("init", {"shared.txt": "base\n", "kept.py": "print('hi')\n"});
}

impl TriageRepoFixture.git(*args: str) -> str {
    return subprocess.run(
        ["git", *args], cwd=self.root, check=True, capture_output=True, text=True
    ).stdout;
}

impl TriageRepoFixture.commit(msg: str, files: dict[str, str] = {}) -> str {
    for (rel, text) in files.items() {
        (self.root / rel).parent.mkdir(parents=True, exist_ok=True);
        (self.root / rel).write_text(text, encoding="utf-8");
    }
    self.git("add", "-A");
    self.git("commit", "-m", msg);
    return self.git("rev-parse", "HEAD").strip();
}

impl TriageRepoFixture.fork_point(back: int = 1) -> None {
    self.git("update-ref", "refs/remotes/upstream/master", "HEAD");
    self.git("reset", "--hard", f"HEAD~{back}");
}

impl TriageRepoFixture.triage(shows: list[str] = [], lacks: list[str] = []) -> str {
    result = subprocess.run(tool("upstream_triage"), cwd=self.root, capture_output=True, text=True);
    self.assertEqual(result.returncode, 0, result.stderr);
    for needle in shows {
        self.assertIn(needle, result.stdout);
    }
    for needle in lacks {
        self.assertNotIn(needle, result.stdout);
    }
    return result.stdout;
}

impl TriageTests.test_missing_ref_then_up_to_date {
    self.triage(["was not available"]);
    self.fork_point(0);
    self.triage(["Up to date"]);
}

impl TriageTests.test_relevance_filter {
    one: str = "**1** worth reviewing";
    cases: list[tuple[str, dict[str, str], dict[str, str], str
        | None, bool, list[str], list[str]]] = [
        (
            "only removed files",
            {"portals/removed_portal.py": "x = 1\n"},
            {"portals/removed_portal.py": "x = 2\n"},
            "portals/removed_portal.py",
            False,
            [NOT_IN_FORK, "Probably skip"],
            [],
        ),
        (
            "kept file",
            {},
            {"kept.py": "print('changed')\n"},
            None,
            True,
            ["Worth reviewing", "kept.py"],
            [],
        ),
        (
            "changelog-only footprint",
            {"portals/gone.py": "y = 1\n", "CHANGELOG.md": "- base\n"},
            {"portals/gone.py": "y = 2\n", "CHANGELOG.md": "- did a thing\n"},
            "portals/gone.py",
            False,
            [CHANGELOG_ONLY],
            [],
        ),
        ("new upstream tool", {}, NEW_TOOL, None, True, [one, "tools/new_workflow.py"], []),
        (
            "new file in removed directory",
            {"portals/gone/cli/src/cli.ts": "run()\n"},
            {"portals/gone/cli/tests/new.test.ts": "test()\n"},
            "portals/gone",
            False,
            ["**0** worth reviewing", NOT_IN_FORK],
            [],
        ),
        (
            "new directory inside kept directory",
            {"portals/kept/cli.ts": "run()\n"},
            {"portals/kept/tests/new/case.test.ts": "test()\n"},
            None,
            True,
            [one],
            [],
        ),
        (
            "new tool with changelog",
            {"CHANGELOG.md": "- base\n"},
            {**NEW_TOOL, "CHANGELOG.md": "- new workflow tool\n"},
            None,
            True,
            [one],
            [CHANGELOG_ONLY],
        ),
    ];
    for (label, shared, upstream, removed, reviewed, shows, lacks) in cases {
        with self.subTest(label) {
            self.new_repo();
            if shared {
                self.commit("shared: base", shared);
            }
            pick: str = "git cherry-pick " + self.commit("upstream: change", upstream);
            self.fork_point();
            if removed {
                self.git("rm", "-r", removed);
                self.commit("fork: remove demo portal");
            }
            before = self.git("status", "--porcelain");
            out = self.triage(shows, lacks);
            self.assertEqual(pick in out, reviewed, out);
            self.assertEqual(self.git("status", "--porcelain"), before);
            for (rel, text) in upstream.items() {
                path = self.root / rel;
                self.assertFalse(path.exists() and path.read_text(encoding="utf-8") == text);
            }
        }
    }
}

impl TriageTests.test_cherry_picked_commit_drops_off_via_patch_id {
    upstream_sha = self.commit("upstream: add feature", {"kept.py": "print('feature')\n"});
    self.commit("upstream: unrelated change", {"shared.txt": "upstream edit\n"});
    self.fork_point(2);
    self.commit("fork: divergent commit", {"fork_only.txt": "mine\n"});
    self.git("cherry-pick", upstream_sha);
    self.triage([APPLIED, "**1** worth reviewing"]);
}

impl TriageTests.test_different_patch_with_same_subject_requests_verification {
    upstream_sha = self.commit("Fix configuration", {"kept.py": "print('upstream fix')\n"});
    self.fork_point();
    fork_sha = self.commit("Fix configuration", {"shared.txt": "fork configuration\n"});
    self.triage(
        [
            "**0** worth reviewing",
            f"subject matches fork commit {fork_sha[:9]}, patch differs: verify",
        ],
        [f"git cherry-pick {upstream_sha}", APPLIED],
    );
}

impl TriageTests.test_conflict_resolved_personalized_port_has_distinct_verify_reason {
    profile: str = ".claude/skills/job-application-assistant/01-candidate-profile.md";
    self.commit("Add template profile", {profile: "Name: template\nGuidance: old\n"});
    upstream_sha = self.commit(
        "Improve profile guidance", {profile: "Name: template\nGuidance: improved\n"}
    );
    self.fork_point();
    self.commit("Personalize profile", {profile: "Name: personal\nGuidance: old\n"});
    with self.assertRaises(subprocess.CalledProcessError) {
        self.git("cherry-pick", upstream_sha);
    }
    (self.root / profile).write_text("Name: personal\nGuidance: improved\n", encoding="utf-8");
    self.git("add", profile);
    self.git("cherry-pick", "--continue");
    fork_sha = self.git("rev-parse", "HEAD").strip();
    self.triage(
        [
            "**0** worth reviewing",
            f"subject matches fork commit {fork_sha[:9]}, patch differs: verify",
        ],
        [APPLIED],
    );
}

impl TriageTests.test_same_patch_with_renamed_subject_is_still_already_applied {
    upstream_sha = self.commit("Fix configuration", {"kept.py": "print('upstream fix')\n"});
    self.fork_point();
    self.commit("Fork configuration", {"fork_only.txt": "fork\n"});
    self.git("cherry-pick", upstream_sha);
    self.git("commit", "--amend", "-m", "Port upstream configuration fix");
    self.triage(["**0** worth reviewing", APPLIED]);
}

impl TriageTests.test_suggested_commands_apply_dependent_changes_in_ancestry_order {
    final: str = "print('second upstream change')\n";
    first = self.commit(
        "Introduce shared behavior", {"kept.py": "print('first upstream change')\n"}
    );
    second = self.commit("Refine shared behavior", {"kept.py": final});
    self.fork_point(2);
    self.commit("Customize fork", {"fork_only.txt": "fork customization\n"});
    commands: list[list[str]] = [
        line.split("  #", 1)[0].split()
        for line in self.triage().splitlines()
        if line.startswith("git cherry-pick ")
    ];
    self.assertEqual([command[2] for command in commands], [first, second]);
    for command in commands {
        self.git(*command[1:]);
    }
    self.assertEqual((self.root / "kept.py").read_text(), final);
}

impl TriageTests.test_listed_sha_is_excluded {
    rejected = self.commit(
        "upstream: feature the fork rejects", {"kept.py": "print('rejected feature')\n"}
    );
    self.fork_point();
    self.commit(
        "fork: won't-port list",
        {".github/upstream-wontport.txt": f"{rejected[:9]}  # rejected on purpose\n"},
    );
    self.triage(["on the fork's won't-port list"]);
}

impl WorkflowGuardTests.test_workflow_is_fork_only_token_scoped_and_sha_pinned {
    text = WORKFLOW.read_text(encoding="utf-8");
    self.assertIn(f"github.repository != '{UPSTREAM_SLUG}'", text);
    self.assertIn("GH_TOKEN: ${{ github.token }}", text);
    self.assertNotIn("secrets.", text);
    for line in text.splitlines() {
        if line.strip().startswith(("- uses:", "uses:")) {
            ref: str = line.split("uses:", 1)[1].strip();
            self.assertIn("@", ref);
            self.assertRegex(
                ref.split("@", 1)[1].split()[0], "^[0-9a-f]{40}$", f"action not SHA-pinned: {ref}"
            );
        }
    }
}
