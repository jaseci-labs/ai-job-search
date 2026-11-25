import shutil, subprocess, sys, time, unittest;
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

def legacy(text: str) -> str {
    return text.encode("cp1254").decode("utf-8", "replace");
}

def waf(policy: str) -> any {
    return lambda (url: str, ua: str) -> tuple[str, int] {
        (policy, 200) if ua == robots_check.BROWSER else ("<html>403 Forbidden</html>", 403)
    };
}

class RobotsCase(unittest.TestCase) {
    def gate_with(reply: any, url: str) -> tuple[int, str] {
        self.fetch = mock.Mock(side_effect=reply)
            if callable(reply)
            else mock.Mock(return_value=(reply, 200));
        with mock.patch.object(robots_check, "_fetch", self.fetch) {
            return robots_check.gate(url);
        }
    }
}

class PathAndAgentRules(RobotsCase) {
    def test_allowed {
        cases: list[tuple[str, str, str, bool]] = [
            (BARCLAYS, "*", "/cs/", False),
            (BARCLAYS, "*", "/careers/", True),
            (STAR + "Allow: /\nDisallow: /cs/\n", "*", "/cs/deep/page", False),
            (STAR + "Disallow: /\nAllow: /jobs/\n", "*", "/jobs/x", True),
            (STAR + "Disallow: /\nAllow: /jobs/\n", "*", "/other", False),
            (STAR + "Disallow: /a\nAllow: /a\n", "*", "/a", False),
            (STAR + "Allow: /a\nDisallow: /a\n", "*", "/a", False),
            (JOBUP, "*", "/api/v1/public/search", False),
            (JOBUP, "*", "/api/x", False),
            (JOBUP, "*", "/en/jobs/", True),
            (JOBUP, "*", "/en/jobs/x", True),
            (STAR + "Disallow: /*.pdf$\n", "*", "/files/cv.pdf", False),
            (STAR + "Disallow: /*.pdf$\n", "*", "/files/cv.pdf.html", True),
            (STAR + "Disallow: /tag/$var\n", "*", "/tag/$var", False),
            (STAR + "Disallow: /tag/$var\n", "*", "/tag/$var/sub", False),
            (STAR + "Disallow: /docs/*******.pdf$\n", "*", "/docs/cv.pdf", False),
            (STAR + "Disallow: /docs/*******.pdf$\n", "*", "/docs/sub/folder/cv.pdf", False),
            (STAR + "Disallow: /docs/*******.pdf$\n", "*", "/docs/sub/folder/cv.html", True),
            (WILDCARDS, "*", "/ab", False),
            (WILDCARDS, "*", "/a/long/path/b/and-more", False),
            (WILDCARDS, "*", "/a", True),
            (WILDCARDS, "*", "/x/anything/at/all/y", False),
            (WILDCARDS, "*", "/x/anything/y/more", True),
            (WILDCARDS, "*", "/end", False),
            (WILDCARDS, "*", "/ending/here", False),
            (WILDCARDS, "*", "/en", True),
            (STAR + "Disallow:\n", "*", "/anything", True),
            ("", "*", "/x", True),
            ("# just a comment\n", "*", "/x", True),
            (STAR + "Disallow: /x  # nope\n", "*", "/x", False),
            (STAR + "Disallow: /foo%20bar\n", "*", "/foo bar", False),
            (STAR + "Disallow: /foo%20bar\n", "*", "/foobar", True),
            (OPT_OUT, "Claude-User", "/a", False),
            (OPT_OUT, "*", "/a", True),
            ("User-agent: CLAUDE-USER\nDisallow: /x\n", "claude-user", "/x", False),
            (JOBUP, "Claude-User", "/api/v1", False),
            (SHARED, "Claude-User", "/z", False),
            (SHARED, "A", "/z", False),
            (BOM + STAR + "Disallow: /\n", "*", "/x", False),
            (BOM + STAR + "Disallow: /\n", "Claude-User", "/x", False),
            (RAILS_DEFAULT, "Claude-User", "/gitlab/jobs/8704363002", True),
            ("# generated\nUser-agent: *\nDisallow: /\n", "Claude-User", "/jobs/1", False),
        ];
        for (body, agent, path, expected) in cases {
            with self.subTest(body=body, agent=agent, path=path) {
                self.assertIs(robots_check.allowed(body, agent, path), expected);
            }
        }
    }

    def test_repeated_wildcards_do_not_catastrophically_backtrack {
        body: str = STAR + "Disallow: /" + "*a" * 13 + "*b$\n";
        start: float = time.perf_counter();
        self.assertTrue(robots_check.allowed(body, "*", "/" + "a" * 28 + "X"));
        elapsed: float = time.perf_counter() - start;
        self.assertLess(elapsed, 0.5, f"_match took {elapsed:.2f}s (catastrophic backtracking)");
    }
}

class Bodies(RobotsCase) {
    def test_is_robots_body {
        cases: list[tuple[str, bool]] = [
            ("<html><body>404 Not Found</body></html>", False),
            ("{\"error\":\"not found\"}", False),
            ("# cached\n<html><body>404 Not Found</body></html>\n", False),
            ("#!/bin/sh\necho not a robots file\n", False),
            ("", True),
            ("\n\n   \n", True),
            (BOM, True),
            (BARCLAYS, True),
            (JOBUP, True),
            ("Sitemap: https://x.example/sitemap.xml\n", True),
            (BOM + "Sitemap: https://x.example/sitemap.xml\n", True),
            (RAILS_DEFAULT, True),
            (BOM + RAILS_DEFAULT, True),
            (RAILS_DEFAULT.replace("\n", "\r\n"), True),
            (RAILS_DEFAULT.replace("\n", "\r"), True),
            ("   # indented comment\n\t# tab-indented comment\n", True),
            ("# 404 Not Found\n", True),
            ("# generated\nUser-agent: *\nDisallow: /\n", True),
        ];
        for (body, expected) in cases {
            with self.subTest(body=body[:40]) {
                self.assertIs(robots_check.is_robots_body(body), expected);
            }
        }
    }

    def test_has_undecodable_rule {
        self.assertEqual(
            [line for line in TURKISH.splitlines() if FFFD not in line], [STAR.strip()]
        );
        cases: list[tuple[str, bool]] = [
            (legacy("User-agent: Bot\xa0\n"), True),
            (legacy("Allow: /ş/\n"), True),
            (legacy("Disallow: /ş/\n"), True),
            (BOM + legacy("User-agent: *\xa0\nDisallow: /\n"), True),
            (TURKISH, False),
            (CJK, False),
        ];
        for (body, expected) in cases {
            with self.subTest(body=body) {
                self.assertIs(robots_check.has_undecodable_rule(body), expected);
            }
        }
    }
}

class Gate(RobotsCase) {
    def test_gate_obeys_the_fetched_policy {
        not_utf8: str = "UNCONFIRMED (HTTP 200 but a User-agent/Allow/Disallow line is not valid UTF-8)";
        undecodable: str = legacy(STAR + "Disallow: /şirket/\n");
        self.assertIn(FFFD, undecodable);
        cases: list[tuple[any, str, int, str]] = [
            (
                STAR + "Disallow: /search?q=machine%20learning\n",
                "https://example.com/search?q=machine%20learning",
                1,
                "DISALLOWED",
            ),
            ("<html>404</html>", "https://x.example/jobs", 1, "not a robots.txt"),
            (
                RAILS_DEFAULT,
                "https://job-boards.greenhouse.io/gitlab/jobs/8704363002",
                0,
                "ALLOWED",
            ),
            (BOM + STAR + "Disallow: /\n", "https://bom.example/jobs", 1, "DISALLOWED"),
            (waf(STAR + "Allow: /\n"), "https://waf.example/jobs", 0, "ALLOWED"),
            (waf(STAR + "Disallow: /jobs\n"), "https://waf.example/jobs", 1, "DISALLOWED"),
            (undecodable, "https://legacy.example/şirket/x", 1, not_utf8),
            (
                legacy("User-agent: *\xa0\nDisallow: /\n"),
                "https://legacy.example/jobs",
                1,
                not_utf8,
            ),
            (
                legacy("User-agent: *\n\xa0Disallow: /jobs\n"),
                "https://legacy.example/jobs",
                1,
                not_utf8,
            ),
            (TURKISH, "https://legacy.example/jobs", 0, "ALLOWED"),
            (TURKISH, "https://legacy.example/api/x", 1, "DISALLOWED"),
            (CJK, "https://tr.indeed.example/職涯貼士/x", 1, "DISALLOWED"),
            (CJK, "https://tr.indeed.example/şirket/x", 1, "DISALLOWED"),
            (CJK, "https://tr.indeed.example/cmp/x/reviews", 0, "ALLOWED"),
        ];
        for (reply, url, expected, said) in cases {
            with self.subTest(url=url, said=said) {
                (rc, msg) = self.gate_with(reply, url);
                self.assertEqual(rc, expected, msg);
                self.assertIn(said, msg);
            }
        }
    }

    def test_unsupported_url_is_unconfirmed_without_a_fetch {
        cases: list[tuple[str, str]] = [
            ("file:///etc/passwd", "scheme"),
            ("gopher://127.0.0.1:6379/_", "scheme"),
            ("ftp://x.example/robots.txt", "scheme"),
            ("x.example/path", "scheme"),
            ("http:///robots.txt", "no host"),
        ];
        for (url, said) in cases {
            with self.subTest(url=url) {
                (rc, msg) = self.gate_with("", url);
                self.assertEqual(rc, 1);
                self.assertTrue(msg.startswith("UNCONFIRMED"), msg);
                self.assertIn(said, msg);
                self.fetch.assert_not_called();
            }
        }
    }

    def test_gate_never_passes_the_caller_url_through_to_curl {
        self.gate_with(STAR + "Allow: /\n", "https://x.example/-o/evil?q=1");
        self.assertEqual(self.fetch.call_args_list[0].args[0], "https://x.example/robots.txt");
    }
}

class Curl(RobotsCase) {
    def test_cli_usage_and_dash_leading_argument {
        self.assertTrue((REPO / "tools" / "robots_check.jac").is_file());
        usage: any = capture(tool("robots_check"), timeout=30);
        self.assertEqual(usage.returncode, 2, usage.stderr);
        self.assertIn("usage:", usage.stderr);
        dashed: any = capture([*tool("robots_check"), "--help"], timeout=60);
        self.assertEqual(dashed.returncode, 1);
        self.assertNotIn("Usage: curl", dashed.stdout);
    }

    def test_curl_argv_is_pinned_to_http_and_ends_with_a_double_dash_before_the_url {
        src: str = (REPO / "tools" / "robots_check.jac").read_text(encoding="utf-8");
        self.assertRegex(src, "\"--\",\\s*url,?\\s*\\]");
        url: str = "https://x.example/robots.txt";
        done: mock.Mock = mock.Mock(returncode=0, stdout="\n404", stderr="");
        with mock.patch.object(subprocess, "run", return_value=done) as run {
            self.assertEqual(robots_check._fetch(url, "Claude-User"), ("", 404));
        }
        argv: list[str] = run.call_args.args[0];
        self.assertEqual(argv[0], "curl");
        self.assertEqual(argv[-2:], ["--", url]);
        for option in ("--proto", "--proto-redir") {
            self.assertEqual(argv[argv.index(option) + 1], "=http,https");
            self.assertLess(argv.index(option), argv.index("--"));
        }
    }

    def test_curl_output_is_read_as_utf8_whatever_the_locale {
        real_run: any = subprocess.run;
        write: str = "import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))";
        policy: str = STAR + "Disallow: /職涯貼士/\n";
        not_found: str = "<html lang=\"tr\"><body>Merkezi Kayıt Kuruluşu A.Ş.</body></html>";
        cases: list[tuple[str, str, int, int, str]] = [
            (
                "https://tr.indeed.example/cmp/x/reviews",
                policy,
                200,
                0,
                "robots.txt permits this path",
            ),
            ("https://tr.indeed.example/職涯貼士/x", policy, 200, 1, "DISALLOWED"),
            (
                "https://kap.example/tr/sirket-bilgileri",
                not_found,
                404,
                0,
                "no robots.txt published",
            ),
        ];
        for (url, body, status, expected, said) in cases {
            raw: bytes = f"{body}\n{status}".encode("utf-8");
            self.assertRaises(UnicodeDecodeError, raw.decode, "cp1254");

            def fake_curl(argv: list[str], **kwargs: any) -> any {
                if kwargs.get("text") and not kwargs.get("encoding") {
                    kwargs["encoding"] = "cp1254";
                }
                return real_run([sys.executable, "-c", write, raw.hex()], **kwargs);
            }

            with self.subTest(url=url), mock.patch.object(subprocess, "run", fake_curl) {
                (rc, msg) = robots_check.gate(url);
                self.assertEqual(rc, expected, msg);
                self.assertIn(said, msg);
            }
        }
    }

    @unittest.skipUnless(shutil.which("curl"), "curl is not installed")
    def test_real_curl_refuses_a_file_url_through_fetch {
        target: str = (REPO / "tools" / "robots_check.jac").resolve().as_uri();
        with self.assertRaises(RuntimeError) {
            robots_check._fetch(target, "Claude-User");
        }
    }
}
