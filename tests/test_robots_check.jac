import builtins;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

glob BARCLAYS: any;

glob JOBUP: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parents[1];
    BARCLAYS = "User-agent: *\n\n\nAllow: /\n\nDisallow: /cs/\n\nSitemap: https://x/sitemap.xml\n";
    JOBUP = "User-agent: *\nDisallow: /api/\n";
}

class TestPathRules(unittest.TestCase) {
    def test_blank_lines_inside_record_do_not_end_it -> any;

    def test_allowed_path_on_same_site_still_allowed -> any;

    def test_longest_match_wins_over_rule_order -> any;

    def test_longest_match_can_unblock -> any;

    def test_equal_specificity_tie_goes_to_disallow -> any;

    def test_equal_specificity_tie_goes_to_disallow_when_allow_listed_first -> any;

    def test_api_block_and_sibling_path -> any;

    def test_wildcard_and_end_anchor -> any;

    def test_dollar_sign_mid_pattern_is_literal_not_end_anchor -> any;

    def test_repeated_wildcards_do_not_catastrophically_backtrack -> any;

    def test_consecutive_wildcards_match_identically_to_single_wildcard -> any;

    def test_wildcard_semantics_survive_the_matcher_change -> any;

    def test_percent_encoded_query_string_matches_rule_in_gate -> any;

    def test_empty_disallow_means_allow_everything -> any;

    def test_empty_or_ruleless_robots_allows -> any;

    def test_comments_are_stripped -> any;
}

class TestAgentSelection(unittest.TestCase) {
    def test_named_claude_user_opt_out_is_honored -> any;

    def test_agent_match_is_case_insensitive -> any;

    def test_falls_back_to_star_when_agent_absent -> any;

    def test_multiple_agents_share_one_ruleset -> any;
}

class TestCli(unittest.TestCase) {
    def test_module_is_importable_and_cli_exists -> any;
}

class TestSoftTwoHundred(unittest.TestCase) {
    def test_html_error_page_is_not_a_robots_file -> any;

    def test_json_error_body_is_not_a_robots_file -> any;

    def test_soft_200_is_unconfirmed_not_allowed -> any;

    def test_gate_reads_policy_as_browser_when_honest_request_is_refused -> any;

    def test_gate_obeys_a_browser_fetched_policy_strictly -> any;

    def test_a_genuinely_empty_robots_is_still_allow_all -> any;

    def test_a_real_policy_is_recognised -> any;

    def test_sitemap_only_file_counts -> any;

    static has RAILS_DEFAULT: any = "# See http://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file\n#\n# To ban all spiders from the entire site uncomment the next two lines:\n# User-agent: *\n# Disallow: /\n";

    def test_a_comment_only_robots_is_allow_all -> any;

    def test_gate_allows_a_comment_only_robots -> any;

    def test_a_comment_line_does_not_make_an_error_page_a_robots_file -> any;

    def test_comment_only_with_other_line_endings_and_indent_is_allow_all -> any;

    def test_a_hash_only_error_page_reads_as_allow_all_on_purpose -> any;

    def test_a_comment_only_body_cannot_hide_a_rule -> any;
}

class TestPercentEncodedRules(unittest.TestCase) {
    def test_encoded_space_in_disallow_now_matches -> any;

    def test_encoded_rule_does_not_overmatch -> any;

    def test_plain_rules_are_unaffected -> any;
}

class TestByteOrderMark(unittest.TestCase) {
    static has BODY: any = "﻿User-agent: *\nDisallow: /\n";

    def test_bom_does_not_hide_the_first_group -> any;

    def test_gate_obeys_a_policy_saved_with_a_bom -> any;

    def test_is_robots_body_skips_the_bom_too -> any;
}

class TestUndecodableRules(unittest.TestCase) {
    static def _legacy(text) -> any;

    def _gate(body, url) -> any;

    def test_undecodable_disallow_is_unconfirmed_not_allowed -> any;

    def test_undecodable_star_agent_is_unconfirmed -> any;

    def test_undecodable_byte_before_the_field_is_unconfirmed -> any;

    def test_every_rule_line_is_checked -> any;

    def test_fffd_in_a_comment_or_an_unrelated_line_is_harmless -> any;

    def test_valid_utf8_non_ascii_rules_are_still_obeyed -> any;
}

class TestArgumentHardening(unittest.TestCase) {
    def test_curl_argv_ends_with_a_double_dash_before_the_url -> any;

    def test_a_dash_leading_argument_fails_closed -> any;

    def test_gate_never_passes_the_caller_url_through_to_curl -> any;
}

class TestNonAsciiCurlOutput(unittest.TestCase) {
    def _gate_with_curl_output(url, body, status) -> any;

    def test_rule_holding_a_cp1254_undefined_byte_is_read_and_obeyed -> any;

    def test_404_page_holding_a_cp1254_undefined_byte_still_means_no_policy -> any;
}

with entry:__main__ {
    unittest.main();
}

class TestSchemeHardening(unittest.TestCase) {
    def _gate_without_curl(url) -> any;

    def test_non_http_scheme_is_unconfirmed_without_a_fetch -> any;

    def test_missing_host_is_unconfirmed_without_a_fetch -> any;

    def test_curl_is_pinned_to_http_and_https_on_every_hop -> any;

    def test_real_curl_refuses_a_file_url_through_fetch -> any;
}
