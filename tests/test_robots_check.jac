import shutil;
import subprocess;
import sys;
import time;
import unittest;
import from unittest { mock }

glob STAR: str = "User-agent: *\n",
     BARCLAYS: str = "User-agent: *\n\n\nAllow: /\n\nDisallow: /cs/\n\nSitemap: https://x/sitemap.xml\n",
     JOBUP: str = STAR + "Disallow: /api/\n",
     RAILS_DEFAULT: str = "# See http://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file\n#\n# To ban all spiders from the entire site uncomment the next two lines:\n# User-agent: *\n# Disallow: /\n",
     BOM: str = "﻿",
     FFFD: str = "�",
     WILDCARDS: str = STAR + "Disallow: /a*b\nDisallow: /x/*/y$\nDisallow: /end*$\n",
     OPT_OUT: str = "User-agent: Claude-User\nDisallow: /\n\nUser-agent: *\nAllow: /\n",
     SHARED: str = "User-agent: A\nUser-agent: Claude-User\nDisallow: /z\n",
     CJK: str = STAR + "Disallow: /職涯貼士/\nDisallow: /şirket/\n",
     TURKISH: str = legacy(
         "# Şirket politikası\nUser-agent: *\nDisallow: /api/  # özel\nSitemap: https://legacy.example/şirket.xml\nAçıklama: iş ilanları\n",
     );

def legacy(text: str) -> str;

def waf(policy: str) -> any;

class RobotsCase(unittest.TestCase) {
    def gate_with(reply: any, url: str) -> tuple[int, str];
}

class PathAndAgentRules(RobotsCase) {
    def test_allowed;
    def test_repeated_wildcards_do_not_catastrophically_backtrack;
}

class Bodies(RobotsCase) {
    def test_is_robots_body;
    def test_has_undecodable_rule;
}

class Gate(RobotsCase) {
    def test_gate_obeys_the_fetched_policy;
    def test_unsupported_url_is_unconfirmed_without_a_fetch;
    def test_gate_never_passes_the_caller_url_through_to_curl;
}

class Curl(RobotsCase) {
    def test_cli_usage_and_dash_leading_argument;
    def test_curl_argv_is_pinned_to_http_and_ends_with_a_double_dash_before_the_url;
    def test_curl_output_is_read_as_utf8_whatever_the_locale;

    @unittest.skipUnless(shutil.which("curl"), "curl is not installed")
    def test_real_curl_refuses_a_file_url_through_fetch;
}
