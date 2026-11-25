import fnmatch;
import re;
import shutil;
import tempfile;
import unittest;
import from pathlib { Path }

glob TRACKER_HEADER: str = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline",
     DOCS_README: str = "documents/README.md",
     STEP_6B: str = "### Step 6b: Record the Application",
     STEP_3B: str = "### Step 3b: Record the Application",
     OUTCOME_1: str = "## Step 1: Load State and Identify the Application",
     OUTCOME_3: str = "## Step 3: Archive the Application Materials",
     OUTCOME_4: str = "## Step 4: Update the Tracker",
     INTERVIEW_1: str = "## Step 1: Load the Application Context",
     NAMING: str = "by the **Subfolder naming** rule in `documents/README.md`",
     NO_WIDENING: str = "Never widen those globs to the company alone",
     COMPANY: str = "Acme",
     ROLES: list[str] = ["Data Scientist", "ML Engineer", "ML Engineer II"],
     RULES: dict[str, list[tuple[str, str | None, list[str]]]] = {
         "step 6b records a drafted row": [
             (
                 APPLY,
                 STEP_6B,
                 [
                     "| `status` | `drafted` |",
                     "| `cv_file`, `cover_letter_file` | the two paths listed under \"Files Created\"",
                     "never move it backwards",
                     "undated `redrafted` marker",
                     "Do not modify `job_scraper/seen_jobs.json`",
                 ],
             ),
             (ASSISTANT, STEP_3B, ["`/apply` Step 6b"]),
         ],
         "drafted means drafted to every reader": [
             (HTML_REPORT, None, ["`drafted` → **Drafted**"]),
             (
                 HTML_REPORT,
                 "## Step 2: Compute Summary Stats",
                 ["excluded from every statistic below"],
             ),
             (OUTCOME, "## Step 2b: Follow-Up Branch", ["neither final nor `drafted`"]),
             (OUTCOME, OUTCOME_4, ["overwrite its `date` column with the actual submission date"]),
             (GMAIL_SYNC, None, ["`drafted` rows stay in this set"]),
             (GMAIL_SYNC, "## Step 5", ["`drafted` -> `applied`, otherwise"]),
             (GMAIL_SYNC, "### Step 7a", ["also set `date` to the email's date"]),
             (GMAIL_SYNC, "## Step 9: Staleness Check", ["Skip `drafted` rows here"]),
             (NOTION_SYNC, None, ["omit when the status is `drafted`", "not yet submitted"]),
             (SCRAPER, None, ["do not add a second row"]),
             (APPLY, STEP_6B, ["bare number, 0-100", "append a new row"]),
         ],
         "the posting is archived where every reader looks": [
             (APPLY, "## Step 0: Parse Input", ["full posting text verbatim"]),
             (
                 APPLY,
                 STEP_6B,
                 [
                     "`documents/applications/<company>_<role>/job_posting.md`",
                     "never a fresh fetch",
                     "`/outcome` Step 1.4",
                     "**If the file already exists, leave it**",
                     "keeps the older posting",
                     "left in place rather than written",
                     "never reconstruct it from memory",
                 ],
             ),
             (OUTCOME, OUTCOME_1, ["4. Derive the archive folder name"]),
             (ASSISTANT, "### Step 1: Research & Evaluate Fit", ["full posting text verbatim"]),
             (ASSISTANT, STEP_3B, ["same posting archive"]),
             (OUTCOME, OUTCOME_3, ["if it already exists, leave it"]),
         ],
         "the deadline survives every write": [
             (APPLY, "## Step 0: Parse Input", ["application deadline"]),
             (
                 APPLY,
                 STEP_6B,
                 [
                     "append `,deadline` to the header line only",
                     "Never guess one",
                     "leave an existing deadline alone",
                     "no data row is touched",
                     "read as an empty deadline",
                 ],
             ),
             (
                 OUTCOME,
                 OUTCOME_1,
                 [
                     "append `,deadline` to the header line only",
                     "Deadline urgency",
                     "never chased",
                     "no data row is touched",
                     "read as an empty deadline",
                     "one edit to an existing tracker",
                 ],
             ),
             (OUTCOME, OUTCOME_4, ["preserve every other field of the row"]),
             (GMAIL_SYNC, "### Step 7a: Write Approved Updates", ["preserve every other field"]),
             (
                 NOTION_SYNC,
                 None,
                 [
                     "**Deadline precedence: the tracker wins too**",
                     "tracker `deadline` column",
                     "never reconcile the two by picking the earlier or later date",
                 ],
             ),
             (ASSISTANT, STEP_3B, ["`deadline` is the application deadline"]),
         ],
         "both fallback globs take the full stem": [
             (OUTCOME, OUTCOME_3, [NAMING, NO_WIDENING]),
             (INTERVIEW, INTERVIEW_1, [NAMING, NO_WIDENING]),
         ],
         "the archive name has one rule and every deriver cites it": [
             (
                 DOCS_README,
                 "## applications/",
                 [
                     "not a letter, digit or underscore is dropped",
                     "single path component",
                     "If the derived name is empty",
                 ],
             ),
             (OUTCOME, OUTCOME_1, [NAMING]),
             (
                 APPLY,
                 "### Requirement coverage (both documents)",
                 ["the same rule `/outcome` Step 1.4 uses"],
             ),
             (ASSISTANT, "### Step 2: Tailor CV", [NAMING]),
             (GMAIL_SYNC, "## Step 2: Load State", [NAMING]),
             (INTERVIEW, INTERVIEW_1, [NAMING]),
             (INTERVIEW, "### 6. Logistics", ["archive folder derived in Step 1"]),
             (NOTION_SYNC, "## Step 5: Write the Detail Page", [NAMING]),
         ],
     };

"""The archive name by the Subfolder naming rule of documents/README.md."""
def derive(company: str, role: str) -> str | None {
    name: str = re.sub("[^\\w]", "", f"{company}_{role}".lower().replace(" ", "_"));
    return re.sub("_+", "_", name).strip("_") or None;
}

"""The fallback CV glob a section documents."""
def cv_glob(rel: str, heading: str) -> str {
    found: list[str] = re.findall(
        "`(cv/main_[^`]+|cover_letters/cover_[^`]+)`", section(doc(rel), heading)
    );
    return [g for g in found if "*" in g and g.startswith("cv/")][0];
}

def resolve(pattern: str, role: str) -> str {
    return pattern.replace("<company>_<role>", derive(COMPANY, role) or "").replace(
        "<company>", (derive(COMPANY, "") or "").rstrip("_")
    );
}

def drafted_files(ext: str = ".tex") -> list[str] {
    return [f"cv/main_{derive(COMPANY, r)}{ext}" for r in ROLES];
}

class ApplyRecordsApplication(unittest.TestCase) {
    def test_every_file_states_its_rules {
        for (theme, cases) in RULES.items() {
            with self.subTest(theme=theme) {
                expect_all(self, cases);
            }
        }
    }

    def test_tracker_header_is_the_same_line_in_both_commands_and_ends_with_deadline {
        self.assertTrue(TRACKER_HEADER.endswith(",deadline"));
        for text in (doc(OUTCOME), section(doc(APPLY), STEP_6B)) {
            headers: list[str] = [
                ln.strip()
                for ln in text.splitlines()
                if ln.strip().startswith("date,company,")
            ];
            self.assertEqual(headers[:1], [TRACKER_HEADER]);
        }
    }

    def test_migration_appends_the_headers_own_last_column {
        last_column: str = TRACKER_HEADER.rsplit(",", 1)[1];
        for (rel, heading) in ((APPLY, STEP_6B), (OUTCOME, OUTCOME_1)) {
            expect(self, section(doc(rel), heading), f"append `,{last_column}` to the header line");
        }
    }

    def test_step_runs_before_the_optional_offer_that_ends_the_turn {
        text: str = doc(APPLY);
        self.assertLess(text.index(STEP_6B), text.index("### Application-Form Fields"));
    }

    def test_lint_skills_passes {
        lint_skills_passes(self);
    }

    def test_the_cv_glob_selects_the_row_s_own_role {
        on_disk: list[str] = drafted_files();
        for (rel, heading) in ((OUTCOME, OUTCOME_3), (INTERVIEW, INTERVIEW_1)) {
            pattern: str = cv_glob(rel, heading);
            for (role, expected) in zip(ROLES, on_disk) {
                with self.subTest(file=rel, role=role) {
                    self.assertEqual(fnmatch.filter(on_disk, resolve(pattern, role)), [expected]);
                }
            }
        }
    }

    def test_the_glob_finds_a_non_tex_template {
        on_disk: list[str] = drafted_files(".typ");
        pattern: str = resolve(cv_glob(OUTCOME, OUTCOME_3), ROLES[0]);
        self.assertEqual(fnmatch.filter(on_disk, pattern), [on_disk[0]]);
    }

    def test_archiving_keeps_each_submitted_sources_extension_and_bytes {
        targets: re.Match | None = re.search(
            "\\*\\*`(cv_draft[^`]+)` and `(cover_letter[^`]+)`\\*\\*",
            section(doc(OUTCOME), OUTCOME_3),
        );
        assert targets is not None, "the archive must name both destination sources";
        for (ext, content) in (
            (".tex", b"\\documentclass{article}\n"),
            (".typ", b"#set text(size: 11pt)\n"),
        ) {
            for (directory, stem, target) in (
                ("cv", "main", targets.group(1)),
                ("cover_letters", "cover", targets.group(2)),
            ) {
                with self.subTest(
                    ext=ext, document=directory
                ), tempfile.TemporaryDirectory() as tmp {
                    source: Path = Path(tmp) / directory / f"{stem}_acme_ml-engineer{ext}";
                    source.parent.mkdir();
                    source.write_bytes(content);
                    destination: Path = Path(tmp)
                        / target.replace("<CV_EXT>", ext).replace("<COVER_EXT>", ext);
                    shutil.copyfile(source, destination);
                    self.assertEqual(destination.suffix, source.suffix);
                    self.assertEqual(destination.read_bytes(), content);
                }
            }
        }
    }

    def test_documented_rule_yields_a_single_path_component {
        cases: list[tuple[str, str, str | None]] = [
            ("Novo Nordisk A/S", "Data Scientist", "novo_nordisk_as_data_scientist"),
            ("Acme", "Data Scientist / ML Engineer", "acme_data_scientist_ml_engineer"),
            ("Ørsted A/S", "ML Engineer", "ørsted_as_ml_engineer"),
            ("../..", "Data Scientist", "data_scientist"),
            ("../..", "///", None),
        ];
        for (company, role, expected) in cases {
            with self.subTest(company=company, role=role) {
                self.assertEqual(derive(company, role), expected);
            }
        }
    }
}
