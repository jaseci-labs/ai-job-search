import http.server, io, json, os, subprocess, sys, threading, unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest { mock }

glob openpyxl: any;

with entry {
    try {
        import openpyxl;
    } except ImportError {
        openpyxl = None;
    }
}

glob CYRILLIC: str = "Яндекс",
     CJK: str = "腾讯",
     POLISH: str = "Żabka Łódź",
     SCORES: dict[str, int] = {"technical": 80, "experience": 80, "behavioral": 80, "career": 80};

def run_legacy_stdout(argv: list[any], cwd: any = None, path_root: any = None) -> any {
    env: any = os.environ | {"PYTHONIOENCODING": "cp1252", "PYTHONUTF8": "0"};
    if path_root is not None {
        env = rooted(path_root, env);
    }
    return subprocess.run(
        [*tool(argv[0]), *[str(a) for a in argv[1:]]], cwd=cwd, env=env, capture_output=True
    );
}

def posting(company: str, title: str) -> dict[str, str] {
    return {
        "title": title,
        "company": company,
        "url": "https://example.com/jobs/123456",
        "portal": "example",
        "status": "new",
        "first_seen": "2026-09-20",
    };
}

class PostingServer(http.server.BaseHTTPRequestHandler) {
    def do_GET {
        if self.path != "/posting" {
            self.send_response(404);
            self.end_headers();
            return;
        }
        body: bytes = f"<html><body><h1>{POLISH}</h1><p>{CYRILLIC}</p></body></html>".encode(
            "utf-8"
        );
        self.send_response(200);
        self.send_header("Content-Type", "text/html; charset=utf-8");
        self.send_header("Content-Length", str(len(body)));
        self.end_headers();
        self.wfile.write(body);
    }

    def log_message(*args: any) {}
}

class ToolsWriteUtf8(unittest.TestCase) {
    def setUp {
        directory: any = TemporaryDirectory();
        self.addCleanup(directory.cleanup);
        self.tmp = Path(directory.name);
    }

    def write_json(name: str, data: any) -> Path {
        path: Path = self.tmp / name;
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8");
        return path;
    }

    def serve -> int {
        server: any = http.server.ThreadingHTTPServer(("127.0.0.1", 0), PostingServer);
        threading.Thread(target=server.serve_forever, daemon=True).start();
        self.addCleanup(server.server_close);
        self.addCleanup(server.shutdown);
        return server.server_address[1];
    }

    def assert_clean_utf8(
        proc: any, expect_code: int, *needles: str, stream: str = "stdout"
    ) -> str {
        err: str = proc.stderr.decode("utf-8", "replace");
        self.assertNotIn("UnicodeEncodeError", err);
        self.assertEqual(proc.returncode, expect_code, err);
        text: str = getattr(proc, stream).decode("utf-8");
        for needle in needles {
            self.assertIn(needle, text);
        }
        return text;
    }

    def test_html_report_prints_an_output_path_outside_cp1252 {
        (self.tmp / "job_search_tracker.csv").write_text(
            "date,company,role,status\n2026-10-01,Acme,Dev,applied\n", encoding="utf-8"
        );
        out: Path = self.tmp / f"{CYRILLIC}.html";
        proc: any = run_legacy_stdout(["html_report", "--root", self.tmp, "--out", out]);
        self.assert_clean_utf8(proc, 0, CYRILLIC);
        self.assertTrue(out.is_file());
    }

    def test_rank_state_candidates_and_apply_print_non_latin_postings {
        seen: dict[str, any] = {"a": posting(CYRILLIC, "Инженер"), "b": posting(CJK, "工程师")};
        state: Path = self.write_json("seen_jobs.json", {"version": 1, "seen": seen});
        dated: list[any] = ["--state", state, "--today", "2026-09-21"];
        proc: any = run_legacy_stdout(["rank_state", "candidates", *dated]);
        self.assertEqual(json.loads(self.assert_clean_utf8(proc, 0, CYRILLIC, CJK))["eligible"], 2);
        state = self.write_json(
            "seen_jobs.json", {"version": 1, "seen": {"a": posting(CJK, "工程师")}}
        );
        results: Path = self.write_json(
            "results.json", [{"key": "a", "status": "scored", "scores": SCORES}]
        );
        proc = run_legacy_stdout(["rank_state", "apply", "--results", results, *dated]);
        out: any = json.loads(self.assert_clean_utf8(proc, 0, CJK));
        self.assertEqual([row["key"] for row in out["ranked"]], ["a"]);
    }

    def test_scrape_candidates_lists_non_latin_hits {
        results: Path = self.write_json(
            "hits.json",
            [{"title": "Инженер", "company": CYRILLIC, "url": "https://example.com/jobs/1"}],
        );
        proc: any = run_legacy_stdout(
            ["scrape_state", "candidates", "--results", results], path_root=self.tmp
        );
        self.assertEqual(len(json.loads(self.assert_clean_utf8(proc, 0, CYRILLIC))["selected"]), 1);
    }

    def test_job_key_audit_reports_non_latin_entries {
        seen: dict[str, any] = {f"{CYRILLIC}_Инженер": posting(CYRILLIC, "Инженер")};
        state: Path = self.write_json("seen_jobs.json", {"version": 1, "seen": seen});
        proc: any = run_legacy_stdout(["job_key", "--audit", state]);
        self.assertNotIn(b"UnicodeEncodeError", proc.stderr);
        self.assertIn(CYRILLIC, proc.stdout.decode("utf-8"));
    }

    def test_salary_lookup_prints_a_company_outside_cp1252 {
        self.write_json(
            "salary_data.json",
            {
                "metadata": {
                    "source": "fixture",
                    "index_baseline": 100,
                    "index_label": "Index",
                    "baseline_description": "Index 100 = baseline",
                },
                "companies": [
                    {
                        "company": POLISH,
                        "city": "Łódź",
                        "categories": {"all_employees": {"count": 50, "index": 104.0}},
                    },
                ],
            },
        );
        proc: any = run_legacy_stdout(["salary_lookup", "Żabka"], cwd=self.tmp, path_root=self.tmp);
        self.assert_clean_utf8(proc, 0, POLISH);
    }

    def test_verify_pdf_names_a_non_latin_file_in_its_error {
        proc: any = run_legacy_stdout(["verify_pdf", self.tmp / f"main_{CJK}_engineer.pdf"]);
        self.assert_clean_utf8(proc, 1, CJK, stream="stderr");
    }

    def test_verify_layout_reports_a_non_latin_cv_line {
        line: any = lambda (top: float, left: float, text: str) -> any {
            verify_layout.Line(top=top, bottom=top + 10.0, left=left, height=10.0, text=text)
        };
        pages: list[any] = [
            verify_layout.Page(
                height=842.0, lines=[line(100.0, 70.0, "Profil"), line(700.0, 60.0, POLISH)]
            ),
            verify_layout.Page(
                height=842.0,
                lines=[line(80.0, 90.0, "kontynuacja punktu"), line(700.0, 90.0, "dalej")],
            ),
        ];
        raw: io.BytesIO = io.BytesIO();
        legacy: any = io.TextIOWrapper(raw, encoding="cp1252");
        with mock.patch.object(verify_layout, "parse_pdf", return_value=pages), mock.patch.object(
            sys, "argv", ["verify_layout", __file__]
        ), mock.patch.object(sys, "stdout", legacy) {
            verify_layout.main();
            legacy.flush();
        }
        self.assertIn(POLISH, raw.getvalue().decode("utf-8"));
    }

    @unittest.skipUnless(openpyxl, "requires optional openpyxl (installed in CI)")
    def test_salary_converter_names_a_non_latin_worksheet {
        workbook: Path = self.tmp / "salary.xlsx";
        book: any = openpyxl.Workbook();
        try {
            book.active.title = CYRILLIC;
            book.active.append(["Company", "City", "Count", "Index"]);
            book.active.append([CYRILLIC, "Москва", 40, 101.5]);
            book.save(workbook);
        } finally {
            book.close();
        }
        proc: any = run_legacy_stdout([
            "convert_salary_excel",
            workbook,
            "--output",
            self.tmp / "out.json",
        ]);
        self.assert_clean_utf8(proc, 0, CYRILLIC);
    }

    def test_upstream_triage_handles_non_latin_commit_subjects {
        repo: Path = self.tmp / "repo";
        repo.mkdir();
        note: Path = repo / "file.txt";
        git: any = lambda (*args: str) -> any {
            subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)
        };
        git("init", "-b", "master");
        git("config", "user.name", "Test");
        git("config", "user.email", "test@example.com");
        git("remote", "add", "upstream", "https://github.com/ai-job-search-dev/ai-job-search.git");
        for (text, message) in [
            ("hello\n", "init"),
            ("change\n", f"feat: add support for {CYRILLIC}"),
        ] {
            note.write_text(text, encoding="utf-8");
            git("add", "file.txt");
            git("commit", "-m", message);
        }
        git("update-ref", "refs/remotes/upstream/master", "HEAD");
        git("reset", "--hard", "HEAD~1");
        self.assert_clean_utf8(run_legacy_stdout(["upstream_triage"], cwd=repo), 0, CYRILLIC);
    }

    def test_fetch_page_and_robots_check_print_non_latin_text {
        url: str = f"http://127.0.0.1:{self.serve()}";
        proc: any = run_legacy_stdout([
            "fetch_page",
            f"{url}/posting",
            "--text",
            "--out",
            self.tmp / "saved.html",
        ]);
        self.assert_clean_utf8(proc, 0, POLISH, CYRILLIC);
        proc = run_legacy_stdout(["robots_check", f"{url}/jobs/{POLISH}"]);
        self.assert_clean_utf8(proc, 0, "ALLOWED");
    }
}
