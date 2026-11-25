import unittest;
import from pathlib { Path }

glob UNTRUSTED: tuple[str, ...] = ("${{ matrix.tool }}", "${{ github.event.pull_request.title }}"),
     WORKFLOWS: list[Path] = sorted(
         (Path(__file__).resolve().parent.parent / ".github" / "workflows").glob("*.yml")
     );

def indent(line: str) -> int;

def key_indent(line: str) -> int;

class WorkflowHardeningTests(unittest.TestCase) {
    def test_workflows_found;
    def test_every_checkout_drops_its_credentials;
    def test_pull_request_values_stay_out_of_run_scripts;
}

with entry:__main__ {
    unittest.main();
}
