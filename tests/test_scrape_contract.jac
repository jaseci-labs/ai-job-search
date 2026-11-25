import re;
import unittest;
import from pathlib { Path }

glob REPO_ROOT: Path = Path(__file__).resolve().parent.parent,
     SKILL: str = (REPO_ROOT / ".claude" / "skills" / "job-scraper" / "SKILL.md").read_text(
         encoding="utf-8"
     ),
     RANK: str = (REPO_ROOT / ".claude" / "commands" / "rank.md").read_text(encoding="utf-8"),
     PORTAL_CLIS: list[Path] = sorted((REPO_ROOT / ".agents" / "skills").glob("*-search")),
     EMPLOYMENT: str = "**Employment type:**",
     EMPLOYMENT_TYPES: tuple[str, ...] = ("full_time", "part_time", "contract", "freelance");

def contract_fields -> set[str] {
    sentence: any = re.search("Search output already includes ([a-zA-Z0-9\\s,]+)\\.", SKILL);
    if sentence is None {
        raise AssertionError("Step 2 contract sentence not found in job-scraper/SKILL.md");
    }
    names: list[str] = re.sub("\\s+and\\s+", ",", sentence.group(1)).split(",");
    return {name.strip().lower() for name in names if name.strip()};
}

def stored_fields -> set[str] {
    block: any = re.search("Add ALL fetched jobs.*?```json(.*?)```", SKILL, re.DOTALL);
    if block is None {
        raise AssertionError(
            "Step 4 seen_jobs.json schema block not found in job-scraper/SKILL.md"
        );
    }
    return {name for name in re.findall("\"([a-z_]+)\":", block.group(1))};
}

def paragraph(text: str, start: str) -> str {
    return text[text.find(start):].partition("\n\n")[0] if start in text else "";
}

class ScrapeSearchOutputContractTests(unittest.TestCase) {
    def test_step2_contract_sentence_is_found_in_the_scraper_skill {
        self.assertGreaterEqual(contract_fields(), {"title", "company", "location", "date", "url"});
    }

    def test_every_portal_cli_emits_the_step2_contract_fields {
        contract: set[str] = contract_fields();
        failures: list[str] = [];
        for portal in PORTAL_CLIS {
            src: Path = portal / "cli" / "src";
            if not (src / "commands" / "search.ts").exists() {
                failures.append(f"{portal.name}: no cli/src/commands/search.ts");
                continue;
            }
            source: str = "\n".join([
                f.read_text(encoding="utf-8")
                for f in (src / "commands" / "search.ts", src / "helpers.ts")
                if f.exists()
            ]);
            emitted: list[str] = re.findall("^\\s*([a-zA-Z_][a-zA-Z0-9_]*):", source, re.MULTILINE);
            missing: list[str] = sorted([name for name in contract if name not in emitted]);
            if missing {
                failures.append(f"{portal.name}: missing {missing} in search output");
            }
        }
        self.assertEqual([], failures, "; ".join(failures));
    }
}

class SeenJobsSchemaTests(unittest.TestCase) {
    def test_step4_schema_persists_posting_date_and_employment_type {
        self.assertIn("date", contract_fields(), "Step 2 no longer guarantees a posting date");
        for field in ("posted_date", "employment_type") {
            self.assertIn(
                field, stored_fields(), f"Step 4's seen_jobs.json schema stores no {field}"
            );
        }
    }

    def test_schema_lists_every_employment_type_and_null {
        line: str = next(
            l for l in SKILL.splitlines() if l.strip().startswith("\"employment_type\"")
        );
        for value in [f"\"{name}\"" for name in EMPLOYMENT_TYPES] + ["null"] {
            self.assertIn(value, line);
        }
    }

    def test_storage_and_dedup_rules_are_documented {
        rules: list[str] = [
            "`posted_date`",
            "never infer a posting date",
            "never infer an employment type",
            "URL matches any existing `(?:job_scraper/)?seen_jobs\\.json` entry, regardless of\\s+that entry's key",
            "matched by URL or\\s+company\\+title",
        ];
        for rule in rules {
            with self.subTest(rule=rule) {
                self.assertRegex(SKILL, rule);
            }
        }
    }
}

class SeenJobsEmploymentTypeTests(unittest.TestCase) {
    def test_rank_shows_it_as_an_optional_flag_never_a_veto {
        for phrase in ("employment_type", "never a veto", "separator included") {
            self.assertIn(phrase, paragraph(RANK, EMPLOYMENT));
        }
        self.assertIn("(78)**[ · <employment type>]", RANK);
    }

    def test_portal_detail_output_counts_as_a_source {
        self.assertIn("`detail` output", paragraph(SKILL, EMPLOYMENT));
    }
}

class PortalQuerySyntaxTests(unittest.TestCase) {
    def test_step1b_points_at_the_query_syntax_line {
        step1b: any = re.search("#### 1b\\..*?(?=#### 1c\\.)", SKILL, re.DOTALL);
        self.assertIsNotNone(step1b, "Step 1b section not found");
        for phrase in (
            "`Query syntax:`",
            "inside the argument the CLI receives",
            "deduplicate the pool by URL before Step 2",
        ) {
            self.assertIn(phrase, step1b.group(0));
        }
    }

    def test_every_installed_portal_skill_has_a_query_syntax_line {
        missing: list[str] = [
            portal.name
            for portal in PORTAL_CLIS
            if not re.search(
                "^Query syntax:\\s*\\S",
                (portal / "SKILL.md").read_text(encoding="utf-8"),
                re.MULTILINE,
            )
        ];
        self.assertEqual(
            [],
            missing,
            "portal SKILL.md files without a `Query syntax:` line: " + ", ".join(missing),
        );
    }
}
