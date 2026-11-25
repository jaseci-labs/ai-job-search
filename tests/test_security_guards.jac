import contextlib;
import io;
import json;
import shutil;
import subprocess;
import tempfile;
import unittest;
import from unittest { mock }
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parent.parent,
     FORK: str = "someone-else/ai-job-search",
     SETTINGS: str = ".claude/settings.json",
     GITIGNORE: str = ".gitignore",
     LOCAL: str = ".github/security-guards-local.txt",
     SKILL: str = ".claude/skills/example/SKILL.md",
     PORTAL: str = ".agents/skills/example-search/SKILL.md",
     COMMAND: str = ".claude/commands/example.md",
     AGENT: str = ".claude/agents/example.md",
     CLI_DIR: str = ".agents/skills/example-search/cli/",
     MANIFEST: str = CLI_DIR + "package.json",
     OWN_CLI: str = "Bash(bun run .agents/skills/example-search/cli/src/cli.ts",
     CORE_TOOLS: str = "Read, Glob, Grep, WebFetch, Edit, Write",
     PLAIN_COMMAND: str = "# /example - A command with no frontmatter\n",
     PASSES: list[str] = [],
     UNLISTED: str = "not in the reviewed allowlist",
     UNLISTED_NEGATION: str = "negation rule not in the reviewed allowlist";

def run_guards(base: Path, repository: str | None = None) -> subprocess.CompletedProcess;

def settings(
    allow: list[str] | None = None,
    ask: list[str] | None = None,
    deny: list[str] | None = None,
    permissions: dict[str, any] | None = None,
    top: dict[str, any] | None = None,
) -> str;

def hooks(commands: list[any], event: str = "SessionStart") -> str;

def ignore(extra: list[str] = [], swap: dict[str, str] = {}, drop: list[str] = []) -> str;

def manifest(**fields: any) -> str;

def skill(allowed_tools: str | list[str], extra: str = "") -> str;

def agent(tools: str | None = "Read, Grep, WebFetch, WebSearch, Bash", extra: str = "") -> str;

def tree -> dict[str, any];

class GuardRepoFixture(unittest.TestCase) {
    def setUp;
    def build(files: dict[str, any]) -> None;
    def expect(needles: list[str], repository: str | None = None) -> str;
    def check(cases: list[any], repository: str | None = None) -> None;
}

class SettingsGuardTests(GuardRepoFixture) {
    def test_clean_tree_passes;
    def test_guards_pass_on_this_repo;
    def test_allow_list_is_held_to_the_allowlist;
    def test_required_ask_and_deny_rules;
    def test_required_rules_are_the_shipped_shapes;
    def test_malformed_settings_shape_fails_cleanly;
    def test_unreviewed_settings_keys_fail;
    def test_hooks_outside_the_allowlist_fail;
    def test_unrecognised_hook_shapes_fail_closed;
    def test_absent_or_empty_hooks_pass;
    def test_allowlisted_hook_passes;
}

class FrontmatterGuardTests(GuardRepoFixture) {
    def test_skill_allowed_tools;
    def test_flow_list_allowed_tools_is_parsed;
    def test_skill_and_command_files;
    def test_agent_tools;
    def test_agent_permission_modes_hooks_and_servers;
}

class GitignoreGuardTests(GuardRepoFixture) {
    def test_required_rules_and_negations;
    def test_whitespace_is_read_as_git_reads_it;
    def test_subdirectory_gitignores;
    def test_local_negations;
    def test_local_negation_cannot_cancel_a_required_rule;
    def test_local_file_must_be_absent_on_upstream;
    def test_upstream_checkout_ships_no_local_file;
}

class GitignorePatternBehaviorTests(unittest.TestCase) {
    def setUp;
    def test_upskill_reports_ignored_at_depth_but_skill_md_stays_tracked;
    def test_interview_prep_pack_is_ignored_at_the_path_the_command_writes;
}

class ManifestGuardTests(GuardRepoFixture) {
    def test_install_time_code_execution_fails;
    def test_malformed_manifest_shape_fails_cleanly;
    def test_safe_manifests_pass;
    def test_tracked_node_modules;
}

with entry:__main__ {
    unittest.main();
}
