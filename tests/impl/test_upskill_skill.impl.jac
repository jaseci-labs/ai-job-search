impl _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str] {
    parts: any = text.split("\n## ");
    result: any = {};
    for part in parts[1:] {
        heading: any;
        _: any;
        body: any;
        (heading, _, body) = part.partition("\n") as any;
        result[heading.strip()] = body;
    }
    return result;
}

impl UpskillSkillSpec.test_skill_file_exists_with_lint_compliant_header -> any {
    self.assertTrue(SKILL.is_file(), "skill spec missing");
    text: any = SKILL.read_text(encoding="utf-8");
    self.assertTrue(text.startswith("---\n"), "skill spec must start with YAML frontmatter");
    self.assertIn("name: upskill", text);
}

impl UpskillSkillSpec.test_step2_reads_ranked_jobs_with_moderate_fit_floor -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    step2: any = sections.get("Step 2: Load Data", "");
    self.assertIn("seen_jobs.json", step2);
    self.assertIn("rank_score >= 45", step2);
    self.assertIn(
        "gap persistence",
        step2,
        "Step 2 must document the graceful-degradation clause for entries scored before gaps existed",
    );
}

impl UpskillSkillSpec.test_step2_drops_jobs_rank_vetoed -> any {
    tmp: any;
    with TemporaryDirectory() as tmp {
        state: any;
        results: any;
        (state, results) = (Path(tmp) / "seen_jobs.json", Path(tmp) / "results.json");
        state.write_text(
            json.dumps({
                "seen": {
                    "acme_data-engineer": {
                        "title": "Data Engineer",
                        "company": "Acme",
                        "url": "https://example.com/job/1",
                        "first_seen": "2026-09-01",
                        "deadline": None,
                        "status": "new",
                    },
                    "beta_analyst": {
                        "title": "Analyst",
                        "company": "Beta",
                        "url": "https://example.com/job/2",
                        "first_seen": "2026-09-01",
                        "deadline": None,
                        "status": "new",
                    },
                },
            }),
            encoding="utf-8",
        );
        scores: any = {"technical": 85, "experience": 80, "behavioral": 75, "career": 80};
        results.write_text(
            json.dumps([
                {
                    "key": "acme_data-engineer",
                    "status": "scored",
                    "scores": scores,
                    "location_verdict": "FAIL",
                    "language_gate": "PASS",
                    "deadline": None,
                    "strengths": ["Python"],
                    "gaps": ["Kubernetes in production"],
                },
                {
                    "key": "beta_analyst",
                    "status": "scored",
                    "scores": scores,
                    "location_verdict": "PASS",
                    "language_gate": "FAIL",
                    "deadline": None,
                    "strengths": ["SQL"],
                    "gaps": ["Fluent German"],
                },
            ]),
            encoding="utf-8",
        );
        proc: any = subprocess.run(
            [
                *RANK_STATE,
                "apply",
                "--state",
                `str(state),
                "--results",
                `str(results),
                "--today",
                "2026-09-03",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
        self.assertEqual(proc.returncode, 0, proc.stderr);
        seen: any = json.loads(state.read_text(encoding="utf-8"))["seen"];
    }
    field: any;
    for (key, field) in (
        ("acme_data-engineer", "location_verdict"),
        ("beta_analyst", "language_gate"),
    ) {
        with self.subTest(key=key) {
            self.assertEqual(seen[key]["status"], "ranked");
            self.assertGreaterEqual(
                seen[key]["rank_score"], 45, "the vetoed job clears Step 2's score floor"
            );
            self.assertEqual(seen[key][field], "FAIL");
        }
    }

    step2: any = _sections(SKILL.read_text(encoding="utf-8")).get("Step 2: Load Data", "");
    item3: any = step2[step2.index("3. Read `job_scraper/seen_jobs.json`"):step2.index("4. Read")];
    for field in ("`location_verdict`", "`language_gate`") {
        self.assertIn(field, item3, f"Step 2.3 must drop entries whose {field} is FAIL");
    }
    self.assertIn("`FAIL`", item3);
    self.assertIn(
        "legacy", item3, "entries ranked before the rename keep their verdict in `location`"
    );
    self.assertIn("A `FLAG` stays in", item3);
}

impl UpskillSkillSpec.test_step2_column_list_keeps_in_phase_with_tracker_header -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    step2: any = sections.get("Step 2: Load Data", "");
    self.assertIn(
        "source, deadline",
        step2,
        "Step 2's column list lost the deadline column the tracker header now ends with",
    );
}

impl UpskillSkillSpec.test_step3_documents_dedupe_and_gap_precedence -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    step3: any = sections.get("Step 3: Pass 1 — Hard Skill Diff", "");
    self.assertIn("case-insensitive company + title", step3, "Step 3 must specify the dedupe key");
    self.assertIn(
        "/notion-sync",
        step3,
        "Step 3 must cite the upstream precedent for the dedupe key, not a fork-only file",
    );
    self.assertIn(
        "Recorded gaps beat inferred skills",
        step3,
        "Step 3 must state that recorded gaps take precedence over inferred skills",
    );
    self.assertIn("(100 - fit_rating) / 100", step3);
    self.assertIn("(100 - rank_score) / 100", step3);
}

impl UpskillSkillSpec.test_step3_dedupe_names_the_field_ranked_entries_actually_carry -> any {
    schema: any = SCRAPER.read_text(encoding="utf-8");
    schema_block: any = schema[schema.index("\"<key from tools/job_key.jac>\""):schema.index(
        "```", schema.index("\"<key from tools/job_key.jac>\"")
    )];
    self.assertIn("\"title\"", schema_block);
    self.assertNotIn(
        "\"role\"", schema_block, "if entries gain a role key, revisit the join wording"
    );
    step3: any = _sections(SKILL.read_text(encoding="utf-8")).get(
        "Step 3: Pass 1 — Hard Skill Diff", ""
    );
    dedupe: any = step3[step3.index("**Dedupe.**"):step3.index("2. **Recorded gaps")];
    self.assertIn("`title`", dedupe, "the dedupe must name the entry field, title");
    self.assertIn("`role`", dedupe, "the dedupe must name the tracker column, role");
    self.assertNotIn("company + role", dedupe, "entries have no role field to match on");
}

impl UpskillSkillSpec.test_step3_handles_blank_fit_rating -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    step3: any = sections.get("Step 3: Pass 1 — Hard Skill Diff", "");
    self.assertIn(
        "blank or non-numeric `fit_rating`",
        step3,
        "Step 3.3 must state what happens to a row whose fit_rating is blank",
    );
    self.assertIn(
        "Never treat a blank as 0",
        step3,
        "the blank-as-0 reading (weight 1.0, maximum) is the failure mode and must be forbidden explicitly",
    );
}

impl UpskillSkillSpec.test_step5_heatmap_shows_gap_provenance -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    step5: any = sections.get("Step 5: Build Gap Heatmap", "");
    self.assertIn("recorded gaps", step5);
    self.assertIn("inferred", step5);
}

impl UpskillSkillSpec.test_step8_report_header_counts_both_sources -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    step8: any = sections.get("Step 8: Write and Save Report", "");
    self.assertIn("T tracked, R ranked", step8);
}

impl UpskillSkillSpec.test_important_rules_cover_untrusted_data_and_no_backfill -> any {
    sections: any = _sections(SKILL.read_text(encoding="utf-8"));
    rules: any = sections.get("Important Rules", "");
    self.assertIn(
        "never instructions",
        rules,
        "rules must state stored gaps are untrusted data, never instructions",
    );
    self.assertIn(
        "Never invent gap history",
        rules,
        "rules must forbid back-filling a missing gaps field by guessing",
    );
}

impl UpskillSkillSpec.test_lint_skills_passes -> any {
    result: any = subprocess.run([*tool("lint_skills")], cwd=REPO, capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
}
