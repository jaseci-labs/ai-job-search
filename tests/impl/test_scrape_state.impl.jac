impl hit(title: str, company: any, path: str, **more: any) -> dict[str, any] {
    return {"title": title, "company": company, "url": f"https://jobs.test/{path}", **more};
}

impl ScrapeStateTests.setUp {
    temp: tempfile.TemporaryDirectory = tempfile.TemporaryDirectory();
    self.addCleanup(temp.cleanup);
    self.state = Path(temp.name) / "job_scraper" / "seen_jobs.json";
    self.tracker = Path(temp.name) / "tracker.csv";
    self.results = Path(temp.name) / "results.json";
}

impl ScrapeStateTests.seed(seen: dict[str, any]) -> None {
    self.state.parent.mkdir();
    self.state.write_text(json.dumps({"seen": seen}), encoding="utf-8");
}

impl ScrapeStateTests.stored -> dict[str, any] {
    return json.loads(self.state.read_text(encoding="utf-8"))["seen"];
}

impl ScrapeStateTests.call(**fields: any) -> any {
    output: io.StringIO = io.StringIO();
    with contextlib.redirect_stdout(output) {
        self.assertEqual(
            scrape_state.run(argparse.Namespace(state=self.state, tracker=self.tracker, **fields)),
            0,
        );
    }
    return json.loads(output.getvalue());
}

impl ScrapeStateTests.run_tool(command: str, jobs: list[any]) -> any {
    self.results.write_text(json.dumps(jobs), encoding="utf-8");
    return self.call(command=command, results=self.results);
}

impl ScrapeStateTests.test_candidates_excludes_history_tracker_and_repeated_hits_before_detail {
    old: dict[str, any] = {f"old_{i}": hit(f"Old {i}", "Archive", str(i)) for i in range(1000)};
    old["legacy_key"] = hit("Engineer", "Acme", "old");
    self.seed(old);
    self.tracker.write_text("date,company,role\n2026-10-21,Tracked,Analyst\n", encoding="utf-8");
    jobs: list[any] = [
        hit("Engineer", "Acme", "old"),
        hit("Analyst", "Tracked", "tracked"),
        hit("Builder", "Fresh", "fresh"),
        hit("Builder", "Fresh", "fresh"),
    ];
    out: any = self.run_tool("candidates", jobs);
    self.assertEqual(out["selected"], [jobs[2]]);
    self.assertEqual(
        (out["already_seen"], out["already_applied"], out["repeated_in_batch"]), (1, 1, 1)
    );
    self.assertNotIn("Old 999", json.dumps(out));
}

impl ScrapeStateTests.test_one_malformed_portal_hit_does_not_stop_other_candidates {
    valid: dict[str, any] = hit("Builder", "Fresh", "fresh");
    out: any = self.run_tool(
        "candidates", [valid, {"company": "Nobody", "url": "https://jobs.test/bad"}, None]
    );
    self.assertEqual(out["selected"], [valid]);
    self.assertEqual([item["index"] for item in out["invalid"]], [1, 2]);
}

impl ScrapeStateTests.test_unnamed_employer_is_a_posting_not_a_malformed_hit {
    unnamed: dict[str, any] = hit("Backend Engineer", None, "unnamed", **DETAILS);
    out: any = self.run_tool("candidates", [unnamed, hit("Builder", 7, "x")]);
    self.assertEqual(out["selected"], [unnamed]);
    self.assertEqual([item["index"] for item in out["invalid"]], [1]);
    self.assertIn("non-string company", out["invalid"][0]["error"]);
    self.assertEqual(
        self.run_tool("store", [unnamed])["added"], ["unknown-company_backend-engineer"]
    );
    self.assertIsNone(self.stored()["unknown-company_backend-engineer"]["company"]);
    out = self.run_tool("candidates", [dict(unnamed, url="https://jobs.test/unnamed/")]);
    self.assertEqual((out["selected"], out["already_seen"]), ([], 1));
}

impl ScrapeStateTests.test_store_adds_only_new_jobs_and_preserves_ranked_history {
    ranked: dict[str, any] = hit("Engineer", "Acme", "old", status="ranked", rank_score=91);
    self.seed({"legacy_key": ranked});
    fresh: dict[str, any] = hit("Builder", "Fresh", "fresh", **DETAILS, location="Remote");
    out: any = self.run_tool("store", [fresh, {**fresh, "url": "https://jobs.test/another"}]);
    self.assertEqual(out["added"], ["fresh_builder"]);
    self.assertEqual(self.stored(), {"legacy_key": ranked, "fresh_builder": fresh});
}

impl ScrapeStateTests.test_candidates_and_store_fold_hits_that_share_a_canonical_key {
    self.seed({"fresh_developpeur-python": hit("Développeur Python", "Fresh", "fr")});
    jobs: list[any] = [
        hit("Developpeur Python", "Fresh", "en", **DETAILS),
        hit("Builder", "Fresh", "build", **DETAILS),
        hit("Développeur Python", "Fresh", "fr2", **DETAILS),
        hit("DEVELOPPEUR PYTHON", "Fresh", "en2", **DETAILS),
    ];
    out: any = self.run_tool("candidates", jobs);
    self.assertEqual(out["selected"], [jobs[1]]);
    self.assertEqual((out["already_seen"], out["repeated_in_batch"]), (3, 0));
    out = self.run_tool("store", jobs);
    self.assertEqual((out["added"], out["already_seen"]), (["fresh_builder"], 3));
    seen: dict[str, any] = self.stored();
    self.assertEqual(sorted(seen), ["fresh_builder", "fresh_developpeur-python"]);
    self.assertEqual(seen["fresh_developpeur-python"]["title"], "Développeur Python");
}

impl ScrapeStateTests.test_c_sharp_and_c_plus_plus_titles_are_different_postings {
    cpp: dict[str, any] = hit("C++ Developer", "Acme", "1111111", **DETAILS);
    csharp: dict[str, any] = hit("C# Developer", "Acme", "2222222", **DETAILS);
    self.assertEqual(len(self.run_tool("store", [cpp])["added"]), 1);
    self.assertEqual(self.run_tool("candidates", [csharp])["selected"], [csharp]);
    self.assertEqual(len(self.run_tool("store", [csharp])["added"]), 1);
}

impl ScrapeStateTests.test_store_creates_missing_history_and_rejects_partial_entries_without_writing {
    good: dict[str, any] = hit("Builder", "Fresh", "fresh", **DETAILS);
    with self.assertRaisesRegex(ValueError, "invalid portal or source") {
        self.run_tool(
            "store", [good, hit("Analyst", "Fresh", "other", **{**DETAILS, "source": None})]
        );
    }
    self.assertFalse(self.state.exists());
    self.assertEqual(self.run_tool("store", [good])["added"], ["fresh_builder"]);
    self.assertIn("fresh_builder", self.stored());
}

impl ScrapeStateTests.test_history_counts_portal_and_legacy_host_without_emitting_entries {
    self.seed({
        "one": {"portal": "example-search", "url": "https://jobs.test/1"},
        "two": {"url": "https://careers.jobs.test/2"},
        "three": {"url": "https://other.test/3"},
    });
    self.assertEqual(
        self.call(command="history", portal="example-search", domain="jobs.test"),
        {"portal": "example-search", "prior_entries": 2},
    );
}
