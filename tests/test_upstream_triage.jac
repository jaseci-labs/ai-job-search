import shutil, subprocess, tempfile, unittest;
import from pathlib { Path }

glob WORKFLOW: Path = Path(__file__).resolve().parent.parent
         / ".github/workflows/upstream-watch.yml",
     UPSTREAM_SLUG: str = "ai-job-search-dev/ai-job-search",
     NOT_IN_FORK: str = "touches only files not in this fork",
     CHANGELOG_ONLY: str = "changelog-only footprint in this fork",
     APPLIED: str = "already applied (cherry-picked)",
     PORTAL: str = "portals/gone.py",
     LOG: str = "CHANGELOG.md",
     NEW_TOOL: dict[str, str] = {"tools/new_workflow.py": "print('new workflow')\n"};

class TriageRepoFixture(unittest.TestCase) {
    def setUp -> None {
        self.new_repo();
    }

    def new_repo -> None {
        self.root = Path(tempfile.mkdtemp());
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);
        self.git("init", "-b", "master");
        self.git("config", "user.name", "Test");
        self.git("config", "user.email", "test@example.com");
        self.git("remote", "add", "upstream", f"https://github.com/{UPSTREAM_SLUG}.git");
        self.commit("init", {"shared.txt": "base\n", "kept.py": "print('hi')\n"});
    }

    def git(*args: str) -> str {
        return capture(["git", *args], cwd=self.root, check=True).stdout;
    }

    def commit(msg: str, files: dict[str, str] = {}) -> str {
        for (rel, text) in files.items() {
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True);
            (self.root / rel).write_text(text, encoding="utf-8");
        }
        self.git("add", "-A");
        self.git("commit", "-m", msg);
        return self.git("rev-parse", "HEAD").strip();
    }

    def fork_point(back: int = 1) -> None {
        self.git("update-ref", "refs/remotes/upstream/master", "HEAD");
        self.git("reset", "--hard", f"HEAD~{back}");
    }

    def triage(shows: list[str] = [], lacks: list[str] = []) -> str {
        result = capture(tool("upstream_triage"), cwd=self.root);
        self.assertEqual(result.returncode, 0, result.stderr);
        for needle in shows {
            self.assertIn(needle, result.stdout);
        }
        for needle in lacks {
            self.assertNotIn(needle, result.stdout);
        }
        return result.stdout;
    }
}

class TriageTests(TriageRepoFixture) {
    def test_missing_ref_then_up_to_date {
        self.triage(["was not available"]);
        self.fork_point(0);
        self.triage(["Up to date"]);
    }

    def test_relevance_filter {
        cases: list[tuple[str, dict[str, str], dict[str, str], str | None, str | None]] = [
            ("only removed files", {PORTAL: "1\n"}, {PORTAL: "2\n"}, PORTAL, NOT_IN_FORK),
            ("kept file", {}, {"kept.py": "print('changed')\n"}, None, None),
            (
                "changelog only",
                {PORTAL: "1\n", LOG: "- a\n"},
                {PORTAL: "2\n", LOG: "- b\n"},
                PORTAL,
                CHANGELOG_ONLY,
            ),
            ("new upstream tool", {}, NEW_TOOL, None, None),
            (
                "new file in removed dir",
                {"gone/src/cli.ts": "a\n"},
                {"gone/tests/t.ts": "b\n"},
                "gone",
                NOT_IN_FORK,
            ),
            (
                "new dir in kept dir",
                {"kept/cli.ts": "a\n"},
                {"kept/tests/new/t.ts": "b\n"},
                None,
                None,
            ),
            ("new tool with changelog", {LOG: "- a\n"}, {**NEW_TOOL, LOG: "- b\n"}, None, None),
        ];
        for (label, shared, upstream, removed, why) in cases {
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
                if why {
                    self.triage(["**0** worth reviewing", "Probably skip", why], [pick]);
                } else {
                    self.triage(
                        ["**1** worth reviewing", pick, *[rel for rel in upstream if rel != LOG]],
                        [NOT_IN_FORK, CHANGELOG_ONLY],
                    );
                }
                self.assertEqual(self.git("status", "--porcelain"), before);
                for (rel, text) in upstream.items() {
                    path = self.root / rel;
                    self.assertFalse(path.exists() and path.read_text(encoding="utf-8") == text);
                }
            }
        }
    }

    def test_cherry_picked_commit_drops_off_via_patch_id {
        upstream_sha = self.commit("upstream: add feature", {"kept.py": "print('feature')\n"});
        self.commit("upstream: unrelated change", {"shared.txt": "upstream edit\n"});
        self.fork_point(2);
        self.commit("fork: divergent commit", {"fork_only.txt": "mine\n"});
        self.git("cherry-pick", upstream_sha);
        self.triage([APPLIED, "**1** worth reviewing"]);
    }

    def test_different_patch_with_same_subject_requests_verification {
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

    def test_conflict_resolved_personalized_port_has_distinct_verify_reason {
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

    def test_same_patch_with_renamed_subject_is_still_already_applied {
        upstream_sha = self.commit("Fix configuration", {"kept.py": "print('upstream fix')\n"});
        self.fork_point();
        self.commit("Fork configuration", {"fork_only.txt": "fork\n"});
        self.git("cherry-pick", upstream_sha);
        self.git("commit", "--amend", "-m", "Port upstream configuration fix");
        self.triage(["**0** worth reviewing", APPLIED]);
    }

    def test_suggested_commands_apply_dependent_changes_in_ancestry_order {
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

    def test_listed_sha_is_excluded {
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
}

class WorkflowGuardTests(unittest.TestCase) {
    def test_workflow_is_fork_only_token_scoped_and_sha_pinned {
        text = WORKFLOW.read_text(encoding="utf-8");
        self.assertIn(f"github.repository != '{UPSTREAM_SLUG}'", text);
        self.assertIn("GH_TOKEN: ${{ github.token }}", text);
        self.assertNotIn("secrets.", text);
        for line in text.splitlines() {
            if line.strip().startswith(("- uses:", "uses:")) {
                ref: str = line.split("uses:", 1)[1].strip();
                self.assertIn("@", ref);
                self.assertRegex(
                    ref.split("@", 1)[1].split()[0],
                    "^[0-9a-f]{40}$",
                    f"action not SHA-pinned: {ref}",
                );
            }
        }
    }
}
