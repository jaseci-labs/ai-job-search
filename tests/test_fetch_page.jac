import builtins;

import contextlib;

import http.server;

import io;

import os;

import shutil;

import sys;

import tempfile;

import threading;

import unittest;

import from pathlib { Path }

glob REPO_ROOT: any;

glob PAGE: any;

glob KOREAN_PAGE: any;

glob CONTENT_TYPES: any;

with entry {
    REPO_ROOT = Path(__file__).resolve().parent.parent;

    PAGE = "<!doctype html><html><head><title>Posting</title><style>.x{color:red}</style><script>alert('tracking')</script></head><body><!-- hidden comment --><h1>Visible&nbsp;title</h1><p>Visible text &amp; more.</p><noscript>noscript text</noscript><svg><text>svg text</text></svg></body></html>";
    KOREAN_PAGE = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=euc-kr\"><title>채용공고</title></head><body><h1>백엔드 개발자 채용</h1></body></html>";
    CONTENT_TYPES = {"/euc-kr.html": "text/html; charset=euc-kr"};
}

class _Handler(http.server.BaseHTTPRequestHandler) {
    def do_GET -> any;

    def log_message(*args_) -> any;
}

class FetchPageFixture(unittest.TestCase) {
    class def setUpClass -> any;

    class def tearDownClass -> any;

    def setUp -> any;

    def allow_gate(url) -> any;

    def run_main(*argv_) -> any;
}

class SchemeAndPathGuards(FetchPageFixture) {
    def test_rejects_non_http_scheme -> any;

    def test_refuses_out_inside_repo_before_any_network -> any;

    def test_refuses_out_inside_repo_spelled_in_another_case -> any;
}

class RobotsGate(FetchPageFixture) {
    def test_refuses_when_robots_gate_denies -> any;

    def test_gate_sees_the_requested_url -> any;

    def test_redirect_target_is_checked_before_fetching -> any;

    def test_allowed_redirect_still_fetches_the_posting -> any;

    def test_raw_space_in_location_is_encoded_on_both_paths -> any;

    def test_raw_utf8_in_location_keeps_its_bytes_on_both_paths -> any;

    @unittest.skipUnless(
        shutil.which("curl"), "urllib cannot send a URL with raw non-ASCII characters"
    )
    def test_relative_redirect_from_a_unicode_url -> any;

    def test_cross_origin_redirect_uses_destination_policy -> any;
}

class Fetching(FetchPageFixture) {
    def test_fetches_and_reports_status -> any;

    def test_non_200_is_reported_not_fatal -> any;

    def test_text_strips_script_style_comments_and_unescapes -> any;

    def test_text_drops_unclosed_and_template_blocks -> any;

    def test_text_decodes_a_page_by_its_declared_charset -> any;

    def test_max_chars_caps_text -> any;

    def test_default_out_lands_in_temp_not_repo -> any;

    def _without_curl -> any;

    def test_redirect_loop_is_a_transport_error_on_both_paths -> any;

    def test_decompressed_size_is_bounded_on_urllib_path -> any;

    def test_urllib_fallback_when_curl_missing -> any;

    def test_fetch_succeeds_when_curl_lacks_compression -> any;
}

class CurlArgvShape(unittest.TestCase) {
    def test_curl_argv_is_get_only_and_terminates_options -> any;

    def test_user_agent_is_the_one_robots_check_uses -> any;

    def test_curl_compressed_flag_requires_decoder_support -> any;

    def test_curl_features_line_controls_compressed_support -> any;
}

with entry:__main__ {
    unittest.main();
}
