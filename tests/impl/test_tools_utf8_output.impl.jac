impl run_legacy_stdout(argv, cwd=None, `root=None) -> any {
    env: any = `dict(os.environ, PYTHONIOENCODING="cp1252", PYTHONUTF8="0");
    if `root is not None {
        env = rooted(`root, env);
    }
    command: any = [sys.executable, *map(str, argv)]
        if `str(argv[0]).endswith(".py")
        else [*tool(argv[0]), *map(str, argv[1:])];
    return subprocess.run(command, cwd=cwd, env=env, capture_output=True);
}

impl ToolsWriteUtf8.setUp -> any {
    directory: any = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.tmp = Path(directory.name);
}

impl ToolsWriteUtf8.assert_clean_utf8(proc, expect_code, *needles_, stream="stdout") -> any {
    needles: any = tuple(needles_);
    err: any = proc.stderr.decode("utf-8", "replace");
    self.assertNotIn("UnicodeEncodeError", err);
    self.assertEqual(proc.returncode, expect_code, err);
    text: any = getattr(proc, stream).decode("utf-8");
    for needle in needles {
        self.assertIn(needle, text);
    }
    return text;
}

impl ToolsWriteUtf8.write_state(seen) -> any {
    state: any = self.tmp / "seen_jobs.json";
    state.write_text(
        json.dumps({"version": 1, "seen": seen}, ensure_ascii=False), encoding="utf-8"
    );
    return state;
}

impl ToolsWriteUtf8.entry(company, title) -> any {
    return {
        "title": title,
        "company": company,
        "url": "https://example.com/jobs/123456",
        "portal": "example",
        "status": "new",
        "first_seen": "2026-09-20",
    };
}

impl ToolsWriteUtf8.test_html_report_prints_an_output_path_outside_cp1252 -> any {
    (self.tmp / "job_search_tracker.csv").write_text(
        "date,company,role,status\n2026-10-01,Acme,Dev,applied\n", encoding="utf-8"
    );
    out: any = self.tmp / f"{CYRILLIC}.html";
    proc: any = run_legacy_stdout(["html_report", "--root", self.tmp, "--out", out]);
    self.assert_clean_utf8(proc, 0, CYRILLIC);
    self.assertTrue(out.is_file());
}

impl ToolsWriteUtf8.test_rank_candidates_lists_non_latin_postings -> any {
    state: any = self.write_state({
        "a": self.entry(CYRILLIC, "Инженер"),
        "b": self.entry(CJK, "工程师"),
    });
    proc: any = run_legacy_stdout([
        "rank_state",
        "candidates",
        "--state",
        state,
        "--today",
        "2026-09-21",
    ]);
    out: any = json.loads(self.assert_clean_utf8(proc, 0, CYRILLIC, CJK));
    self.assertEqual(out["eligible"], 2);
}

impl ToolsWriteUtf8.test_rank_apply_prints_the_ranking_for_non_latin_postings -> any {
    state: any = self.write_state({"a": self.entry(CJK, "工程师")});
    results: any = self.tmp / "results.json";
    results.write_text(
        json.dumps([
            {
                "key": "a",
                "status": "scored",
                "scores": {"technical": 80, "experience": 80, "behavioral": 80, "career": 80},
            },
        ]),
        encoding="utf-8",
    );
    proc: any = run_legacy_stdout([
        "rank_state",
        "apply",
        "--results",
        results,
        "--state",
        state,
        "--today",
        "2026-09-21",
    ]);
    out: any = json.loads(self.assert_clean_utf8(proc, 0, CJK));
    self.assertEqual([row["key"] for row in out["ranked"]], ["a"]);
}

impl ToolsWriteUtf8.test_scrape_candidates_lists_non_latin_hits -> any {
    results: any = self.tmp / "hits.json";
    results.write_text(
        json.dumps(
            [{"title": "Инженер", "company": CYRILLIC, "url": "https://example.com/jobs/1"}],
            ensure_ascii=False,
        ),
        encoding="utf-8",
    );
    proc: any = run_legacy_stdout(
        ["scrape_state", "candidates", "--results", results], root=self.tmp
    );
    out: any = json.loads(self.assert_clean_utf8(proc, 0, CYRILLIC));
    self.assertEqual(len(out["selected"]), 1);
}

impl ToolsWriteUtf8.test_job_key_audit_reports_non_latin_entries -> any {
    state: any = self.write_state({f"{CYRILLIC}_Инженер": self.entry(CYRILLIC, "Инженер")});
    proc: any = run_legacy_stdout(["job_key", "--audit", state]);
    self.assertNotIn(b"UnicodeEncodeError", proc.stderr);
    self.assertIn(CYRILLIC, proc.stdout.decode("utf-8"));
}

impl ToolsWriteUtf8.test_salary_lookup_prints_a_company_outside_cp1252 -> any {
    (self.tmp / "salary_data.json").write_text(
        json.dumps(
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
            ensure_ascii=False,
        ),
        encoding="utf-8",
    );
    proc: any = run_legacy_stdout(["salary_lookup", "Żabka"], cwd=self.tmp, root=self.tmp);
    self.assert_clean_utf8(proc, 0, POLISH);
}

impl ToolsWriteUtf8.test_verify_pdf_names_a_non_latin_file_in_its_error -> any {
    missing: any = self.tmp / f"main_{CJK}_engineer.pdf";
    proc: any = run_legacy_stdout(["verify_pdf", missing]);
    self.assert_clean_utf8(proc, 1, CJK, stream="stderr");
}

impl ToolsWriteUtf8.test_verify_layout_reports_a_non_latin_cv_line -> any {
    a4: float = 842.0;
    pages: any = [
        verify_layout.Page(
            height=a4,
            lines=[
                verify_layout.Line(top=100.0, bottom=110.0, left=70.0, height=10.0, text="Profil"),
                verify_layout.Line(top=700.0, bottom=710.0, left=60.0, height=10.0, text=POLISH),
            ],
        ),
        verify_layout.Page(
            height=a4,
            lines=[
                verify_layout.Line(
                    top=80.0, bottom=90.0, left=90.0, height=10.0, text="kontynuacja punktu"
                ),
                verify_layout.Line(top=700.0, bottom=710.0, left=90.0, height=10.0, text="dalej"),
            ],
        ),
    ];
    raw: any = io.BytesIO();
    legacy: any = io.TextIOWrapper(raw, encoding="cp1252");
    with mock.patch.object(verify_layout, "parse_pdf", return_value=pages) {
        with mock.patch.object(sys, "argv", ["verify_layout", __file__]) {
            with mock.patch.object(sys, "stdout", legacy) {
                verify_layout.main();
                legacy.flush();
            }
        }
    }
    self.assertIn(POLISH, raw.getvalue().decode("utf-8"));
}

impl ToolsWriteUtf8.test_salary_converter_names_a_non_latin_worksheet -> any {
    workbook: any = self.tmp / "salary.xlsx";
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

impl ToolsWriteUtf8.test_upstream_triage_handles_non_latin_commit_subjects -> any {
    repo: any = self.tmp / "repo";
    repo.mkdir();
    subprocess.run(["git", "init", "-b", "master"], cwd=repo, check=True, capture_output=True);
    subprocess.run(
        ["git", "config", "user.name", "Test"], cwd=repo, check=True, capture_output=True
    );
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=repo,
        check=True,
        capture_output=True,
    );
    subprocess.run(
        [
            "git",
            "remote",
            "add",
            "upstream",
            "https://github.com/ai-job-search-dev/ai-job-search.git",
        ],
        cwd=repo,
        check=True,
        capture_output=True,
    );
    (repo / "file.txt").write_text("hello\n", encoding="utf-8");
    subprocess.run(["git", "add", "file.txt"], cwd=repo, check=True, capture_output=True);
    subprocess.run(["git", "commit", "-m", "init"], cwd=repo, check=True, capture_output=True);
    (repo / "file.txt").write_text("change\n", encoding="utf-8");
    subprocess.run(["git", "add", "file.txt"], cwd=repo, check=True, capture_output=True);
    msg: any = f"feat: add support for {CYRILLIC}";
    subprocess.run(["git", "commit", "-m", msg], cwd=repo, check=True, capture_output=True);
    subprocess.run(
        ["git", "update-ref", "refs/remotes/upstream/master", "HEAD"],
        cwd=repo,
        check=True,
        capture_output=True,
    );
    subprocess.run(["git", "reset", "--hard", "HEAD~1"], cwd=repo, check=True, capture_output=True);
    proc: any = run_legacy_stdout(["upstream_triage"], cwd=repo);
    self.assert_clean_utf8(proc, 0, CYRILLIC);
}

impl ToolsWriteUtf8.test_fetch_page_prints_non_latin_text -> any {
    import threading;

    class Handler(http.server.BaseHTTPRequestHandler) {
        def do_GET -> any {
            if self.path == "/robots.txt" {
                self.send_response(404);
                self.end_headers();
                return;
            }
            body: any = f"<html><body><h1>{POLISH}</h1><p>{CYRILLIC}</p></body></html>".encode(
                "utf-8"
            );
            self.send_response(200);
            self.send_header("Content-Type", "text/html; charset=utf-8");
            self.send_header("Content-Length", `str(len(body)));
            self.end_headers();
            self.wfile.write(body);
        }

        def log_message(*args_) -> any {
            args: any = tuple(args_);
        }
    }

    server: any = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler);
    thread: any = threading.Thread(target=server.serve_forever, daemon=True);
    thread.start();
    try {
        port: any = server.server_address[1];
        out: any = self.tmp / "saved.html";
        proc: any = run_legacy_stdout([
            "fetch_page",
            f"http://127.0.0.1:{port}/posting",
            "--text",
            "--out",
            out,
        ]);
        self.assert_clean_utf8(proc, 0, POLISH, CYRILLIC);
    } finally {
        server.shutdown();
        server.server_close();
    }
}

impl ToolsWriteUtf8.test_robots_check_runs_cleanly -> any {
    import threading;

    class Handler(http.server.BaseHTTPRequestHandler) {
        def do_GET -> any {
            self.send_response(404);
            self.end_headers();
        }

        def log_message(*args__) -> any {
            args: any = tuple(args__);
        }
    }

    server: any = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler);
    thread: any = threading.Thread(target=server.serve_forever, daemon=True);
    thread.start();
    try {
        port: any = server.server_address[1];
        proc: any = run_legacy_stdout(["robots_check", f"http://127.0.0.1:{port}/jobs/{POLISH}"]);
        self.assert_clean_utf8(proc, 0, "ALLOWED");
    } finally {
        server.shutdown();
        server.server_close();
    }
}
