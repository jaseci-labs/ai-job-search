import re;
import shlex;
import subprocess;

glob REMOTE: str = "forks/template",
     BRANCHES: tuple[str, ...] = ("release/next", "release'next");

class CompanionRefTests(UpstreamCheckerRepoFixture) {
    def prepare(branch: str) -> list[str] {
        self.new_repo();
        self.add_remote(REMOTE, str(self.root));
        self.materialize_remote_ref(REMOTE);
        (self.root / "AGENTS.md").write_text(
            FRONTMATTER.replace("1.0.0", "2.0.0"), encoding="utf-8"
        );
        self.commit("update next-release methodology");
        self.git("branch", branch);
        self.git("update-ref", f"refs/remotes/{REMOTE}/{branch}", "HEAD");
        self.git("reset", "--hard", "HEAD~1");
        return ["--remote", REMOTE, "--branch", branch];
    }

    def run_tool(name: str, *args: str) -> str {
        result = subprocess.run(
            [*tool(name), *args], cwd=self.root, capture_output=True, text=True, encoding="utf-8"
        );
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
        return result.stdout;
    }

    def follow(command: str) -> str {
        words: list[str] = shlex.split(command);
        self.assertEqual(words[:4], ["neojac", "run", "jobsearch", "--"], command);
        return self.run_tool(*words[4:]);
    }

    def test_version_checker_companion_uses_selected_remote_and_branch {
        for branch in BRANCHES {
            with self.subTest(branch) {
                out = self.check(self.run_checker(*self.prepare(branch)), ["[UPDATE]"]);
                companion = self.follow(out.split("run: ", 1)[1].strip());
                self.assertIn(f"{REMOTE}/{branch}", companion);
                self.assertIn("**1** worth reviewing", companion);
            }
        }
    }

    def test_triage_companion_uses_selected_remote_and_branch {
        for branch in BRANCHES {
            with self.subTest(branch) {
                out = self.run_tool("upstream_triage", *self.prepare(branch));
                self.assertIn("**1** worth reviewing", out);
                companion = self.follow(
                    re.search(
                        "run `(neojac run jobsearch -- check_upstream_updates [^`]+)`", out
                    ).group(1),
                );
                self.assertIn(f"{REMOTE}/{branch}", companion);
                self.assertIn("[UPDATE]", companion);
            }
        }
    }
}
