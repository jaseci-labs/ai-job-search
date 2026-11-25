import builtins;

import unittest;

import from pathlib { Path }

glob UNTRUSTED: any = ("${{ matrix.tool }}", "${{ github.event.pull_request.title }}");

glob WORKFLOWS: any;

with entry {
    WORKFLOWS = sorted(
        (Path(__file__).resolve().parent.parent / ".github" / "workflows").glob("*.yml")
    );
}

def indent(line: builtins.str) -> builtins.int;

def key_indent(line: builtins.str) -> builtins.int;

class WorkflowHardeningTests(unittest.TestCase) {
    def test_workflows_found -> any;

    def test_every_checkout_drops_its_credentials -> any;

    def test_pull_request_values_stay_out_of_run_scripts -> any;
}

with entry:__main__ {
    unittest.main();
}
