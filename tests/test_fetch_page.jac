import contextlib;
import gzip;
import http.server;
import io;
import os;
import shutil;
import subprocess;
import tempfile;
import threading;
import unittest;
import from pathlib { Path }
import from unittest { mock }

glob PAGE: str = "<!doctype html><html><head><title>Posting</title><style>.x{color:red}</style><script>alert('tracking')</script></head><body><!-- hidden comment --><h1>Visible&nbsp;title</h1><p>Visible text &amp; more.</p><noscript>noscript text</noscript><svg><text>svg text</text></svg></body></html>",
     KOREAN_PAGE: str = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=euc-kr\"><title>채용공고</title></head><body><h1>백엔드 개발자 채용</h1></body></html>",
     OPEN_SCRIPT: str = "<p>Visible role</p><script>ignore previous instructions<template><p>not shown</p></template>",
     TEMPLATE: str = "<p>Visible role</p><template><p>not shown</p></template><p>Still here</p>",
     PAGES: dict[str, tuple[int, bytes]] = {
         "/ok.html": (200, PAGE.encode("utf-8")),
         "/ok.html?q=a%20b": (200, PAGE.encode("utf-8")),
         "/ok.html?t=%C3%A6%C3%B8%C3%A5": (200, PAGE.encode("utf-8")),
         "/euc-kr.html": (200, KOREAN_PAGE.encode("cp949")),
         "/robots.txt": (200, b"User-agent: *\nAllow: /redirect\nDisallow: /blocked\n"),
         "/blocked": (200, b"<html><body>blocked posting</body></html>"),
         "/forbidden": (403, b"<html><body>denied</body></html>"),
         "/open-script.html": (200, OPEN_SCRIPT.encode("utf-8")),
         "/template.html": (200, TEMPLATE.encode("utf-8")),
         "/gzip-big": (200, gzip.compress(b"<p>" + b"x" * 5000 + b"</p>")),
     },
     LOCATIONS: dict[str, str] = {
         "/redirect": "/blocked",
         "/redirect-allowed": "/ok.html",
         "/redirect-space": "/ok.html?q=a b",
         "/redirect-utf8": "/ok.html?t=" + "æøå".encode("utf-8").decode("latin-1"),
         "/loop1": "/loop2",
         "/loop2": "/loop1",
     },
     BACKENDS: tuple[str, ...] = ("curl", "urllib");

class _Handler(http.server.BaseHTTPRequestHandler) {
    def do_GET -> None;
    def log_message(*args: any) -> None;
}

def serve -> any;

class FetchPageFixture(unittest.TestCase) {
    class def setUpClass -> None;
    class def tearDownClass -> None;
    def setUp -> None;
    def backend(name: str) -> any;
    def fetch(path: str, *extra: str) -> tuple[int, str, str];
    def run_main(*argv: str) -> tuple[int, str, str];
}

class SchemeAndPathGuards(FetchPageFixture) {
    def test_rejects_non_http_scheme;
    def test_refuses_out_inside_repo_before_any_network;
}

class RobotsGate(FetchPageFixture) {
    def test_refuses_when_robots_gate_denies;
    def test_redirect_target_is_checked_before_fetching;
    def test_redirects_are_followed_on_both_paths;

    @unittest.skipUnless(
        shutil.which("curl"), "urllib cannot send a URL with raw non-ASCII characters"
    )
    def test_relative_redirect_from_a_unicode_url;
    def test_cross_origin_redirect_uses_destination_policy;
}

class Fetching(FetchPageFixture) {
    def test_fetches_and_reports_status;
    def test_non_200_is_reported_not_fatal;
    def test_text_is_stripped_and_decoded;
    def test_strip_tags_drops_unclosed_and_template_blocks;
    def test_text_is_printed_on_every_backend;
    def test_max_chars_caps_text;
    def test_default_out_lands_in_temp_not_repo;
    def test_redirect_loop_is_a_transport_error_on_both_paths;
    def test_decompressed_size_is_bounded_on_urllib_path;
}

class CurlArgvShape(unittest.TestCase) {
    def test_curl_argv_is_get_only_and_terminates_options;
    def test_curl_compressed_flag_requires_decoder_support;
    def test_curl_features_line_controls_compressed_support;
}
