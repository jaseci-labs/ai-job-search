"""The weekly release workflow can't run offline, so pin its safety properties.

The version itself comes from commitizen (`cz bump --get-next`, .cz.toml).
"""

import unittest;

import from pathlib { Path }

glob REPO: any;

glob WORKFLOW: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    WORKFLOW = REPO / ".github" / "workflows" / "release.yml";
}

class ReleaseWorkflowTests(unittest.TestCase) {
    def setUp -> any;

    def test_release_runs_only_on_upstream -> any;

    def test_write_access_is_granted_to_the_job_not_the_workflow -> any;

    def test_actions_are_sha_pinned -> any;
}

with entry:__main__ {
    unittest.main();
}
