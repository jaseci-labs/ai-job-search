"""Pin the workflow settings zizmor checks, without needing zizmor or PyYAML.

- Every `actions/checkout` sets `persist-credentials: false`. Otherwise the job
  token stays in `.git/config` for every later step, including the CLI code a
  pull request brings (`artipacked`).
- A value a pull request controls never appears expanded inside a `run:`
  script (`template-injection`): `matrix.tool`, which `cli-checks` discovers
  from directory names, and the PR title, which `pr-title` checks.
"""

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

"""Column of a step's keys: two past the dash on a `- key:` line."""
def key_indent(line: builtins.str) -> builtins.int;

class WorkflowHardeningTests(unittest.TestCase) {
    def test_workflows_found -> any;

    def test_every_checkout_drops_its_credentials -> any;

    def test_pull_request_values_stay_out_of_run_scripts -> any;
}

with entry:__main__ {
    unittest.main();
}
