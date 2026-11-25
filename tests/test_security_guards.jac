import operator;

import contextlib;

import io;

import json;

import os;

import shutil;

import subprocess;

import sys;

import tempfile;

import unittest;

import from unittest { mock }

import from pathlib { Path }

glob REPO_ROOT: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;
}

def run_guards(`root: Path, repository=None) -> subprocess.CompletedProcess;

class GuardRepoFixture(unittest.TestCase) {
    def setUp -> any;

    def write_agent(tools, path=None, omit_tools=False) -> any;

    def write_skill(path, allowed_tools, extra_frontmatter="") -> any;

    def write_settings(allow, ask=None, deny=None) -> any;

    def write_gitignore(rules) -> any;

    def write_manifest(data, path=None) -> any;
}

class CleanTreeTests(GuardRepoFixture) {
    def test_clean_tree_passes -> any;
}

class PermissionGuardTests(GuardRepoFixture) {
    def test_wildcard_bash_permission_fails -> any;

    def test_network_fetch_permission_fails -> any;

    def test_dropped_allowlisted_permission_still_passes -> any;

    def test_invalid_settings_json_fails -> any;

    def test_malformed_settings_shape_fails_cleanly -> any;
}

class AskDenyRuleTests(GuardRepoFixture) {
    def test_missing_required_deny_rule_fails -> any;

    def test_missing_required_ask_rule_fails -> any;

    def test_extra_deny_and_ask_rules_pass -> any;

    def test_required_rules_are_the_shipped_shapes -> any;

    def test_malformed_ask_or_deny_shape_fails_cleanly -> any;
}

class SkillGrantGuardTests(GuardRepoFixture) {
    def test_bare_bash_in_skill_fails -> any;

    def test_glob_cli_grant_in_skill_fails -> any;

    def test_portal_skill_may_grant_only_its_own_cli -> any;

    def test_portal_skill_may_not_grant_core_tools -> any;

    def test_bom_prefixed_frontmatter_is_parsed -> any;

    def test_non_utf8_skill_fails_cleanly -> any;

    def test_flow_list_allowed_tools_is_parsed -> any;

    def test_core_skill_may_not_grant_a_portal_cli -> any;

    def test_command_frontmatter_is_checked -> any;

    def test_nested_command_frontmatter_is_checked -> any;

    def test_nested_command_without_frontmatter_passes -> any;

    def test_command_without_frontmatter_passes -> any;

    def test_list_form_allowed_tools_is_parsed -> any;

    def test_folded_description_does_not_confuse_parser -> any;

    def test_entry_with_mid_pattern_wildcard_fails -> any;

    def test_allowlisted_shipped_entries_pass -> any;

    def test_skill_without_frontmatter_fails_cleanly -> any;

    def test_skill_hooks_frontmatter_fails -> any;

    def test_dynamic_context_line_fails_in_skills_and_commands -> any;

    def test_inline_code_and_exclamation_marks_pass -> any;
}

class AgentGrantGuardTests(GuardRepoFixture) {
    def test_agent_without_tools_key_fails -> any;

    def test_agent_with_empty_tools_value_fails -> any;

    def test_agent_with_edit_or_write_fails -> any;

    def test_agent_with_bash_pattern_fails -> any;

    def test_nested_agent_is_checked -> any;

    def test_allowlisted_agent_passes -> any;

    def test_agent_frontmatter_missing_fails_cleanly -> any;

    def test_no_agents_directory_passes -> any;

    def write_agent_with(extra) -> any;

    def test_agent_permission_mode_that_removes_prompts_fails -> any;

    def test_agent_permission_mode_that_still_prompts_passes -> any;

    def test_agent_hooks_and_mcp_servers_fail -> any;
}

class HookGuardTests(GuardRepoFixture) {
    def write_settings_with_hooks(hooks) -> any;

    def test_session_start_hook_fails -> any;

    def test_hook_is_caught_even_when_permissions_block_is_malformed -> any;

    def test_every_hook_event_is_checked -> any;

    def test_every_command_in_a_multi_hook_event_is_reported -> any;

    def test_unrecognised_hook_shapes_fail_closed -> any;

    def test_non_object_hooks_value_fails_cleanly -> any;

    def test_absent_or_empty_hooks_pass -> any;

    def test_allowlisted_hook_passes -> any;
}

class GitignoreGuardTests(GuardRepoFixture) {
    def test_each_missing_personal_data_rule_fails -> any;

    def test_extra_rules_are_allowed -> any;

    def test_generated_report_rules_are_required -> any;
}

class GitignorePatternBehaviorTests(unittest.TestCase) {
    def setUp -> any;

    def test_upskill_reports_ignored_at_depth_but_skill_md_stays_tracked -> any;

    def test_interview_prep_pack_is_ignored_at_the_path_the_command_writes -> any;
}

class GitignoreNegationTests(GuardRepoFixture) {
    def test_negation_reincluding_personal_data_fails -> any;

    def test_allowlisted_negations_pass -> any;
}

class GitignoreWhitespaceTests(GuardRepoFixture) {
    def test_rule_with_leading_whitespace_fails -> any;

    def test_rule_with_a_leading_tab_fails -> any;

    def test_trailing_whitespace_is_ignored_like_git_ignores_it -> any;

    def test_negation_with_leading_whitespace_is_still_a_negation -> any;
}

class SubdirectoryGitignoreTests(GuardRepoFixture) {
    def test_subdirectory_gitignore_negation_fails -> any;

    def test_subdirectory_gitignore_without_negation_passes -> any;

    def test_root_allowlist_does_not_cover_a_subdirectory_negation -> any;

    def test_gitignore_inside_node_modules_or_git_is_not_read -> any;
}

class SettingsKeyAllowlistTests(GuardRepoFixture) {
    def _settings_with(top=None, permissions=None) -> any;

    def test_unrecognised_top_level_setting_fails -> any;

    def test_unrecognised_permissions_setting_fails -> any;

    def test_shipped_keys_pass -> any;
}

class LocalNegationsTests(GuardRepoFixture) {
    static has FORK: any = "someone-else/ai-job-search";

    def write_local(text) -> any;

    def with_negation(negation) -> any;

    def test_listed_negation_passes -> any;

    def test_unlisted_negation_still_fails -> any;

    def test_line_that_is_not_a_negation_is_rejected -> any;

    def test_local_negation_cannot_cancel_a_required_rule -> any;

    def test_rejected_required_negation_is_not_also_allowlisted -> any;

    def test_negation_of_a_path_under_a_required_rule_is_still_allowed -> any;

    def test_file_absent_means_no_change -> any;

    def test_file_must_be_absent_on_upstream -> any;

    def test_upstream_checkout_ships_no_local_file -> any;
}

class ManifestGuardTests(GuardRepoFixture) {
    def test_prepare_wrapper_hooks_fail -> any;

    def test_each_lifecycle_script_fails -> any;

    def test_trusted_dependencies_fails -> any;
    def test_workspaces_fails -> any;

    def test_install_config_file_beside_manifest_fails -> any;

    def test_malformed_manifest_shape_fails_cleanly -> any;

    def test_benign_scripts_pass -> any;

    def test_node_modules_manifests_are_ignored -> any;

    def test_no_manifests_at_all_passes -> any;
}

class TrackedNodeModulesTests(GuardRepoFixture) {
    def _git(*args_) -> any;

    def _init_repo -> any;

    def test_tracked_node_modules_file_fails -> any;

    def test_untracked_node_modules_directory_passes -> any;

    def test_not_a_git_checkout_is_skipped -> any;
}

class RealRepoTests(unittest.TestCase) {
    def test_guards_pass_on_this_repo -> any;
}

with entry:__main__ {
    unittest.main();
}
