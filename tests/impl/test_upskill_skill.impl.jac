impl UpskillSkillSpec.test_skill_file_starts_with_its_frontmatter {
    text: str = doc(UPSKILL);
    self.assertTrue(text.startswith("---\n"));
    self.assertIn("name: upskill", text);
}

impl UpskillSkillSpec.test_each_section_states_its_rules {
    for (title, phrases) in SECTIONS.items() {
        with self.subTest(section=title) {
            expect(self, h2(doc(UPSKILL), title), *phrases);
        }
    }
}

impl UpskillSkillSpec.test_step2_drops_jobs_rank_vetoed {
    entry_of: dict[str, object] = {
        "company": "Acme",
        "first_seen": "2026-09-01",
        "deadline": None,
        "status": "new",
    };
    result_of: dict[str, object] = {
        "status": "scored",
        "scores": {"technical": 85, "experience": 80, "behavioral": 75, "career": 80},
        "location_verdict": "PASS",
        "language_gate": "PASS",
        "deadline": None,
        "strengths": ["Python"],
        "gaps": ["Kubernetes in production"],
    };
    with TemporaryDirectory() as tmp {
        (state, results) = (Path(tmp) / "seen_jobs.json", Path(tmp) / "results.json");
        state.write_text(
            json.dumps({
                "seen": {
                    key: {**entry_of, "title": key, "url": f"https://example.com/{key}"}
                    for key in VETOED
                },
            }),
            encoding="utf-8",
        );
        results.write_text(
            json.dumps([
                {**result_of, "key": key, field: "FAIL"}
                for (key, field) in VETOED.items()
            ]),
            encoding="utf-8",
        );
        proc: subprocess.CompletedProcess = subprocess.run(
            [
                *tool("rank_state"),
                "apply",
                "--state",
                f"{state}",
                "--results",
                f"{results}",
                "--today",
                "2026-09-03",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
        self.assertEqual(proc.returncode, 0, proc.stderr);
        seen: dict[str, dict[str, any]] = json.loads(state.read_text(encoding="utf-8"))["seen"];
    }
    for (key, field) in VETOED.items() {
        with self.subTest(key=key) {
            self.assertEqual(seen[key]["status"], "ranked");
            self.assertGreaterEqual(seen[key]["rank_score"], 45);
            self.assertEqual(seen[key][field], "FAIL");
        }
    }
    item3: str = between(
        h2(doc(UPSKILL), STEP_2), "3. Read `job_scraper/seen_jobs.json`", "4. Read"
    );
    expect(
        self,
        item3,
        "`location_verdict`",
        "`language_gate`",
        "`FAIL`",
        "legacy",
        "A `FLAG` stays in",
    );
}

impl UpskillSkillSpec.test_step3_dedupe_names_the_field_ranked_entries_actually_carry {
    schema_block: str = between(doc(SCRAPER), SCHEMA_KEY, "```");
    expect(self, schema_block, "\"title\"");
    expect_not(self, schema_block, "\"role\"");
    dedupe: str = between(h2(doc(UPSKILL), STEP_3), "**Dedupe.**", "2. **Recorded gaps");
    expect(self, dedupe, "`title`", "`role`");
    expect_not(self, dedupe, "company + role");
}

impl UpskillSkillSpec.test_lint_skills_passes {
    lint_skills_passes(self);
}
