impl completed(stdout: str = "", returncode: int = 0) -> subprocess.CompletedProcess {
    return subprocess.CompletedProcess(
        args=["git", "remote", "get-url", "origin"], returncode=returncode, stdout=stdout
    );
}

impl UpstreamCheckoutTests.test_github_repository_decides_without_asking_git {
    for (repository, expected) in [(UPSTREAM, True), ("someone-else/ai-job-search", False)] {
        with self.subTest(repository), mock.patch.dict(
            os.environ, {"GITHUB_REPOSITORY": repository}
        ), mock.patch.object(_upstream.subprocess, "run") as run {
            self.assertEqual(is_upstream_checkout(), expected);
            run.assert_not_called();
        }
    }
}

impl UpstreamCheckoutTests.test_origin_decides_when_no_env_and_unknown_means_upstream {
    cases: list[tuple[any, bool]] = [
        (OSError("no git on PATH"), True),
        (subprocess.TimeoutExpired(cmd="git", timeout=10), True),
        (completed("", returncode=128), True),
        *[(completed(url + "\n"), expected) for (url, expected) in ORIGIN_URLS.items()],
    ];
    with mock.patch.dict(os.environ) {
        os.environ.pop("GITHUB_REPOSITORY", None);
        for (outcome, expected) in cases {
            with self.subTest(str(outcome)), mock.patch.object(
                _upstream.subprocess, "run", side_effect=[outcome]
            ) {
                self.assertEqual(is_upstream_checkout(), expected);
            }
        }
    }
}
