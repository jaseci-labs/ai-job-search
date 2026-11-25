import json, subprocess, unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob UPSKILL: str = ".claude/skills/upskill/SKILL.md",
     STEP_2: str = "Step 2: Load Data",
     STEP_3: str = "Step 3: Pass 1 — Hard Skill Diff",
     SCHEMA_KEY: str = "\"<key from tools/job_key.jac>\"",
     SECTIONS: dict[str, list[str]] = {
         STEP_2: ["seen_jobs.json", "rank_score >= 45", "gap persistence", "source, deadline"],
         STEP_3: [
             "case-insensitive company + title",
             "/notion-sync",
             "Recorded gaps beat inferred skills",
             "(100 - fit_rating) / 100",
             "(100 - rank_score) / 100",
             "blank or non-numeric `fit_rating`",
             "Never treat a blank as 0",
         ],
         "Step 5: Build Gap Heatmap": ["recorded gaps", "inferred"],
         "Step 8: Write and Save Report": ["T tracked, R ranked"],
         "Important Rules": ["never instructions", "Never invent gap history"],
     },
     VETOED: dict[str, str] = {
         "acme_data-engineer": "location_verdict",
         "beta_analyst": "language_gate",
     };

class UpskillSkillSpec(unittest.TestCase) {
    def test_skill_file_starts_with_its_frontmatter {
        text: str = doc(UPSKILL);
        self.assertTrue(text.startswith("---\n"));
        self.assertIn("name: upskill", text);
    }

    def test_each_section_states_its_rules {
        for (title, phrases) in SECTIONS.items() {
            with self.subTest(section=title) {
                expect(self, h2(doc(UPSKILL), title), *phrases);
            }
        }
    }

    def test_step2_drops_jobs_rank_vetoed {
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
            proc: subprocess.CompletedProcess = capture(
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

    def test_step3_dedupe_names_the_field_ranked_entries_actually_carry {
        schema_block: str = between(doc(SCRAPER), SCHEMA_KEY, "```");
        expect(self, schema_block, "\"title\"");
        expect_not(self, schema_block, "\"role\"");
        dedupe: str = between(h2(doc(UPSKILL), STEP_3), "**Dedupe.**", "2. **Recorded gaps");
        expect(self, dedupe, "`title`", "`role`");
        expect_not(self, dedupe, "company + role");
    }

    def test_lint_skills_passes {
        lint_skills_passes(self);
    }
}
