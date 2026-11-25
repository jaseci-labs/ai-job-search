import os, shutil, subprocess, tempfile, unittest;
import from pathlib { Path, PureWindowsPath }
import from unittest { mock }

glob FRONTMATTER: str = "---\nframework_version: 1.0.0\n---\n",
     BODY: str = "# Test framework file\n\nOriginal guidance sentence.\n",
     PROFILE: str = ".claude/skills/job-application-assistant/01-test-profile.md";

class CheckerRepoFixture(unittest.TestCase) {
    def setUp -> None {
        self.root = Path(tempfile.mkdtemp());
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);
        root_at(self, self.root);
        self.framework_file = self.root / PROFILE;
        self.framework_file.parent.mkdir(parents=True);
        self.framework_file.write_text(FRONTMATTER + BODY, encoding="utf-8");
        identity: list[str] = ["-c", "user.name=test", "-c", "user.email=test@example.com"];
        for args in (["init", "-q"], ["add", "-A"], [*identity, "commit", "-q", "-m", "base"]) {
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True);
        }
    }

    def run_checker -> subprocess.CompletedProcess {
        env: dict[str, str] = {
            k: v
            for (k, v) in os.environ.items()
            if not k.startswith("GITHUB_")
        };
        return capture(tool("check_framework_version"), env=env);
    }
}

class FrameworkVersionGateTests(CheckerRepoFixture) {
    def test_edits_need_a_version_bump {
        quoted: str = FRONTMATTER.replace("1.0.0", "\"1.0.0\"");
        edited: str = BODY + "\nChanged guidance sentence.\n";
        cases: list[tuple[str, str, int]] = [
            ("clean tree", FRONTMATTER + BODY, 0),
            ("unbumped edit", FRONTMATTER + edited, 1),
            ("bumped edit", FRONTMATTER.replace("1.0.0", "1.0.1") + edited, 0),
            ("same version quoted", quoted + edited, 1),
            ("same version respaced", FRONTMATTER.replace(": 1", ":  1") + edited, 1),
            ("version reformatted alone", quoted + BODY, 0),
        ];
        for (label, text, returncode) in cases {
            with self.subTest(label) {
                self.framework_file.write_text(text, encoding="utf-8");
                result = self.run_checker();
                self.assertEqual(result.returncode, returncode, result.stdout + result.stderr);
                self.assertIn(
                    "modified without bumping 'framework_version'"
                        if returncode
                        else "Framework Version Check: OK",
                    result.stdout,
                );
            }
        }
    }

    def test_file_without_version_marker_fails {
        self.framework_file.with_name("02-unmarked.md").write_text(
            "# No frontmatter at all\n", encoding="utf-8"
        );
        result = self.run_checker();
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr);
        self.assertIn("missing 'framework_version'", result.stdout);
    }
}

class GitCallTests(unittest.TestCase) {
    def test_diff_and_show_use_posix_paths_for_windows_checkout {
        checkout = PureWindowsPath("C:/checkout");
        diff: str = "-framework_version: 1.0.0\n+framework_version: \"1.0.0\"\n-Old guidance\n+New guidance\n";
        with mock.patch.object(check_framework_version, "ROOT", checkout), mock.patch.object(
            check_framework_version,
            "run_git",
            side_effect=[(0, diff, ""), (0, FRONTMATTER + BODY, "")],
        ) as run_git, mock.patch.object(
            check_framework_version,
            "parse_frontmatter",
            return_value={"framework_version": "1.0.0"},
        ) {
            self.assertTrue(
                check_framework_version.has_non_trivial_changes(checkout / PROFILE, "base")
            );
        }
        self.assertEqual(
            run_git.call_args_list,
            [
                mock.call(["diff", "-U0", "base", "--", PROFILE]),
                mock.call(["show", f"base:{PROFILE}"]),
            ],
        );
    }

    def test_run_git_pins_utf8_encoding {
        with mock.patch.object(check_framework_version.subprocess, "run") as run {
            run.return_value = subprocess.CompletedProcess(
                args=["git"], returncode=0, stdout="", stderr=""
            );
            check_framework_version.run_git(["diff", "-U0", "HEAD"]);
        }
        self.assertEqual(run.call_args.kwargs.get("encoding"), "utf-8");
    }
}
