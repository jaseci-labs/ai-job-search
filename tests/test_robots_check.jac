"""Offline tests for tools/robots_check.jac.

No network: every case exercises the parser against literal robots.txt bodies,
matching the repo's CI policy of making no live portal requests.

The cases marked FAIL-OPEN REGRESSION are the ones Python's own
urllib.robotparser gets wrong. They are pinned here because getting them wrong
means the browser-header retry runs against a site that said no, which is the
exact boundary this tool exists to hold.
"""

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
    """FAIL-OPEN REGRESSION: /cs/ is disallowed despite the blank lines."""
    def test_blank_lines_inside_record_do_not_end_it -> any;

    def test_allowed_path_on_same_site_still_allowed -> any;

    """FAIL-OPEN REGRESSION: 'Allow: /' precedes 'Disallow: /cs/' in the
        file; specificity must win, not position."""
    def test_longest_match_wins_over_rule_order -> any;

    def test_longest_match_can_unblock -> any;

    """Cautious tie-break: Google resolves ties to Allow, we do not."""
    def test_equal_specificity_tie_goes_to_disallow -> any;

    """The only ordering that exercises the tie-break clause: with Allow
        first, deleting the clause makes the first rule at a given length win
        and Allow would leak through. The Disallow-first sibling above cannot
        detect that mutation (review finding F21, 2026-08-19)."""
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
    """The doc calls this by path; make sure that entry point stays valid."""
    def test_module_is_importable_and_cli_exists -> any;
}

"""A 200 whose body is not a robots.txt used to grant permission.

    Found by adversarial review, not inspection. A misconfigured host answering
    /robots.txt with an HTML error page at status 200 parses to zero rules, and
    zero rules read as "allowed" - so the browser retry ran on permission that
    was never given. FAIL-OPEN REGRESSION.
    """
class TestSoftTwoHundred(unittest.TestCase) {
    def test_html_error_page_is_not_a_robots_file -> any;

    def test_json_error_body_is_not_a_robots_file -> any;

    def test_soft_200_is_unconfirmed_not_allowed -> any;

    """09-web-research.md's Barclays-class recovery: the policy file itself
        returns 403 to Claude-User and 200 to a browser, and the checker must
        then read it as a browser and obey it strictly. This is gate()'s UA
        fallback loop, previously untested despite the doc's coverage claim
        (review finding F30, 2026-08-19)."""
    def test_gate_reads_policy_as_browser_when_honest_request_is_refused -> any;

    """The fallback must not fail open: a policy readable only as a browser
        still disallows what it disallows."""
    def test_gate_obeys_a_browser_fetched_policy_strictly -> any;

    """RFC 9309: an empty file permits everything. Do not over-correct."""
    def test_a_genuinely_empty_robots_is_still_allow_all -> any;

    def test_a_real_policy_is_recognised -> any;

    def test_sitemap_only_file_counts -> any;

    static has RAILS_DEFAULT: any = "# See http://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file\n#\n# To ban all spiders from the entire site uncomment the next two lines:\n# User-agent: *\n# Disallow: /\n";

    def test_a_comment_only_robots_is_allow_all -> any;

    def test_gate_allows_a_comment_only_robots -> any;

    """Only a body that is ALL comments counts; one leading comment line in
        front of an HTML page is still a soft 200."""
    def test_a_comment_line_does_not_make_an_error_page_a_robots_file -> any;

    """CRLF, CR-only and indented comments are the same comment-only file."""
    def test_comment_only_with_other_line_endings_and_indent_is_allow_all -> any;

    """Accepted trade-off, pinned so nobody mistakes it for a bug: a plain-text
        error body made only of '#' lines cannot be told from a one-comment
        robots.txt, RFC 9309 parses both as no rules, and such a host has
        published no policy (the same as a 404). See is_robots_body()."""
    def test_a_hash_only_error_page_reads_as_allow_all_on_purpose -> any;

    """A rule after a comment line is still a rule."""
    def test_a_comment_only_body_cannot_hide_a_rule -> any;
}

"""Rule patterns are percent-decoded to match the decoded request path.

    FAIL-OPEN REGRESSION: without this, a site that percent-encodes its own
    Disallow patterns has them silently skipped.
    """
class TestPercentEncodedRules(unittest.TestCase) {
    def test_encoded_space_in_disallow_now_matches -> any;

    def test_encoded_rule_does_not_overmatch -> any;

    def test_plain_rules_are_unaffected -> any;
}

"""One leading UTF-8 byte-order mark is skipped before parsing.

    FAIL-OPEN REGRESSION: a robots.txt saved with a BOM decodes to a body that
    starts with U+FEFF, so its first field was U+FEFF + "user-agent", which is
    not "user-agent". A leading "User-agent: *" went unseen, every rule in its
    group was dropped for want of an agent, and "Disallow: /" read as
    allow-all. Google's reference parser skips the BOM; Python's robotparser
    does not.
    """
class TestByteOrderMark(unittest.TestCase) {
    static has BODY: any = "﻿User-agent: *\nDisallow: /\n";

    def test_bom_does_not_hide_the_first_group -> any;

    def test_gate_obeys_a_policy_saved_with_a_bom -> any;

    """A lone directive behind a BOM read as a soft 200 (fail-closed, but
        wrong). A BOM-only file is an empty file: allow-all, as RFC 9309 says."""
    def test_is_robots_body_skips_the_bom_too -> any;
}

"""A User-agent, Allow or Disallow line holding U+FFFD is unreadable.

    FAIL-OPEN REGRESSION: read as the UTF-8 that RFC 9309 requires, with bad
    bytes replaced, a non-conformant robots.txt saved in cp1254 turns
    "Disallow: /şirket/" into a pattern holding U+FFFD. It can never match, so
    the rule was silently skipped and the path read as allowed. The gate now
    leaves permission unconfirmed instead. U+FFFD in a comment or an unrelated
    line decides nothing and must stay harmless.
    """
class TestUndecodableRules(unittest.TestCase) {
    """`text` saved in cp1254, then read as UTF-8 with bad bytes replaced."""
    static def _legacy(text) -> any;

    def _gate(body, url) -> any;

    def test_undecodable_disallow_is_unconfirmed_not_allowed -> any;

    """A trailing 0xA0 is a no-break space in cp1254, which strip() removes,
        but U+FFFD in UTF-8, which it does not: "*" became another agent and
        the group's Disallow stopped applying."""
    def test_undecodable_star_agent_is_unconfirmed -> any;

    """A 0xA0 indent garbled the field name, so the Disallow went unseen."""
    def test_undecodable_byte_before_the_field_is_unconfirmed -> any;

    """User-agent, Allow and Disallow alike, and a first line behind a BOM:
        _groups skips the BOM, so the check must too or it misses that line."""
    def test_every_rule_line_is_checked -> any;

    def test_fffd_in_a_comment_or_an_unrelated_line_is_harmless -> any;

    """Real UTF-8 never decodes to U+FFFD. The first rule is tr.indeed.com's."""
    def test_valid_utf8_non_ascii_rules_are_still_obeyed -> any;
}

"""A URL can never be read by curl as an option.

    gate() rebuilds the target as scheme://host/robots.txt, so the gate path was
    never exposed; this pins the "--" terminator for direct _fetch callers and
    confirms a dash-leading argument fails closed end to end.
    """
class TestArgumentHardening(unittest.TestCase) {
    def test_curl_argv_ends_with_a_double_dash_before_the_url -> any;

    def test_a_dash_leading_argument_fails_closed -> any;

    """The robots target is rebuilt from scheme+host, never the raw input."""
    def test_gate_never_passes_the_caller_url_through_to_curl -> any;
}

"""curl's output is decoded as UTF-8, never the locale's code page.

    With text=True and no encoding, Windows decoded with the locale's code page.
    Under cp1254 (Turkish) the bytes 0x81 and 0x9e are undefined, so the pipe
    reader thread died, stdout came back None, and the gate printed
    "UNCONFIRMED (AttributeError)" for policies it never read - blocking a
    retry those policies allow (reproduced 2026-09-29).
    """
class TestNonAsciiCurlOutput(unittest.TestCase) {
    """gate(url) with curl swapped for a process that prints `body` and the
        status the way curl's -w does, decoded however _fetch asks."""
    def _gate_with_curl_output(url, body, status) -> any;

    """The rule is verbatim from tr.indeed.com/robots.txt: 職 is e8 81 b7.
        DISALLOWED on its path proves it was decoded, not merely survived."""
    def test_rule_holding_a_cp1254_undefined_byte_is_read_and_obeyed -> any;

    """kap.org.tr answers /robots.txt with a UTF-8 HTML 404 that names
        "Merkezi Kayıt Kuruluşu A.Ş." - Ş is c5 9e."""
    def test_404_page_holding_a_cp1254_undefined_byte_still_means_no_policy -> any;
}

with entry:__main__ {
    unittest.main();
}

"""GHSA-h8vc-753p-wpmh: only http(s) reaches curl, on the first hop and on
    every redirect.

    gate() rebuilt the target as scheme://host/robots.txt but never checked the
    scheme, so a direct call with file:, gopher: or ftp: handed that scheme to
    curl, and curl -L was free to follow a redirect to any protocol it supports.
    """
class TestSchemeHardening(unittest.TestCase) {
    def _gate_without_curl(url) -> any;

    def test_non_http_scheme_is_unconfirmed_without_a_fetch -> any;

    def test_missing_host_is_unconfirmed_without_a_fetch -> any;

    def test_curl_is_pinned_to_http_and_https_on_every_hop -> any;

    def test_real_curl_refuses_a_file_url_through_fetch -> any;
}
