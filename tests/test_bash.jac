import subprocess;
import unittest;
import from pathlib { Path }
import from unittest { mock }

glob PROBE: list[str] = ["-c", "x=ok; test \"$x\" = ok"],
     GIT: Path = Path(__file__).resolve().parent / "Git" / "cmd" / "git.exe",
     GIT_BASH: str = str(GIT.parent.parent / "bin" / "bash.exe");

def launcher_dropping_variables(args: list[str], **kwargs: any) -> subprocess.CompletedProcess;

class BashDiscoveryTests(unittest.TestCase) {
    def test_find_bash;
}
