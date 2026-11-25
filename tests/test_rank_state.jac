import csv, json, unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob TOOL: list[str] = tool("rank_state"),
     TODAY: str = "2026-09-03",
     DIMENSIONS: tuple[str, ...] = ("technical", "experience", "behavioral", "career"),
     RETRY_FIELDS: tuple[str, ...] = ("fetch_attempts", "first_unreachable", "last_fetch_error"),
     ABSENT: str = "<absent>";

def job(**over: any) -> dict[str, any] {
    return {
        "title": "SOC Analyst",
        "company": "Acme",
        "url": "https://example.com/job",
        "first_seen": "2026-08-30",
        "deadline": None,
        "status": "new",
        "portal": "linkedin-search",
        **over,
    };
}

def scored(key: str = "a", score: int | float = 50, **extra: any) -> dict[str, any] {
    return {"key": key, "status": "scored", "scores": dict.fromkeys(DIMENSIONS, score), **extra};
}

def keys(rows: list[dict[str, any]]) -> list[str] {
    return [row["key"] for row in rows];
}

class RankStateCase(unittest.TestCase) {
    def setUp -> None {
        tmp: TemporaryDirectory = TemporaryDirectory();
        self.addCleanup(tmp.cleanup);
        self.tmp = Path(tmp.name);
        self.state = self.tmp / "seen_jobs.json";
    }

    def write_state(seen: dict[str, any]) -> None {
        self.state.write_text(json.dumps({"seen": seen}), encoding="utf-8");
    }

    def read_state -> dict[str, any] {
        return json.loads(self.state.read_text(encoding="utf-8"))["seen"];
    }

    def results(payload: any, name: str = "results.json") -> str {
        path: Path = self.tmp / name;
        path.write_text(json.dumps(payload), encoding="utf-8");
        return str(path);
    }

    def start(*args: str) -> any {
        return capture([*TOOL, *args, "--state", str(self.state)], encoding="utf-8");
    }

    def run_tool(
        *args: str, expect: int = 0, today: str = TODAY, now: str | None = None
    ) -> dict[str, any] {
        proc: any = self.start(*args, "--today", today, *(["--now", now] if now else []));
        self.assertEqual(proc.returncode, expect, proc.stderr);
        return json.loads(proc.stdout);
    }

    def candidates(*args: str, today: str = TODAY) -> dict[str, any] {
        return self.run_tool(
            "candidates", "--tracker", str(self.tmp / "none.csv"), *args, today=today
        );
    }

    def apply(
        results: list[any], *flags: str, expect: int = 0, today: str = TODAY, now: str | None = None
    ) -> dict[str, any] {
        return self.run_tool(
            "apply", "--results", self.results(results), *flags, expect=expect, today=today, now=now
        );
    }

    def fail_fetch(now: str, error: str = "403 after curl retry") -> dict[str, any] {
        return self.apply(
            [{"key": "a", "status": "unreachable", "fetch_error": error}], today=now[:10], now=now
        );
    }
}

class Candidates(RankStateCase) {
    def test_selects_only_new_entries_and_projects_a_compact_row {
        self.write_state({
            "a": job(),
            "b": job(status="ranked", rank_score=70),
            "c": job(status="skipped"),
            "d": job(status="expired"),
        });
        out: dict[str, any] = self.candidates();
        self.assertEqual(keys(out["selected"]), ["a"]);
        self.assertEqual(
            set(out["selected"][0]),
            {"key", "title", "company", "url", "portal", "deadline", "posted_date"},
        );
    }

    def test_status_and_focus_decide_what_is_selected {
        cases: list[tuple[dict[str, any], list[str], list[str]]] = [
            (
                {
                    "a": job(title="Data Scientist"),
                    "b": job(title="SOC Analyst"),
                    "c": job(title="Engineer", strengths=["strong data science match"]),
                },
                ["--focus", "data scien"],
                ["a", "c"],
            ),
            (
                {
                    "a": job(status="ranked"),
                    "b": job(status="expired"),
                    "c": job(status="skipped"),
                    "d": job(status="new"),
                },
                ["--all"],
                ["a", "b", "d"],
            ),
            (
                {
                    "a": job(
                        status="unreachable",
                        fetch_attempts=1,
                        first_unreachable="2026-09-02T09:00:00Z",
                    ),
                    "b": job(status="expired"),
                },
                [],
                ["a"],
            ),
        ];
        for (seen, args, selected) in cases {
            with self.subTest(args=args) {
                self.write_state(seen);
                self.assertEqual(sorted(keys(self.candidates(*args)["selected"])), selected);
            }
        }
    }

    def test_limit_defers_the_rest_and_reports_the_count {
        for (entries, limit, selected) in ((25, "10", 10), (15, "0", 15)) {
            with self.subTest(limit=limit) {
                self.write_state({f"k{i}": job(title=f"Role {i}") for i in range(entries)});
                out: dict[str, any] = self.candidates("--limit", limit);
                self.assertEqual(len(out["selected"]), selected);
                self.assertEqual(out["eligible"], entries);
                self.assertEqual(out["deferred"], entries - selected);
            }
        }
    }

    def test_tracker_exclusion_handles_utf8_bom_and_reordered_columns {
        self.write_state({
            "a": job(company="Acme", title="SOC Analyst"),
            "b": job(company="Other"),
        });
        tracker: Path = self.tmp / "tracker.csv";
        for encoding in ("utf-8", "utf-8-sig") {
            for csv_text in (
                "date,company,role\n2026-08-01,ACME,soc analyst\n",
                "date,company,role\r\n2026-08-01,ACME,soc analyst\r\n",
                "company,role,date\r\nACME,soc analyst,2026-08-01\r\n",
                "role,company,date\r\nsoc analyst,ACME,2026-08-01\r\n",
            ) {
                with self.subTest(encoding=encoding, csv=csv_text) {
                    tracker.write_bytes(csv_text.encode(encoding));
                    out: dict[str, any] = self.run_tool("candidates", "--tracker", str(tracker));
                    self.assertEqual(keys(out["selected"]), ["b"]);
                    self.assertEqual(out["excluded_by_tracker"], 1);
                }
            }
        }
    }

    def test_tracker_exclusion_preserves_unicode_identity {
        header: list[str] = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline".split(
            ","
        );
        cases: list[tuple[str, str, str, str, bool]] = [
            ("Acme", "设计师", "Acme", "工程师", False),
            ("Acme", "工程师", "Acme", "工程师", True),
            ("腾讯", "Engineer", "腾讯", "Engineer", True),
            ("腾讯", "Engineer", "阿里巴巴", "Engineer", False),
            ("Компания", "Инженер", "КОМПАНИЯ", "ИНЖЕНЕР", True),
            ("Café", "Engineer", "Café", "Engineer", True),
            ("Straße", "Engineer", "STRASSE", "Engineer", True),
            ("कला Labs", "Engineer", "कल Labs", "Engineer", False),
            ("Acme, Inc.", "SOC Analyst", "ACME_INC", "soc-analyst", True),
        ];
        tracker: Path = self.tmp / "tracker.csv";
        for (company, role, candidate_company, title, excluded) in cases {
            with self.subTest(tracked=(company, role), candidate=(candidate_company, title)) {
                self.write_state({
                    "candidate": job(company=candidate_company, title=title),
                    "other": job(company="Other", title="Untracked role"),
                });
                with tracker.open("w", encoding="utf-8", newline="") as fh {
                    writer: any = csv.DictWriter(fh, fieldnames=header);
                    writer.writeheader();
                    writer.writerow({
                        "date": TODAY,
                        "company": company,
                        "role": role,
                        "status": "applied",
                    });
                }
                out: dict[str, any] = self.run_tool("candidates", "--tracker", str(tracker));
                self.assertEqual(
                    keys(out["selected"]), ["other"] if excluded else ["candidate", "other"]
                );
                self.assertEqual(out["excluded_by_tracker"], int(excluded));
            }
        }
    }

    def test_tracker_saved_in_a_legacy_code_page_is_reported_not_a_traceback {
        self.write_state({"a": job()});
        tracker: Path = self.tmp / "tracker.csv";
        tracker.write_bytes(
            "date,company,role\r\n2026-08-01,Ørsted,SOC Analyst\r\n".encode("cp1252")
        );
        proc: any = self.start("candidates", "--tracker", str(tracker));
        self.assertEqual(proc.returncode, 1);
        self.assertIn("is not UTF-8 text - re-save it as CSV UTF-8", proc.stderr);
        self.assertNotIn("Traceback", proc.stderr);
    }

    def test_missing_state_file_exits_nonzero {
        proc: any = self.start("candidates", "--tracker", str(self.tmp / "n.csv"));
        self.assertNotEqual(proc.returncode, 0);
        self.assertIn("not found", proc.stderr + proc.stdout);
    }
}

class Sweep(RankStateCase) {
    def test_only_ranked_entries_past_their_deadline_are_retired {
        past: dict[str, any] = job(status="ranked", deadline="2026-09-01");
        cases: list[tuple[dict[str, any], list[str], dict[str, any], dict[str, str]]] = [
            (
                {
                    "past": past,
                    "soon": job(status="ranked", deadline="2026-09-07"),
                    "later": job(status="ranked", deadline="2026-12-01"),
                },
                ["--write"],
                {"newly_expired": ["past"], "closing_soon": ["soon"]},
                {"past": "expired", "soon": "ranked"},
            ),
            ({"a": job(status="ranked")}, ["--write"], {"newly_expired": []}, {"a": "ranked"}),
            (
                {"new_past": job(deadline="2026-09-01"), "rescored": past, "other": past},
                ["--write", "--exclude", "rescored"],
                {"newly_expired": ["other"], "swept": 1},
                {"new_past": "new"},
            ),
            (
                {"a": past, "b": past, "other": past},
                ["--write", "--exclude", "a, b"],
                {"newly_expired": ["other"], "swept": 1},
                {"b": "ranked"},
            ),
            ({"past": past}, [], {"newly_expired": ["past"], "written": False}, {"past": "ranked"}),
        ];
        for (seen, args, want, statuses) in cases {
            with self.subTest(seen=list(seen), args=args) {
                self.write_state(seen);
                out: dict[str, any] = self.run_tool("sweep", *args);
                got: dict[str, any] = {
                    field: keys(out[field]) if isinstance(out[field], list) else out[field]
                    for field in want
                };
                self.assertEqual(got, want);
                after: dict[str, any] = self.read_state();
                self.assertEqual({key: after[key]["status"] for key in statuses}, statuses);
            }
        }
    }

    def test_non_iso_deadlines_are_reported_not_compared {
        self.write_state({
            "asap": job(status="ranked", deadline="ASAP", portal="jobindex-search"),
            "euro": job(status="ranked", deadline="31.08.2026", portal="jobbank-search"),
        });
        out: dict[str, any] = self.run_tool("sweep", "--write");
        self.assertEqual(out["newly_expired"], []);
        self.assertEqual(
            out["unparseable_deadlines"],
            [
                {"key": "asap", "portal": "jobindex-search", "deadline": "ASAP"},
                {"key": "euro", "portal": "jobbank-search", "deadline": "31.08.2026"},
            ],
        );
        self.assertEqual({job["status"] for job in self.read_state().values()}, {"ranked"});
    }
}

class Apply(RankStateCase) {
    def test_a_result_changes_exactly_the_fields_it_should {
        warning: str = "⚠ 1 instruction-like line - review before continuing";
        script: str = "<script>not sanitized on purpose, stored as plain data</script>";
        closed: dict[str, any] = {"key": "a", "status": "expired"};
        retrying: dict[str, any] = job(
            status="unreachable",
            fetch_attempts=2,
            first_unreachable="2026-09-01T09:00:00Z",
            last_fetch_error="timeout",
        );
        retry_cleared: dict[str, str] = dict.fromkeys((*RETRY_FIELDS, "expired_reason"), ABSENT);
        cases: list[tuple[dict[str, any], dict[str, any], dict[str, any]]] = [
            (job(deadline="2026-10-01"), scored(deadline=None), {"deadline": "2026-10-01"}),
            (job(location="FLAG"), scored(), {"location_verdict": "FLAG", "location": ABSENT}),
            (
                job(location="Athens, Greece"),
                scored(location_verdict="PASS"),
                {"location": "Athens, Greece"},
            ),
            (job(language_note="stale"), scored(language_gate="PASS"), {"language_note": ABSENT}),
            (
                job(),
                scored(strengths=["one", "two", "three", "four"], gaps=[script]),
                {"strengths": ["one", "two", "three"], "gaps": [script]},
            ),
            (
                job(status="ranked", strengths=["old strength"], gaps=["old gap"]),
                scored(strengths=["new strength"], gaps=["new gap"]),
                {"strengths": ["new strength"], "gaps": ["new gap"]},
            ),
            (
                job(status="ranked", rank_score=40, strengths=["old"]),
                scored(score=90, strengths=["new"]),
                {"rank_score": 90, "strengths": ["new"]},
            ),
            (retrying, scored(score=60), {"status": "ranked", **retry_cleared}),
            (job(), closed, {"status": "expired"}),
            (retrying, closed, {"status": "expired", **retry_cleared}),
            (job(), scored(), {"guard": ABSENT}),
            (
                job(),
                scored(guard=f"posting_guard: {warning} (1 hidden block removed)"),
                {"guard": f"{warning} (1 hidden block removed)"},
            ),
            (job(), scored(guard=f"posting_guard: {warning}"), {"guard": warning}),
            (job(), scored(guard="posting_guard: clean"), {"guard": "clean"}),
            (
                job(),
                scored(
                    guard="posting_guard: clean (8 hidden blocks removed, none instruction-like)"
                ),
                {"guard": "clean"},
            ),
            (job(status="ranked", guard="⚠ old", rank_score=50), scored(), {"guard": ABSENT}),
            (job(), scored(guard="x" * 500), {"guard": "x" * 200}),
            (job(), scored(guard={"not": "a string"}), {"guard": ABSENT}),
        ];
        for (stored, result, want) in cases {
            with self.subTest(stored=stored, result=result) {
                self.write_state({"a": stored});
                out: dict[str, any] = self.apply([result]);
                after: dict[str, any] = self.read_state()["a"];
                self.assertEqual({field: after.get(field, ABSENT) for field in want}, want);
                if result is closed {
                    self.assertEqual(keys(out["expired"]), ["a"]);
                } else {
                    self.assertEqual(keys(out["ranked"]), ["a"]);
                    self.assertEqual(out["ranked"][0]["guard"], after.get("guard"));
                }
            }
        }
    }

    def test_scored_keys_keep_past_deadlines_out_of_the_shortlist {
        for status in ("new", "ranked", "expired") {
            with self.subTest(status=status) {
                original: dict[str, any] = job(status=status, deadline="2026-09-02");
                if status != "new" {
                    original.update(
                        rank_score=61, rank_date="2026-08-31", strengths=["stored strength"]
                    );
                }
                self.write_state({"a": original});
                selected: list[dict[str, any]] = self.candidates(
                    *([] if status == "new" else ["--all"])
                )["selected"];
                self.assertEqual(keys(selected), ["a"]);
                out: dict[str, any] = self.apply([
                    scored(
                        score=80,
                        deadline=None,
                        location_verdict="PASS",
                        language_gate="PASS",
                        language="en",
                        strengths=["fresh strength"],
                        gaps=[],
                    ),
                ]);
                self.assertEqual(out["ranked"], []);
                self.assertEqual(out["vetoed"], []);
                self.assertEqual(keys(out["expired"]), ["a"]);
                self.assertEqual(self.read_state()["a"], {**original, "status": "expired"});
                swept: dict[str, any] = self.run_tool("sweep", "--write", "--exclude", "a");
                self.assertEqual(swept["swept"], 0);
                self.assertEqual(self.read_state()["a"]["status"], "expired");
            }
        }
    }

    def test_deadline_apply_boundaries_and_dry_run_keep_existing_semantics {
        cases: list[tuple[str | None, str | None, str, str]] = [
            (TODAY, None, "scored", "ranked"),
            ("2026-09-04", None, "scored", "ranked"),
            ("ASAP", None, "scored", "ranked"),
            (None, None, "scored", "ranked"),
            ("2026-09-02", "2026-09-04", "scored", "ranked"),
            (None, None, "expired", "expired"),
            ("2026-09-02", None, "scored", "expired"),
        ];
        for (stored, fresh, status, expected) in cases {
            with self.subTest(stored=stored, fresh=fresh, status=status) {
                self.write_state({"a": job(deadline=stored)});
                before: bytes = self.state.read_bytes();
                results: list[any] = [scored(score=80, status=status, deadline=fresh)];
                dry: dict[str, any] = self.apply(results, "--dry-run");
                self.assertFalse(dry["written"]);
                self.assertEqual(self.state.read_bytes(), before);
                self.assertEqual(keys(dry[expected]), ["a"]);
                self.assertEqual(keys(self.apply(results)[expected]), ["a"]);
                after: dict[str, any] = self.read_state()["a"];
                self.assertEqual(after["status"], expected);
                self.assertEqual(after["deadline"], fresh or stored);
            }
        }
    }

    def test_past_deadline_does_not_bypass_scoring_errors {
        for result in (scored(scores={"technical": 80}), scored("missing", scores={})) {
            with self.subTest(result=result) {
                original: dict[str, any] = job(deadline="2026-09-02");
                self.write_state({"a": original});
                before: bytes = self.state.read_bytes();
                dry: dict[str, any] = self.apply([result], "--dry-run", expect=1);
                self.assertEqual(len(dry["errors"]), 1);
                self.assertEqual(self.state.read_bytes(), before);
                out: dict[str, any] = self.apply([result], expect=1);
                self.assertEqual(len(out["errors"]), 1);
                self.assertEqual(out["expired"], []);
                self.assertEqual(self.read_state()["a"], original);
            }
        }
    }

    def test_weights_bands_and_persisted_fields {
        self.write_state({"a": job()});
        out: dict[str, any] = self.apply([
            scored(
                scores={"technical": 80, "experience": 60, "behavioral": 70, "career": 75},
                location_verdict="PASS",
                language_gate="PASS",
                deadline="2026-09-05",
                strengths=["s1", "s2"],
                gaps=["g1"],
            ),
        ]);
        want: dict[str, any] = {
            "rank_score": 72,
            "rank_verdict": "Good Fit",
            "status": "ranked",
            "rank_date": TODAY,
            "strengths": ["s1", "s2"],
            "gaps": ["g1"],
            "deadline": "2026-09-05",
        };
        stored: dict[str, any] = self.read_state()["a"];
        self.assertEqual({field: stored[field] for field in want}, want);
        self.assertTrue(out["ranked"][0]["urgent"]);
    }

    def test_vetoed_rows_are_separated_from_the_ranking {
        self.write_state({"a": job(), "b": job(), "c": job()});
        out: dict[str, any] = self.apply([
            scored("a", 90, location_verdict="FAIL", guard="clean"),
            scored("b", 90, language_gate="FAIL", language_note="requires fluent Polish"),
            scored("c", 40),
        ]);
        self.assertEqual(sorted(keys(out["vetoed"])), ["a", "b"]);
        self.assertEqual([row["guard"] for row in out["vetoed"]], ["clean", None]);
        self.assertEqual(self.read_state()["a"]["guard"], "clean");
        self.assertEqual(keys(out["ranked"]), ["c"]);
        self.assertEqual(self.read_state()["b"]["language_note"], "requires fluent Polish");
    }

    def test_a_rejected_result_is_an_error_and_never_half_writes_an_entry {
        cases: list[tuple[dict[str, any], str, str]] = [
            (scored("ghost", scores={}), "ghost", "no such key in seen_jobs.json"),
            (scored(scores={"technical": 80}), "a", "experience"),
            ({"key": "a", "status": "unreachble"}, "a", "unknown status 'unreachble'"),
            (scored(score=90, location_verdict="Fail"), "a", "unknown location_verdict 'Fail'"),
            (scored(score=90, language_gate="fail"), "a", "unknown language_gate 'fail'"),
            (scored(score=90, location_verdict="REJECT"), "a", "unknown location_verdict 'REJECT'"),
        ];
        for (result, key, error) in cases {
            with self.subTest(result=result) {
                self.write_state({"a": job()});
                out: dict[str, any] = self.apply([result], expect=1);
                self.assertEqual(keys(out["errors"]), [key]);
                self.assertIn(error, out["errors"][0]["error"]);
                self.assertEqual(out["ranked"], []);
                self.assertEqual(self.read_state(), {"a": job()});
            }
        }
    }

    def test_invalid_scores_report_errors_without_changing_the_entry {
        invalid: tuple[any, ...] = (
            -1,
            101,
            True,
            False,
            float("nan"),
            float("inf"),
            -float("inf"),
            10 ** 400,
        );
        for dimension in DIMENSIONS {
            for value in invalid {
                with self.subTest(dimension=dimension, value=value) {
                    original: dict[str, any] = job(
                        status="ranked", rank_score=70, strengths=["keep"]
                    );
                    self.write_state({"a": original, "b": job()});
                    bad: dict[str, any] = scored();
                    bad["scores"][dimension] = value;
                    out: dict[str, any] = self.apply([bad, scored("b", 80)], expect=1);
                    self.assertEqual(keys(out["errors"]), ["a"]);
                    self.assertIn(dimension, out["errors"][0]["error"]);
                    self.assertEqual(self.read_state()["a"], original);
                    self.assertEqual(keys(out["ranked"]), ["b"]);
                    self.assertEqual(self.read_state()["b"]["rank_score"], 80);
                }
            }
        }
    }

    def test_score_boundaries_and_fractional_scores_remain_valid {
        for (value, expected) in ((0, 0), (100, 100), (72.5, 73)) {
            with self.subTest(value=value) {
                self.write_state({"a": job()});
                self.assertEqual(self.apply([scored(score=value)])["errors"], []);
                self.assertEqual(self.read_state()["a"]["rank_score"], expected);
            }
        }
    }
}

class Unreachable(RankStateCase) {
    def test_a_failed_fetch_is_recorded_as_unreachable_not_expired {
        self.write_state({"a": job()});
        out: dict[str, any] = self.fail_fetch("2026-09-03T09:00:00Z");
        want: dict[str, any] = {
            "status": "unreachable",
            "fetch_attempts": 1,
            "first_unreachable": "2026-09-03T09:00:00Z",
            "last_fetch_error": "403 after curl retry",
        };
        stored: dict[str, any] = self.read_state()["a"];
        self.assertEqual({field: stored[field] for field in want}, want);
        self.assertEqual(keys(out["unreachable"]), ["a"]);
        self.assertEqual(out["unreachable"][0]["fetch_attempts"], 1);
        self.assertEqual(out["expired"], []);
        self.assertEqual(out["gave_up"], []);
    }

    def test_three_failures_inside_48_hours_keep_retrying {
        self.write_state({"a": job()});
        out: dict[str, any] = [
            self.fail_fetch(now)
            for now in ("2026-09-03T09:00:00Z", "2026-09-03T18:00:00Z", "2026-09-05T08:59:00Z")
        ][-1];
        stored: dict[str, any] = self.read_state()["a"];
        self.assertEqual(stored["status"], "unreachable");
        self.assertEqual(stored["fetch_attempts"], 3);
        self.assertEqual(stored["first_unreachable"], "2026-09-03T09:00:00Z");
        self.assertEqual(out["gave_up"], []);
    }

    def test_gives_up_after_three_failures_48_hours_apart {
        self.write_state({"a": job()});
        out: dict[str, any] = [
            self.fail_fetch(now, error)
            for (now, error) in (
                ("2026-09-03T09:00:00Z", "403"),
                ("2026-09-04T09:00:00Z", "timeout"),
                ("2026-09-05T09:00:00Z", "login wall"),
            )
        ][-1];
        stored: dict[str, any] = self.read_state()["a"];
        self.assertEqual(stored["status"], "expired");
        self.assertEqual(stored["expired_reason"], "unreachable");
        self.assertEqual(out["unreachable"], []);
        self.assertEqual(
            out["gave_up"],
            [
                {
                    "key": "a",
                    "title": "SOC Analyst",
                    "company": "Acme",
                    "url": "https://example.com/job",
                    "fetch_attempts": 3,
                    "last_fetch_error": "login wall",
                },
            ],
        );
        self.assertEqual(self.candidates(today="2026-09-06")["selected"], []);
    }

    def test_a_failed_fetch_past_the_stored_deadline_still_expires {
        self.write_state({
            "a": job(
                deadline="2026-09-20",
                status="unreachable",
                fetch_attempts=1,
                first_unreachable="2026-10-04T09:00:00Z",
                last_fetch_error="timeout",
            ),
        });
        out: dict[str, any] = self.fail_fetch("2026-10-05T09:00:00Z");
        stored: dict[str, any] = self.read_state()["a"];
        self.assertEqual(stored["status"], "expired");
        for field in (*RETRY_FIELDS, "expired_reason") {
            self.assertNotIn(field, stored);
        }
        self.assertEqual(keys(out["expired"]), ["a"]);
        self.assertEqual(out["unreachable"], []);
        self.assertEqual(out["gave_up"], []);
    }

    def test_fetch_error_is_stored_as_bounded_plain_text {
        self.write_state({"a": job()});
        self.fail_fetch("2026-09-03T09:00:00Z", error="x" * 500);
        self.assertLessEqual(len(self.read_state()["a"]["last_fetch_error"]), 200);
    }

    def test_malformed_results_are_errors_not_a_traceback {
        self.write_state({"a": job(), "b": job(title="Other")});
        out: dict[str, any] = self.apply(
            [
                7,
                "a",
                {"key": ["a"], "scores": {}},
                {"key": "a", "scores": [90, 80]},
                {"key": "b", "scores": dict.fromkeys(DIMENSIONS, 80)},
            ],
            expect=1,
        );
        self.assertEqual(
            [e["error"] for e in out["errors"]],
            [
                "result is not an object",
                "result is not an object",
                "no such key in seen_jobs.json",
                "scores must be an object",
            ],
        );
        self.assertEqual(keys(out["ranked"]), ["b"]);
        self.assertEqual(self.read_state()["a"]["status"], "new");
    }

    def test_non_object_entry_is_reported_not_a_traceback {
        seen: dict[str, any] = {"a": job(), "b": "oops"};
        self.write_state(seen);
        for args in (
            ("candidates", "--tracker", str(self.tmp / "none.csv")),
            ("sweep",),
            (
                "apply",
                "--results",
                self.results([{"key": "b", "status": "unreachable"}], "bad.json"),
            ),
            ("apply", "--results", self.results([scored(score=80)], "good.json")),
        ) {
            with self.subTest(args=args) {
                proc: any = self.start(*args, "--today", TODAY);
                self.assertEqual(proc.returncode, 1);
                self.assertIn("entry is not an object: b", proc.stderr);
                self.assertNotIn("Traceback", proc.stderr);
            }
        }
        self.assertEqual(self.read_state(), seen);
    }
}

with entry:__main__ {
    unittest.main();
}
