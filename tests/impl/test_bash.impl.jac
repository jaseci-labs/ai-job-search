impl BashDiscoveryTests.test_working_path_shell_is_used -> any {
    run: any;
    with mock.patch.object(_bash, "WINDOWS", False), mock.patch.object(
        _bash.shutil, "which", return_value="/bin/bash"
    ), mock.patch.object(_bash.subprocess, "run", return_value=mock.Mock(returncode=0)) as run {
        self.assertEqual(_bash.find_bash(), "/bin/bash");
    }
    self.assertEqual(run.call_args.args[0], ["/bin/bash", "-c", "x=ok; test \"$x\" = ok"]);
}

impl BashDiscoveryTests.test_launcher_that_expands_variables_falls_back_to_git_bash -> any {
    git: any = Path(__file__).resolve().parent / "Git" / "cmd" / "git.exe";
    fallback: any = `str(git.parent.parent / "bin" / "bash.exe");

    def probe(args, **kwargs) -> any {
        script: any = args[2];
        if args[0] == "wsl-bash" {
            script = script.replace("$x", "");
        }
        return subprocess.CompletedProcess(
            args, 0 if script in ("exit 0", "x=ok; test \"$x\" = ok") else 1
        );
    }

    with mock.patch.object(_bash, "WINDOWS", True), mock.patch.object(
        _bash.shutil, "which", side_effect=["wsl-bash", `str(git)]
    ), mock.patch.object(_bash.subprocess, "run", side_effect=probe) {
        self.assertEqual(_bash.find_bash(), fallback);
    }
}

impl BashDiscoveryTests.test_missing_shell_needs_no_probe -> any {
    run: any;
    with mock.patch.object(_bash, "WINDOWS", False), mock.patch.object(
        _bash.shutil, "which", return_value=None
    ), mock.patch.object(_bash.subprocess, "run") as run {
        self.assertIsNone(_bash.find_bash());
    }
    run.assert_not_called();
}

impl BashDiscoveryTests.test_unusable_path_shell_falls_back_to_git_bash_on_windows -> any {
    git: any = Path(__file__).resolve().parent / "Git" / "cmd" / "git.exe";
    fallback: any = `str(git.parent.parent / "bin" / "bash.exe");
    run: any;
    with mock.patch.object(_bash, "WINDOWS", True), mock.patch.object(
        _bash.shutil, "which", side_effect=["wsl-bash", `str(git)]
    ), mock.patch.object(
        _bash.subprocess, "run", side_effect=[mock.Mock(returncode=1), mock.Mock(returncode=0)]
    ) as run {
        self.assertEqual(_bash.find_bash(), fallback);
    }
    self.assertEqual([call.args[0][0] for call in run.call_args_list], ["wsl-bash", fallback]);
}

impl BashDiscoveryTests.test_failed_or_hanging_shell_is_unavailable -> any {
    for error in (OSError("cannot start"), subprocess.TimeoutExpired("bash", 5)) {
        with self.subTest(error=`type(error).__name__), mock.patch.object(
            _bash, "WINDOWS", False
        ), mock.patch.object(_bash.shutil, "which", return_value="bash"), mock.patch.object(
            _bash.subprocess, "run", side_effect=error
        ) {
            self.assertIsNone(_bash.find_bash());
        }
    }
}

impl BashDiscoveryTests.test_nonzero_exit_without_a_fallback_is_unavailable -> any {
    with mock.patch.object(_bash, "WINDOWS", False), mock.patch.object(
        _bash.shutil, "which", return_value="bash"
    ), mock.patch.object(_bash.subprocess, "run", return_value=mock.Mock(returncode=1)) {
        self.assertIsNone(_bash.find_bash());
    }
}
