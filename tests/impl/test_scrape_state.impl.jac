impl ScrapeStateTests.setUp -> any {
    self.temp = tempfile.TemporaryDirectory();
    self.addCleanup(self.temp.cleanup);
    self.root = Path(self.temp.name);
    self.state = self.root / "job_scraper" / "seen_jobs.json";
    self.tracker = self.root / "tracker.csv";
    self.results = self.root / "results.json";
}

impl ScrapeStateTests.run_tool(command, jobs) -> any {
    self.results.write_text(json.dumps(jobs), encoding="utf-8");
    args: any = argparse.Namespace(
        command=command, results=self.results, state=self.state, tracker=self.tracker
    );
    output: any = io.StringIO();
    with contextlib.redirect_stdout(output) {
        self.assertEqual(scrape_state.run(args), 0);
    }
    return json.loads(output.getvalue());
}

impl ScrapeStateTests.test_candidates_excludes_history_tracker_and_repeated_hits_before_detail -> any {
    old: any = {
        f"old_{i}": {"title": f"Old {i}", "company": "Archive", "url": f"https://jobs.test/{i}"}
        for i in range(1000)
    };
    old["legacy_key"] = {"title": "Engineer", "company": "Acme", "url": "https://jobs.test/old"};
    self.state.parent.mkdir();
    self.state.write_text(json.dumps({"seen": old}), encoding="utf-8");
    self.tracker.write_text("date,company,role\n2026-10-21,Tracked,Analyst\n", encoding="utf-8");
    jobs: any = [
        {"title": "Engineer", "company": "Acme", "url": "https://jobs.test/old"},
        {"title": "Analyst", "company": "Tracked", "url": "https://jobs.test/tracked"},
        {"title": "Builder", "company": "Fresh", "url": "https://jobs.test/fresh"},
        {"title": "Builder", "company": "Fresh", "url": "https://jobs.test/fresh"},
    ];
    out: any = self.run_tool("candidates", jobs);
    self.assertEqual(out["selected"], [jobs[2]]);
    self.assertEqual(
        (out["already_seen"], out["already_applied"], out["repeated_in_batch"]), (1, 1, 1)
    );
    self.assertNotIn("Old 999", json.dumps(out));
}

impl ScrapeStateTests.test_one_malformed_portal_hit_does_not_stop_other_candidates -> any {
    valid: any = {"title": "Builder", "company": "Fresh", "url": "https://jobs.test/fresh"};
    out: any = self.run_tool(
        "candidates", [valid, {"company": "Nobody", "url": "https://jobs.test/bad"}, None]
    );
    self.assertEqual(out["selected"], [valid]);
    self.assertEqual([item["index"] for item in out["invalid"]], [1, 2]);
}

impl ScrapeStateTests.test_unnamed_employer_is_a_posting_not_a_malformed_hit -> any {
    extra: any = {
        "first_seen": "2026-10-21",
        "posted_date": None,
        "deadline": None,
        "fit": "medium",
        "status": "new",
        "portal": "freehire-search",
        "source": "cli",
    };
    unnamed: any = {
        "title": "Backend Engineer",
        "company": None,
        "url": "https://jobs.test/unnamed",
        **extra,
    };
    out: any = self.run_tool(
        "candidates", [unnamed, {"title": "Builder", "company": 7, "url": "https://jobs.test/x"}]
    );
    self.assertEqual(out["selected"], [unnamed]);
    self.assertEqual([item["index"] for item in out["invalid"]], [1]);
    self.assertIn("non-string company", out["invalid"][0]["error"]);

    out = self.run_tool("store", [unnamed]);
    self.assertEqual(out["added"], ["unknown-company_backend-engineer"]);
    seen: any = json.loads(self.state.read_text(encoding="utf-8"))["seen"];
    self.assertIsNone(seen["unknown-company_backend-engineer"]["company"]);
    out = self.run_tool("candidates", [`dict(unnamed, url="https://jobs.test/unnamed/")]);
    self.assertEqual((out["selected"], out["already_seen"]), ([], 1));
}

impl ScrapeStateTests.test_store_adds_only_new_jobs_and_preserves_ranked_history -> any {
    old: any = {
        "legacy_key": {
            "title": "Engineer",
            "company": "Acme",
            "url": "https://jobs.test/old",
            "status": "ranked",
            "rank_score": 91,
        },
    };
    self.state.parent.mkdir();
    self.state.write_text(json.dumps({"seen": old}), encoding="utf-8");
    fresh: any = {
        "title": "Builder",
        "company": "Fresh",
        "url": "https://jobs.test/fresh",
        "first_seen": "2026-10-21",
        "posted_date": None,
        "deadline": None,
        "fit": "high",
        "status": "new",
        "portal": "example-search",
        "source": "cli",
        "location": "Remote",
    };
    out: any = self.run_tool("store", [fresh, {**fresh, "url": "https://jobs.test/another"}]);
    self.assertEqual(out["added"], ["fresh_builder"]);
    stored: any = json.loads(self.state.read_text(encoding="utf-8"))["seen"];
    self.assertEqual(stored["legacy_key"], old["legacy_key"]);
    self.assertEqual(stored["fresh_builder"], fresh);
}

impl ScrapeStateTests.test_candidates_and_store_fold_hits_that_share_a_canonical_key -> any {
    old: any = {
        "fresh_developpeur-python": {
            "title": "Développeur Python",
            "company": "Fresh",
            "url": "https://jobs.test/fr",
        },
    };
    self.state.parent.mkdir();
    self.state.write_text(json.dumps({"seen": old}), encoding="utf-8");
    extra: any = {
        "first_seen": "2026-10-21",
        "posted_date": None,
        "deadline": None,
        "fit": "medium",
        "status": "new",
        "portal": "jobindex-search",
        "source": "cli",
    };
    jobs: any = [
        {"title": "Developpeur Python", "company": "Fresh", "url": "https://jobs.test/en", **extra},
        {"title": "Builder", "company": "Fresh", "url": "https://jobs.test/build", **extra},
        {
            "title": "Développeur Python",
            "company": "Fresh",
            "url": "https://jobs.test/fr2",
            **extra,
        },
        {
            "title": "DEVELOPPEUR PYTHON",
            "company": "Fresh",
            "url": "https://jobs.test/en2",
            **extra,
        },
    ];
    out: any = self.run_tool("candidates", jobs);
    self.assertEqual(out["selected"], [jobs[1]]);
    self.assertEqual((out["already_seen"], out["repeated_in_batch"]), (3, 0));

    out = self.run_tool("store", jobs);
    self.assertEqual(out["added"], ["fresh_builder"]);
    self.assertEqual(out["already_seen"], 3);
    seen: any = json.loads(self.state.read_text(encoding="utf-8"))["seen"];
    self.assertEqual(sorted(seen), ["fresh_builder", "fresh_developpeur-python"]);
    self.assertEqual(seen["fresh_developpeur-python"]["title"], "Développeur Python");
}

impl ScrapeStateTests.test_c_sharp_and_c_plus_plus_titles_are_different_postings -> any {
    base: any = {
        "company": "Acme",
        "first_seen": "2026-10-21",
        "posted_date": None,
        "deadline": None,
        "fit": "high",
        "status": "new",
        "portal": "example-search",
        "source": "cli",
    };
    cpp: any = {**base, "title": "C++ Developer", "url": "https://jobs.test/1111111"};
    self.assertEqual(len(self.run_tool("store", [cpp])["added"]), 1);
    csharp: any = {**base, "title": "C# Developer", "url": "https://jobs.test/2222222"};
    out: any = self.run_tool("candidates", [csharp]);
    self.assertEqual(out["selected"], [csharp]);
    self.assertEqual(len(self.run_tool("store", [csharp])["added"]), 1);
}

impl ScrapeStateTests.test_store_creates_missing_history_and_rejects_partial_entries_without_writing -> any {
    good: any = {
        "title": "Builder",
        "company": "Fresh",
        "url": "https://jobs.test/fresh",
        "first_seen": "2026-10-21",
        "posted_date": None,
        "deadline": None,
        "fit": "high",
        "status": "new",
        "portal": "example-search",
        "source": "cli",
    };
    with self.assertRaisesRegex(ValueError, "invalid portal or source") {
        self.run_tool(
            "store",
            [good, {**good, "title": "Analyst", "url": "https://jobs.test/other", "source": None}],
        );
    }
    self.assertFalse(self.state.exists());
    self.assertEqual(self.run_tool("store", [good])["added"], ["fresh_builder"]);
    self.assertIn("fresh_builder", json.loads(self.state.read_text(encoding="utf-8"))["seen"]);
}

impl ScrapeStateTests.test_history_counts_portal_and_legacy_host_without_emitting_entries -> any {
    self.state.parent.mkdir();
    self.state.write_text(
        json.dumps({
            "seen": {
                "one": {"portal": "example-search", "url": "https://jobs.test/1"},
                "two": {"url": "https://careers.jobs.test/2"},
                "three": {"url": "https://other.test/3"},
            },
        }),
        encoding="utf-8",
    );
    args: any = argparse.Namespace(
        command="history", state=self.state, portal="example-search", domain="jobs.test"
    );
    output: any = io.StringIO();
    with contextlib.redirect_stdout(output) {
        self.assertEqual(scrape_state.run(args), 0);
    }
    self.assertEqual(
        json.loads(output.getvalue()), {"portal": "example-search", "prior_entries": 2}
    );
}
