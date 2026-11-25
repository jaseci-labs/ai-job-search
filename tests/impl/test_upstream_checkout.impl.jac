impl _no_github_env(testcase) -> any {
    patcher: any = mock.patch.dict(os.environ);
    env: any = patcher.start();
    testcase.addCleanup(patcher.stop);
    env.pop("GITHUB_REPOSITORY", None);
    return env;
}

impl _completed(stdout="", returncode=0) -> any {
    return subprocess.CompletedProcess(
        args=["git", "remote", "get-url", "origin"], returncode=returncode, stdout=stdout
    );
}

impl UpstreamCheckoutTests.test_env_says_upstream -> any {
    with mock.patch.dict(os.environ, {"GITHUB_REPOSITORY": UPSTREAM}) {
        run: any;
        with mock.patch.object(_upstream.subprocess, "run") as run {
            self.assertTrue(is_upstream_checkout());
            run.assert_not_called();
        }
    }
}

impl UpstreamCheckoutTests.test_env_says_fork -> any {
    with mock.patch.dict(os.environ, {"GITHUB_REPOSITORY": "someone-else/ai-job-search"}) {
        run: any;
        with mock.patch.object(_upstream.subprocess, "run") as run {
            self.assertFalse(is_upstream_checkout());
            run.assert_not_called();
        }
    }
}

impl UpstreamCheckoutTests.test_no_env_and_origin_is_fork -> any {
    _no_github_env(self);
    with mock.patch.object(
        _upstream.subprocess,
        "run",
        return_value=_completed("git@github.com:someone-else/ai-job-search.git\n"),
    ) {
        self.assertFalse(is_upstream_checkout());
    }
}

impl UpstreamCheckoutTests.test_no_env_and_git_is_unavailable -> any {
    _no_github_env(self);
    with mock.patch.object(_upstream.subprocess, "run", side_effect=OSError("no git on PATH")) {
        self.assertTrue(is_upstream_checkout());
    }
}

impl UpstreamCheckoutTests.test_no_env_and_git_times_out -> any {
    _no_github_env(self);
    with mock.patch.object(
        _upstream.subprocess, "run", side_effect=subprocess.TimeoutExpired(cmd="git", timeout=10)
    ) {
        self.assertTrue(is_upstream_checkout());
    }
}

impl UpstreamCheckoutTests.test_no_env_and_git_exits_nonzero -> any {
    _no_github_env(self);
    with mock.patch.object(
        _upstream.subprocess, "run", return_value=_completed("", returncode=128)
    ) {
        self.assertTrue(is_upstream_checkout());
    }
}

impl UpstreamCheckoutTests.test_origin_url_forms -> any {
    cases: any = [
        ("https://github.com/ai-job-search-dev/ai-job-search", True),
        ("https://github.com/ai-job-search-dev/ai-job-search.git", True),
        ("git@github.com:ai-job-search-dev/ai-job-search", True),
        ("git@github.com:ai-job-search-dev/ai-job-search.git", True),
        ("ssh://git@github.com/ai-job-search-dev/ai-job-search.git", True),
        ("ssh://git@github.com/ai-job-search-dev/ai-job-search", True),
        ("ssh://git@github.com/someone-else/ai-job-search.git", False),
        ("https://github.com/someone-else/ai-job-search.git", False),
        ("git@github.com:someone-else/ai-job-search", False),
        ("https://gitlab.com/ai-job-search-dev/ai-job-search.git", False),
    ];
    for (url, expected) in cases {
        with self.subTest(url=url) {
            _no_github_env(self);
            with mock.patch.object(
                _upstream.subprocess, "run", return_value=_completed(url + "\n")
            ) {
                self.assertEqual(is_upstream_checkout(), expected);
            }
        }
    }
}
