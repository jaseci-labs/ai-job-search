import subprocess;
import unittest;
import from pathlib { Path }
import from unittest { mock }

glob PROBE: list[str] = ["-c", "x=ok; test \"$x\" = ok"],
     GIT: Path = Path(__file__).resolve().parent / "Git" / "cmd" / "git.exe",
     GIT_BASH: str = str(GIT.parent.parent / "bin" / "bash.exe");

def launcher_dropping_variables(args: list[str], **kwargs: any) -> subprocess.CompletedProcess {
    script: str = args[2].replace("$x", "") if args[0] == "wsl-bash" else args[2];
    return subprocess.CompletedProcess(args, 0 if script in ("exit 0", PROBE[1]) else 1);
}

class BashDiscoveryTests(unittest.TestCase) {
    def test_find_bash {
        (ok, failed) = (mock.Mock(returncode=0), mock.Mock(returncode=1));
        on_windows: list[str] = ["wsl-bash", str(GIT)];
        cases: list[tuple[str, bool, list[str | None], any, str | None, list[str]]] = [
            ("working PATH shell", False, ["/bin/bash"], [ok], "/bin/bash", ["/bin/bash"]),
            ("no shell on PATH", False, [None], [], None, []),
            (
                "launcher that expands variables itself",
                True,
                on_windows,
                launcher_dropping_variables,
                GIT_BASH,
                ["wsl-bash", GIT_BASH],
            ),
            (
                "unusable PATH shell on Windows",
                True,
                on_windows,
                [failed, ok],
                GIT_BASH,
                ["wsl-bash", GIT_BASH],
            ),
            ("shell that cannot start", False, ["bash"], OSError("cannot start"), None, ["bash"]),
            (
                "hanging shell",
                False,
                ["bash"],
                subprocess.TimeoutExpired("bash", 5),
                None,
                ["bash"],
            ),
            ("nonzero exit without a fallback", False, ["bash"], [failed], None, ["bash"]),
        ];
        for (label, windows, found, outcome, expected, probed) in cases {
            with self.subTest(label), mock.patch.object(
                _bash, "WINDOWS", windows
            ), mock.patch.object(_bash.shutil, "which", side_effect=found), mock.patch.object(
                _bash.subprocess, "run", side_effect=outcome
            ) as run {
                self.assertEqual(_bash.find_bash(), expected);
                self.assertEqual(
                    [call.args[0] for call in run.call_args_list],
                    [[shell, *PROBE] for shell in probed],
                );
            }
        }
    }
}
