impl TestPathRules.test_blank_lines_inside_record_do_not_end_it -> any {
    self.assertFalse(allowed(BARCLAYS, "*", "/cs/"));
}

impl TestPathRules.test_allowed_path_on_same_site_still_allowed -> any {
    self.assertTrue(allowed(BARCLAYS, "*", "/careers/"));
}

impl TestPathRules.test_longest_match_wins_over_rule_order -> any {
    body: any = "User-agent: *\nAllow: /\nDisallow: /cs/\n";
    self.assertFalse(allowed(body, "*", "/cs/deep/page"));
}

impl TestPathRules.test_longest_match_can_unblock -> any {
    body: any = "User-agent: *\nDisallow: /\nAllow: /jobs/\n";
    self.assertTrue(allowed(body, "*", "/jobs/x"));
    self.assertFalse(allowed(body, "*", "/other"));
}

impl TestPathRules.test_equal_specificity_tie_goes_to_disallow -> any {
    self.assertFalse(allowed("User-agent: *\nDisallow: /a\nAllow: /a\n", "*", "/a"));
}

impl TestPathRules.test_equal_specificity_tie_goes_to_disallow_when_allow_listed_first -> any {
    self.assertFalse(allowed("User-agent: *\nAllow: /a\nDisallow: /a\n", "*", "/a"));
}

impl TestPathRules.test_api_block_and_sibling_path -> any {
    self.assertFalse(allowed(JOBUP, "*", "/api/v1/public/search"));
    self.assertTrue(allowed(JOBUP, "*", "/en/jobs/"));
}

impl TestPathRules.test_wildcard_and_end_anchor -> any {
    body: any = "User-agent: *\nDisallow: /*.pdf$\n";
    self.assertFalse(allowed(body, "*", "/files/cv.pdf"));
    self.assertTrue(allowed(body, "*", "/files/cv.pdf.html"));
}

impl TestPathRules.test_dollar_sign_mid_pattern_is_literal_not_end_anchor -> any {
    body: any = "User-agent: *\nDisallow: /tag/$var\n";
    self.assertFalse(allowed(body, "*", "/tag/$var"));
    self.assertFalse(allowed(body, "*", "/tag/$var/sub"));
}

impl TestPathRules.test_repeated_wildcards_do_not_catastrophically_backtrack -> any {
    import time;

    pat: any = "/" + "*a" * 13 + "*b$";
    body: any = f"User-agent: *\nDisallow: {pat}\n";
    path: any = "/" + "a" * 28 + "X";
    start: any = time.perf_counter();
    res: any = allowed(body, "*", path);
    elapsed: any = time.perf_counter() - start;
    self.assertTrue(res);
    self.assertLess(elapsed, 0.5, f"_match took {elapsed:.2f}s (catastrophic backtracking)");
}

impl TestPathRules.test_consecutive_wildcards_match_identically_to_single_wildcard -> any {
    body: any = "User-agent: *\nDisallow: /docs/*******.pdf$\n";
    self.assertFalse(allowed(body, "*", "/docs/cv.pdf"));
    self.assertFalse(allowed(body, "*", "/docs/sub/folder/cv.pdf"));
    self.assertTrue(allowed(body, "*", "/docs/sub/folder/cv.html"));
}

impl TestPathRules.test_wildcard_semantics_survive_the_matcher_change -> any {
    body: any = "User-agent: *\nDisallow: /a*b\nDisallow: /x/*/y$\nDisallow: /end*$\n";
    self.assertFalse(allowed(body, "*", "/ab"));
    self.assertFalse(allowed(body, "*", "/a/long/path/b/and-more"));
    self.assertTrue(allowed(body, "*", "/a"));
    self.assertFalse(allowed(body, "*", "/x/anything/at/all/y"));
    self.assertTrue(allowed(body, "*", "/x/anything/y/more"));
    self.assertFalse(allowed(body, "*", "/end"));
    self.assertFalse(allowed(body, "*", "/ending/here"));
    self.assertTrue(allowed(body, "*", "/en"));
}

impl TestPathRules.test_percent_encoded_query_string_matches_rule_in_gate -> any {
    body: any;
    import from tools { robots_check }

    body = "User-agent: *\nDisallow: /search?q=machine%20learning\n";
    original: any = robots_check._fetch;
    robots_check._fetch = lambda (url, ua) -> any { (body, 200) };
    try {
        rc: any;
        msg: any;
        (rc, msg) = robots_check.gate("https://example.com/search?q=machine%20learning") as any;
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(rc, 1, msg);
    self.assertIn("DISALLOWED", msg);
}

impl TestPathRules.test_empty_disallow_means_allow_everything -> any {
    self.assertTrue(allowed("User-agent: *\nDisallow:\n", "*", "/anything"));
}

impl TestPathRules.test_empty_or_ruleless_robots_allows -> any {
    self.assertTrue(allowed("", "*", "/x"));
    self.assertTrue(allowed("# just a comment\n", "*", "/x"));
}

impl TestPathRules.test_comments_are_stripped -> any {
    self.assertFalse(allowed("User-agent: *\nDisallow: /x  # nope\n", "*", "/x"));
}

impl TestAgentSelection.test_named_claude_user_opt_out_is_honored -> any {
    body: any = "User-agent: Claude-User\nDisallow: /\n\nUser-agent: *\nAllow: /\n";
    self.assertFalse(allowed(body, "Claude-User", "/a"));
    self.assertTrue(allowed(body, "*", "/a"));
}

impl TestAgentSelection.test_agent_match_is_case_insensitive -> any {
    body: any = "User-agent: CLAUDE-USER\nDisallow: /x\n";
    self.assertFalse(allowed(body, "claude-user", "/x"));
}

impl TestAgentSelection.test_falls_back_to_star_when_agent_absent -> any {
    self.assertFalse(allowed(JOBUP, "Claude-User", "/api/v1"));
}

impl TestAgentSelection.test_multiple_agents_share_one_ruleset -> any {
    body: any = "User-agent: A\nUser-agent: Claude-User\nDisallow: /z\n";
    self.assertFalse(allowed(body, "Claude-User", "/z"));
    self.assertFalse(allowed(body, "A", "/z"));
}

impl TestCli.test_module_is_importable_and_cli_exists -> any {
    script: any = REPO_ROOT / "tools" / "robots_check.jac";
    self.assertTrue(script.is_file());
    out: any = subprocess.run([*tool("robots_check")], capture_output=True, text=True, timeout=30);
    self.assertEqual(out.returncode, 2, out.stderr);
    self.assertIn("usage:", out.stderr);
}

impl TestSoftTwoHundred.test_html_error_page_is_not_a_robots_file -> any {
    self.assertFalse(is_robots_body("<html><body>404 Not Found</body></html>"));
}

impl TestSoftTwoHundred.test_json_error_body_is_not_a_robots_file -> any {
    self.assertFalse(is_robots_body("{\"error\":\"not found\"}"));
}

impl TestSoftTwoHundred.test_soft_200_is_unconfirmed_not_allowed -> any {
    import from tools { robots_check }

    original: any = robots_check._fetch;
    robots_check._fetch = lambda (url, ua) -> any { ("<html>404</html>", 200) };
    try {
        rc: any;
        msg: any;
        (rc, msg) = robots_check.gate("https://x.example/jobs") as any;
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(rc, 1);
    self.assertIn("not a robots.txt", msg);
}

impl TestSoftTwoHundred.test_gate_reads_policy_as_browser_when_honest_request_is_refused -> any {
    import from tools { robots_check }

    original: any = robots_check._fetch;

    def waf(url, ua) -> any {
        if ua == robots_check.BROWSER {
            return ("User-agent: *\nAllow: /\n", 200);
        }
        return ("<html>403 Forbidden</html>", 403);
    }

    robots_check._fetch = waf;
    try {
        rc: any;
        msg: any;
        (rc, msg) = robots_check.gate("https://waf.example/jobs") as any;
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(rc, 0);
    self.assertIn("ALLOWED", msg);
}

impl TestSoftTwoHundred.test_gate_obeys_a_browser_fetched_policy_strictly -> any {
    import from tools { robots_check }

    original: any = robots_check._fetch;

    def waf(url, ua) -> any {
        if ua == robots_check.BROWSER {
            return ("User-agent: *\nDisallow: /jobs\n", 200);
        }
        return ("<html>403 Forbidden</html>", 403);
    }

    robots_check._fetch = waf;
    try {
        rc: any;
        msg: any;
        (rc, msg) = robots_check.gate("https://waf.example/jobs") as any;
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(rc, 1);
    self.assertIn("DISALLOWED", msg);
}

impl TestSoftTwoHundred.test_a_genuinely_empty_robots_is_still_allow_all -> any {
    self.assertTrue(is_robots_body(""));
    self.assertTrue(is_robots_body("\n\n   \n"));
}

impl TestSoftTwoHundred.test_a_real_policy_is_recognised -> any {
    self.assertTrue(is_robots_body(BARCLAYS));
    self.assertTrue(is_robots_body(JOBUP));
}

impl TestSoftTwoHundred.test_sitemap_only_file_counts -> any {
    self.assertTrue(is_robots_body("Sitemap: https://x.example/sitemap.xml\n"));
}

impl TestSoftTwoHundred.test_a_comment_only_robots_is_allow_all -> any {
    self.assertTrue(is_robots_body(self.RAILS_DEFAULT));
    self.assertTrue(is_robots_body("﻿" + self.RAILS_DEFAULT));
    self.assertTrue(allowed(self.RAILS_DEFAULT, "Claude-User", "/gitlab/jobs/8704363002"));
}

impl TestSoftTwoHundred.test_gate_allows_a_comment_only_robots -> any {
    import from tools { robots_check }

    original: any = robots_check._fetch;
    robots_check._fetch = lambda (url, ua) -> any { (self.RAILS_DEFAULT, 200) };
    try {
        rc: any;
        msg: any;
        (rc, msg) = robots_check.gate(
            "https://job-boards.greenhouse.io/gitlab/jobs/8704363002"
        ) as any;
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(rc, 0, msg);
    self.assertIn("ALLOWED", msg);
}

impl TestSoftTwoHundred.test_a_comment_line_does_not_make_an_error_page_a_robots_file -> any {
    self.assertFalse(is_robots_body("# cached\n<html><body>404 Not Found</body></html>\n"));
    self.assertFalse(is_robots_body("#!/bin/sh\necho not a robots file\n"));
}

impl TestSoftTwoHundred.test_comment_only_with_other_line_endings_and_indent_is_allow_all -> any {
    for body in (
        self.RAILS_DEFAULT.replace("\n", "\r\n"),
        self.RAILS_DEFAULT.replace("\n", "\r"),
        "   # indented comment\n\t# tab-indented comment\n",
    ) {
        with self.subTest(body=body[:30]) {
            self.assertTrue(is_robots_body(body));
        }
    }
}

impl TestSoftTwoHundred.test_a_hash_only_error_page_reads_as_allow_all_on_purpose -> any {
    self.assertTrue(is_robots_body("# 404 Not Found\n"));
}

impl TestSoftTwoHundred.test_a_comment_only_body_cannot_hide_a_rule -> any {
    body: any = "# generated\nUser-agent: *\nDisallow: /\n";
    self.assertTrue(is_robots_body(body));
    self.assertFalse(allowed(body, "Claude-User", "/jobs/1"));
}

impl TestPercentEncodedRules.test_encoded_space_in_disallow_now_matches -> any {
    self.assertFalse(allowed("User-agent: *\nDisallow: /foo%20bar\n", "*", "/foo bar"));
}

impl TestPercentEncodedRules.test_encoded_rule_does_not_overmatch -> any {
    self.assertTrue(allowed("User-agent: *\nDisallow: /foo%20bar\n", "*", "/foobar"));
}

impl TestPercentEncodedRules.test_plain_rules_are_unaffected -> any {
    self.assertFalse(allowed(JOBUP, "*", "/api/x"));
    self.assertTrue(allowed(JOBUP, "*", "/en/jobs/x"));
}

impl TestByteOrderMark.test_bom_does_not_hide_the_first_group -> any {
    self.assertFalse(allowed(self.BODY, "*", "/x"));
    self.assertFalse(allowed(self.BODY, "Claude-User", "/x"));
}

impl TestByteOrderMark.test_gate_obeys_a_policy_saved_with_a_bom -> any {
    import from tools { robots_check }

    original: any = robots_check._fetch;
    robots_check._fetch = lambda (url, ua) -> any { (self.BODY, 200) };
    try {
        rc: any;
        msg: any;
        (rc, msg) = robots_check.gate("https://bom.example/jobs") as any;
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(rc, 1);
    self.assertIn("DISALLOWED", msg);
}

impl TestByteOrderMark.test_is_robots_body_skips_the_bom_too -> any {
    self.assertTrue(is_robots_body("﻿Sitemap: https://x.example/sitemap.xml\n"));
    self.assertTrue(is_robots_body("﻿"));
}

impl TestUndecodableRules._legacy(text) -> any {
    return text.encode("cp1254").decode("utf-8", "replace");
}

impl TestUndecodableRules._gate(body, url) -> any {
    import from tools { robots_check }

    original: any = robots_check._fetch;
    robots_check._fetch = lambda (url, ua) -> any { (body, 200) };
    try {
        return robots_check.gate(url);
    } finally {
        robots_check._fetch = original;
    }
}

impl TestUndecodableRules.test_undecodable_disallow_is_unconfirmed_not_allowed -> any {
    body: any = self._legacy("User-agent: *\nDisallow: /şirket/\n");
    self.assertIn("�", body);
    rc: any;
    msg: any;
    (rc, msg) = self._gate(body, "https://legacy.example/şirket/x") as any;
    self.assertEqual(rc, 1, msg);
    self.assertIn("UNCONFIRMED", msg);
    self.assertIn("not valid UTF-8", msg);
}

impl TestUndecodableRules.test_undecodable_star_agent_is_unconfirmed -> any {
    body: any = self._legacy("User-agent: * \nDisallow: /\n");
    rc: any;
    msg: any;
    (rc, msg) = self._gate(body, "https://legacy.example/jobs") as any;
    self.assertEqual(rc, 1, msg);
    self.assertIn("UNCONFIRMED", msg);
}

impl TestUndecodableRules.test_undecodable_byte_before_the_field_is_unconfirmed -> any {
    body: any = self._legacy("User-agent: *\n Disallow: /jobs\n");
    rc: any;
    msg: any;
    (rc, msg) = self._gate(body, "https://legacy.example/jobs") as any;
    self.assertEqual(rc, 1, msg);
    self.assertIn("UNCONFIRMED", msg);
}

impl TestUndecodableRules.test_every_rule_line_is_checked -> any {
    for body in (
        self._legacy("User-agent: Bot \n"),
        self._legacy("Allow: /ş/\n"),
        self._legacy("Disallow: /ş/\n"),
        "﻿" + self._legacy("User-agent: * \nDisallow: /\n"),
    ) {
        with self.subTest(body=body) {
            self.assertTrue(has_undecodable_rule(body));
        }
    }
}

impl TestUndecodableRules.test_fffd_in_a_comment_or_an_unrelated_line_is_harmless -> any {
    body: any = self._legacy(
        "# Şirket politikası\nUser-agent: *\nDisallow: /api/  # özel\nSitemap: https://legacy.example/şirket.xml\nAçıklama: iş ilanları\n",
    );
    clean: any = [line for line in body.splitlines() if "�" not in line];
    self.assertEqual(clean, ["User-agent: *"]);
    self.assertFalse(has_undecodable_rule(body));
    rc: any;
    msg: any;
    (rc, msg) = self._gate(body, "https://legacy.example/jobs") as any;
    self.assertEqual(rc, 0, msg);
    (rc, msg) = self._gate(body, "https://legacy.example/api/x") as any;
    self.assertEqual(rc, 1, msg);
    self.assertIn("DISALLOWED", msg);
}

impl TestUndecodableRules.test_valid_utf8_non_ascii_rules_are_still_obeyed -> any {
    body: any = "User-agent: *\nDisallow: /職涯貼士/\nDisallow: /şirket/\n";
    self.assertFalse(has_undecodable_rule(body));
    for path in ("/職涯貼士/x", "/şirket/x") {
        rc: any;
        msg: any;
        (rc, msg) = self._gate(body, "https://tr.indeed.example" + path) as any;
        self.assertEqual(rc, 1, msg);
        self.assertIn("DISALLOWED", msg);
    }
    (rc, msg) = self._gate(body, "https://tr.indeed.example/cmp/x/reviews") as any;
    self.assertEqual(rc, 0, msg);
}

impl TestArgumentHardening.test_curl_argv_ends_with_a_double_dash_before_the_url -> any {
    src: any = (REPO_ROOT / "tools" / "impl" / "robots_check.impl.jac").read_text(encoding="utf-8");
    self.assertRegex(src, "\"--\",\\s+url,");
}

impl TestArgumentHardening.test_a_dash_leading_argument_fails_closed -> any {
    out: any = subprocess.run(
        [*tool("robots_check"), "--help"], capture_output=True, text=True, timeout=60
    );
    self.assertEqual(out.returncode, 1);
    self.assertNotIn("Usage: curl", out.stdout);
}

impl TestArgumentHardening.test_gate_never_passes_the_caller_url_through_to_curl -> any {
    seen: any;
    import from tools { robots_check }

    seen = [];

    original: any = robots_check._fetch;

    def spy(url, ua) -> any {
        seen.append(url);
        return ("User-agent: *\nAllow: /\n", 200);
    }

    robots_check._fetch = spy;
    try {
        robots_check.gate("https://x.example/-o/evil?q=1");
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(seen[0], "https://x.example/robots.txt");
}

impl TestNonAsciiCurlOutput._gate_with_curl_output(url, body, status) -> any {
    raw: any;
    real_run: any;
    import from tools { robots_check }
    self.assertRaises(UnicodeDecodeError, body.decode, "cp1254");
    raw = body + b"\n" + `str(status).encode();
    real_run = subprocess.run;

    def fake_curl(argv, **kwargs) -> any {
        if kwargs.get("text") and not kwargs.get("encoding") {
            kwargs["encoding"] = "cp1254";
        }
        write: any = "import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))";
        return real_run([sys.executable, "-c", write, raw.hex()], **kwargs);
    }

    robots_check.subprocess.run = fake_curl;
    try {
        return robots_check.gate(url);
    } finally {
        robots_check.subprocess.run = real_run;
    }
}

impl TestNonAsciiCurlOutput.test_rule_holding_a_cp1254_undefined_byte_is_read_and_obeyed -> any {
    body: any = "User-agent: *\nDisallow: /職涯貼士/\n".encode("utf-8");
    rc: any;
    msg: any;
    (rc, msg) = self._gate_with_curl_output(
        "https://tr.indeed.example/cmp/x/reviews", body, 200
    ) as any;
    self.assertEqual(rc, 0, msg);
    self.assertIn("robots.txt permits this path", msg);
    (rc, msg) = self._gate_with_curl_output("https://tr.indeed.example/職涯貼士/x", body, 200) as any;
    self.assertEqual(rc, 1, msg);
    self.assertIn("DISALLOWED", msg);
}

impl TestNonAsciiCurlOutput.test_404_page_holding_a_cp1254_undefined_byte_still_means_no_policy -> any {
    body: any = "<html lang=\"tr\"><body>Merkezi Kayıt Kuruluşu A.Ş.</body></html>".encode("utf-8");
    rc: any;
    msg: any;
    (rc, msg) = self._gate_with_curl_output(
        "https://kap.example/tr/sirket-bilgileri", body, 404
    ) as any;
    self.assertEqual(rc, 0, msg);
    self.assertIn("no robots.txt published", msg);
}

impl TestSchemeHardening._gate_without_curl(url) -> any {
    fetched: any;
    import from tools { robots_check }

    fetched = [];
    original: any = robots_check._fetch;
    robots_check._fetch = lambda (url, ua) -> any { fetched.append(url) or ("", 404) };
    try {
        result: any = robots_check.gate(url);
    } finally {
        robots_check._fetch = original;
    }
    self.assertEqual(fetched, [], f"curl was asked for {fetched}");
    return result;
}

impl TestSchemeHardening.test_non_http_scheme_is_unconfirmed_without_a_fetch -> any {
    for url in (
        "file:///etc/passwd",
        "gopher://127.0.0.1:6379/_",
        "ftp://x.example/robots.txt",
        "x.example/path",
    ) {
        with self.subTest(url=url) {
            rc: any;
            msg: any;
            (rc, msg) = self._gate_without_curl(url) as any;
            self.assertEqual(rc, 1);
            self.assertTrue(msg.startswith("UNCONFIRMED"), msg);
            self.assertIn("scheme", msg);
        }
    }
}

impl TestSchemeHardening.test_missing_host_is_unconfirmed_without_a_fetch -> any {
    rc: any;
    msg: any;
    (rc, msg) = self._gate_without_curl("http:///robots.txt") as any;
    self.assertEqual(rc, 1);
    self.assertTrue(msg.startswith("UNCONFIRMED"), msg);
}

impl TestSchemeHardening.test_curl_is_pinned_to_http_and_https_on_every_hop -> any {
    seen: any;
    import from tools { robots_check }

    seen = [];

    class Done(builtins.object) {
        static has returncode: any = 0;

        static has stdout: any = "\n404";

        static has stderr: any = "";
    }

    def fake_run(argv, **kwargs) -> any {
        seen.append(argv);
        return Done();
    }

    original: any = robots_check.subprocess.run;
    robots_check.subprocess.run = fake_run;
    try {
        body: any;
        code: any;
        (body, code) = robots_check._fetch("https://x.example/robots.txt", "Claude-User") as any;
    } finally {
        robots_check.subprocess.run = original;
    }
    self.assertEqual(code, 404);
    argv: any = seen[0];
    self.assertIn("--proto", argv);
    self.assertEqual(argv[argv.index("--proto") + 1], "=http,https");
    self.assertIn("--proto-redir", argv);
    self.assertEqual(argv[argv.index("--proto-redir") + 1], "=http,https");
    self.assertLess(argv.index("--proto-redir"), argv.index("--"));
}

impl TestSchemeHardening.test_real_curl_refuses_a_file_url_through_fetch -> any {
    import shutil;

    import from tools { robots_check }

    if not shutil.which("curl") {
        self.skipTest("curl is not installed");
    }
    target: any = (REPO_ROOT / "tools" / "robots_check.jac").resolve().as_uri();
    with self.assertRaises(RuntimeError) {
        robots_check._fetch(target, "Claude-User");
    }
}
