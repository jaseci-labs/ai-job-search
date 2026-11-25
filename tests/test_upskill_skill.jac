import json;
import subprocess;
import unittest;
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
    def test_skill_file_starts_with_its_frontmatter;
    def test_each_section_states_its_rules;
    def test_step2_drops_jobs_rank_vetoed;
    def test_step3_dedupe_names_the_field_ranked_entries_actually_carry;
    def test_lint_skills_passes;
}
