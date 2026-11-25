import shutil;
import subprocess;
import tempfile;
import unittest;
import from pathlib { Path }

glob WORKFLOW: Path = Path(__file__).resolve().parent.parent
         / ".github/workflows/upstream-watch.yml",
     UPSTREAM_SLUG: str = "ai-job-search-dev/ai-job-search",
     NOT_IN_FORK: str = "touches only files not in this fork",
     CHANGELOG_ONLY: str = "changelog-only footprint in this fork",
     APPLIED: str = "already applied (cherry-picked)",
     NEW_TOOL: dict[str, str] = {"tools/new_workflow.py": "print('new workflow')\n"};

class TriageRepoFixture(unittest.TestCase) {
    def setUp -> None;
    def new_repo -> None;
    def git(*args: str) -> str;
    def commit(msg: str, files: dict[str, str] = {}) -> str;
    def fork_point(back: int = 1) -> None;
    def triage(shows: list[str] = [], lacks: list[str] = []) -> str;
}

class TriageTests(TriageRepoFixture) {
    def test_missing_ref_then_up_to_date;
    def test_relevance_filter;
    def test_cherry_picked_commit_drops_off_via_patch_id;
    def test_different_patch_with_same_subject_requests_verification;
    def test_conflict_resolved_personalized_port_has_distinct_verify_reason;
    def test_same_patch_with_renamed_subject_is_still_already_applied;
    def test_suggested_commands_apply_dependent_changes_in_ancestry_order;
    def test_listed_sha_is_excluded;
}

class WorkflowGuardTests(unittest.TestCase) {
    def test_workflow_is_fork_only_token_scoped_and_sha_pinned;
}
