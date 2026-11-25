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
def derive(company: str, role: str) -> str | None;

"""The fallback CV glob a section documents."""
def cv_glob(rel: str, heading: str) -> str;

def resolve(pattern: str, role: str) -> str;

def drafted_files(ext: str = ".tex") -> list[str];

class ApplyRecordsApplication(unittest.TestCase) {
    def test_every_file_states_its_rules;
    def test_tracker_header_is_the_same_line_in_both_commands_and_ends_with_deadline;
    def test_migration_appends_the_headers_own_last_column;
    def test_step_runs_before_the_optional_offer_that_ends_the_turn;
    def test_lint_skills_passes;
    def test_the_cv_glob_selects_the_row_s_own_role;
    def test_the_glob_finds_a_non_tex_template;
    def test_archiving_keeps_each_submitted_sources_extension_and_bytes;
    def test_documented_rule_yields_a_single_path_component;
}
