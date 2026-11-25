impl UpstreamCheckerRepoFixture.setUp -> None {
    self.new_repo();
}

impl UpstreamCheckerRepoFixture.new_repo -> None {
    self.root = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, self.root, ignore_errors=True);
    root_at(self, self.root);
    for rel in FRAMEWORK_FILES {
        (self.root / rel).parent.mkdir(parents=True, exist_ok=True);
        (self.root / rel).write_text(FRONTMATTER, encoding="utf-8");
    }
    self.git("init", "-b", "master");
    self.git("config", "user.name", "Test");
    self.git("config", "user.email", "test@example.com");
    self.commit("init");
}

impl UpstreamCheckerRepoFixture.git(*args: str) -> subprocess.CompletedProcess {
    return subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True);
}

impl UpstreamCheckerRepoFixture.commit(message: str) -> None {
    self.git("add", "-A");
    self.git("commit", "-qm", message);
}

impl UpstreamCheckerRepoFixture.add_remote(name: str, url: str) -> None {
    self.git("remote", "add", name, url);
}

impl UpstreamCheckerRepoFixture.materialize_remote_ref(name: str) -> None {
    self.git("update-ref", f"refs/remotes/{name}/master", "HEAD");
}

impl UpstreamCheckerRepoFixture.with_remotes(urls: dict[str, str]) -> None {
    for (name, url) in urls.items() {
        self.add_remote(name, url);
    }
    self.materialize_remote_ref(list(urls)[-1]);
}

impl UpstreamCheckerRepoFixture.run_checker(
    *args: str, fetch: bool = False, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess {
    return subprocess.run(
        [*tool("check_upstream_updates"), *([] if fetch else ["--no-fetch"]), *args],
        cwd=self.root,
        env=env,
        capture_output=True,
        text=True,
        encoding="utf-8",
    );
}

impl UpstreamCheckerRepoFixture.check(
    result: subprocess.CompletedProcess, shows: list[str], lacks: list[str] = []
) -> str {
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
    for needle in shows {
        self.assertIn(needle, result.stdout);
    }
    for needle in lacks {
        self.assertNotIn(needle, result.stdout);
    }
    return result.stdout;
}

impl UpstreamCheckerTests.stale_upstream(message: str) -> None {
    self.commit(message);
    self.with_remotes({"origin": FORK_URL, "upstream": TEMPLATE_URL});
    (self.root / "AGENTS.md").write_text(FRONTMATTER, encoding="utf-8");
}

impl UpstreamCheckerTests.assert_incomplete -> None {
    self.check(self.run_checker(), ["AGENTS.md", "[WARNING] Framework check incomplete"], ["[OK]"]);
}

impl UpstreamCheckerTests.test_remote_fallback_and_fork_warning {
    current: str = "up to date with origin/master";
    fallback: list[str] = ["--remote", "upstream"];
    cases: list[tuple[str, dict[str, str], list[str], list[str], list[str]]] = [
        (
            "fork without upstream remote",
            {"origin": FORK_URL},
            fallback,
            [FALLBACK, NOT_TEMPLATE, current],
            ["up to date with upstream!"],
        ),
        (
            "clone of the template",
            {"origin": TEMPLATE_URL},
            fallback,
            [FALLBACK, current],
            [NOT_TEMPLATE],
        ),
        (
            "clone with lowercased template url",
            {"origin": TEMPLATE_URL.lower()},
            fallback,
            [FALLBACK, current],
            [NOT_TEMPLATE],
        ),
        (
            "explicit upstream remote",
            {"origin": FORK_URL, "upstream": TEMPLATE_URL},
            [],
            ["up to date with upstream/master"],
            [FALLBACK, NOT_TEMPLATE],
        ),
    ];
    for (label, urls, args, shows, lacks) in cases {
        with self.subTest(label) {
            self.new_repo();
            self.with_remotes(urls);
            self.check(self.run_checker(*args), shows, lacks);
        }
    }
}

impl UpstreamCheckerTests.test_cached_ref_after_failed_fetch_is_not_reported_as_current {
    self.with_remotes({"upstream": str(self.root / "unavailable-remote")});
    out = self.check(self.run_checker(fetch=True), ["Failed to fetch", "[WARNING]"], ["[OK]"]);
    self.assertIn("cached", out.lower());
}

impl UpstreamCheckerTests.test_file_missing_upstream_is_reported_instead_of_silent_ok {
    self.git("rm", "-q", "AGENTS.md");
    self.stale_upstream("drop AGENTS.md");
    self.assert_incomplete();
}

impl UpstreamCheckerTests.test_missing_local_file_does_not_report_all_files_up_to_date {
    self.with_remotes({"upstream": TEMPLATE_URL});
    (self.root / "AGENTS.md").unlink();
    self.assert_incomplete();
}

impl UpstreamCheckerTests.test_missing_upstream_marker_does_not_report_all_files_up_to_date {
    (self.root / "AGENTS.md").write_text(
        "# Upstream guidelines without a version marker\n", encoding="utf-8"
    );
    self.stale_upstream("remove upstream version marker");
    self.assert_incomplete();
}

impl UpstreamCheckerTests.test_output_is_utf8_under_a_legacy_locale {
    branch: str = "release-版本";
    for rel in FRAMEWORK_FILES {
        shutil.copy(REPO_ROOT / rel, self.root / rel);
    }
    self.commit("copy actual framework files");
    self.with_remotes({"upstream": TEMPLATE_URL});
    self.git("update-ref", f"refs/remotes/upstream/{branch}", "HEAD");
    cases: list[tuple[list[str], str, str]] = [
        ([], "0", "[OK]"),
        (["--branch", branch], "1", f"upstream/{branch}"),
    ];
    for (args, utf8_mode, needle) in cases {
        with self.subTest(needle) {
            env: dict[str, str] = os.environ | {
                "LC_ALL": "C",
                "LANG": "C",
                "PYTHONUTF8": utf8_mode,
                "PYTHONCOERCECLOCALE": "0",
                "PYTHONIOENCODING": "cp1252",
            };
            self.check(self.run_checker(*args, env=env), [needle]);
        }
    }
}
