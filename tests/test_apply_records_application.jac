import fnmatch;

import re;

import subprocess;

import shutil;

import tempfile;

import sys;

import unittest;

import from pathlib { Path }

glob _HAVE_YAML: any;

glob yaml: any;

glob REPO: any;

glob COMMANDS: any;

glob APPLY: any;

glob OUTCOME: any;

glob GMAIL_SYNC: any;

glob HTML_REPORT: any;

glob INTERVIEW: any;

glob NOTION_SYNC: any;

glob SKILL: any;

glob SCRAPER: any;

glob DOCS_README: any;

glob TRACKER_HEADER: any;

with entry {
    try {
        import yaml;
        _HAVE_YAML = True;
    } except ImportError {
        _HAVE_YAML = False;
    }

    REPO = Path(__file__).resolve().parent.parent;
    COMMANDS = REPO / ".claude" / "commands";
    APPLY = COMMANDS / "apply.md";
    OUTCOME = COMMANDS / "outcome.md";
    GMAIL_SYNC = COMMANDS / "gmail-sync.md";
    HTML_REPORT = COMMANDS / "html-report.md";
    INTERVIEW = COMMANDS / "interview.md";
    NOTION_SYNC = COMMANDS / "notion-sync.md";
    SKILL = REPO / ".claude" / "skills" / "job-application-assistant" / "SKILL.md";
    SCRAPER = REPO / ".claude" / "skills" / "job-scraper" / "SKILL.md";
    DOCS_README = REPO / "documents" / "README.md";

    TRACKER_HEADER = "date,company,sector,role,role_type,channel,status,contact_person,fit_rating,notes,cv_file,cover_letter_file,source,deadline";
}

def section(path, heading) -> any;

class ApplyRecordsApplication(unittest.TestCase) {
    def setUp -> any;

    def test_step_writes_a_drafted_row_with_both_document_paths -> any;

    def test_tracker_header_matches_outcome -> any;

    def test_tracker_header_ends_with_deadline -> any;

    def test_migration_appends_the_headers_own_last_column -> any;

    def test_step_runs_before_the_optional_offer_that_ends_the_turn -> any;

    def test_matched_row_is_never_moved_backwards -> any;

    def test_redraft_marker_is_undated -> any;

    def test_seen_jobs_is_left_alone -> any;

    def test_skill_defers_to_apply_rather_than_restating -> any;
}

class DraftedMeansDraftedToEveryReader(unittest.TestCase) {
    static has CASES: any = [
        (
            HTML_REPORT,
            None,
            "`drafted` → **Drafted**",
            "a status with no bucket is dropped from every statistic",
        ),
        (
            HTML_REPORT,
            "## Step 2: Compute Summary Stats",
            "excluded from every statistic below",
            "the headline count would include applications that were never sent",
        ),
        (
            OUTCOME,
            "## Step 2b: Follow-Up Branch",
            "neither final nor `drafted`",
            "it would chase an employer who received nothing",
        ),
        (
            OUTCOME,
            "## Step 4: Update the Tracker",
            "overwrite its `date` column with the actual submission date",
            "the drafting date would be reported as the application date",
        ),
        (
            GMAIL_SYNC,
            None,
            "`drafted` rows stay in this set",
            "excluding them discards the row that identifies a submitted-but-unrecorded application, which is the recovery #269 asks for",
        ),
        (
            GMAIL_SYNC,
            "## Step 5",
            "`drafted` -> `applied`, otherwise",
            "the acknowledgement is the one email that proves a hand-submitted application was sent; classified as noise, the recovery never fires",
        ),
        (
            GMAIL_SYNC,
            "### Step 7a",
            "also set `date` to the email's date",
            "the row would keep the drafting date after being proved submitted",
        ),
        (
            GMAIL_SYNC,
            "## Step 9: Staleness Check",
            "Skip `drafted` rows here",
            "an unsent draft reported as a forgotten application",
        ),
        (
            NOTION_SYNC,
            None,
            "omit when the status is `drafted`",
            "an 'Applied on' date for a job never applied to",
        ),
        (
            NOTION_SYNC,
            None,
            "not yet submitted",
            "page bodies are write-once, so calling drafts 'submitted documents' is permanent even after /outcome records the real submission",
        ),
        (
            SCRAPER,
            None,
            "do not add a second row",
            "/scrape would duplicate the row Step 3b just wrote",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "bare number, 0-100",
            "/upskill divides by fit_rating, so `72/100` or a verdict word breaks it",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "append a new row",
            "re-applying after a rejection would overwrite the old application",
        ),
    ];

    def test_every_reader_handles_drafted -> any;

    @unittest.skipUnless(
        _HAVE_YAML,
        "PyYAML not installed (the CI Python-test job omits it; the lint job runs lint_skills.jac directly)",
    )
    def test_lint_skills_passes -> any;
}

class ApplyArchivesThePosting(unittest.TestCase) {
    static has CASES: any = [
        (
            APPLY,
            "## Step 0: Parse Input",
            "full posting text verbatim",
            "by Step 6b the model may hold only a summary, so the archive gets a paraphrase - what /outcome Step 3.2 forbids",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "`documents/applications/<company>_<role>/job_posting.md`",
            "the one moment /apply provably holds the posting is spent again, and a pasted posting has no recovery path at all",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "never a fresh fetch",
            "a model that no longer holds the text would re-fetch to comply, the dead-URL path this whole item exists to avoid",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "`/outcome` Step 1.4",
            "the derivation is no longer pinned to /outcome's, so a later edit to either can silently orphan the archive",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "4. Derive the archive folder name",
            "apply.md item 7 defers its folder derivation to /outcome Step 1.4 by number; renumbering Step 1 leaves that citation dangling",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "**If the file already exists, leave it**",
            "re-running /apply to refresh a CV would overwrite the posting that was actually applied against",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "keeps the older posting",
            "the leave-it rule would read as if the folder is always fresh, hiding that a re-application to the same role collides with the old archive",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "left in place rather than written",
            "the skip discards the current posting silently, and /interview preps against the earlier application's posting",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "never reconstruct it from memory",
            "a model that reached Step 6b without the text could satisfy none of item 7's constraints, and would write a remembered posting instead",
        ),
        (
            SKILL,
            "### Step 1: Research & Evaluate Fit",
            "full posting text verbatim",
            "the /scrape path never runs /apply Step 0, so nothing stops it compressing the posting before Step 3b archives it",
        ),
        (
            SKILL,
            "### Step 3b: Record the Application",
            "same posting archive",
            "the /scrape path reaches Step 3b without running /apply, and its closed enumeration of Step 6b's rules would omit the archive write",
        ),
        (
            OUTCOME,
            "## Step 3: Archive the Application Materials",
            "if it already exists, leave it",
            "/outcome would overwrite /apply's archived posting with a re-fetch, the dead-URL branch the /apply write exists to avoid",
        ),
    ];

    def test_posting_is_archived_where_every_reader_looks -> any;
}

class DeadlineSurvivesEveryWrite(unittest.TestCase) {
    static has CASES: any = [
        (
            APPLY,
            "### Step 6b: Record the Application",
            "append `,deadline` to the header line only",
            "a mid-header insert shifts every existing row's values by one position",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "append `,deadline` to the header line only",
            "the two commands must migrate identically, or whichever runs first sets the schema",
        ),
        (
            APPLY,
            "## Step 0: Parse Input",
            "application deadline",
            "Step 6b's value is supposed to come from Step 0's extraction, so the extraction must be stated where the posting text is still held in full",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "Never guess one",
            "the deadline must stay empty when the posting states none - a guessed date is the urgency clock firing on a date nobody set",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "leave an existing deadline alone",
            "absence is not a correction: a run that extracted no deadline must not blank the one /apply already wrote",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "Deadline urgency",
            "a drafted row has nothing applied so the quiet clock must not run on it - the deadline is the only clock that applies, and it must not be omitted",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "never chased",
            "surfacing the deadline must not drag drafted rows into the follow-up offer",
        ),
        (
            OUTCOME,
            "## Step 4: Update the Tracker",
            "preserve every other field of the row",
            "a status update that rewrites the row would blank the deadline column",
        ),
        (
            GMAIL_SYNC,
            "### Step 7a: Write Approved Updates",
            "preserve every other field",
            "the sync path rewrites the row too - it must carry the same preservation rule",
        ),
        (
            NOTION_SYNC,
            None,
            "**Deadline precedence: the tracker wins too**",
            "the tracker's deadline (written from the posting the application was actually built on) must override the scraper's stored value",
        ),
        (
            NOTION_SYNC,
            None,
            "tracker `deadline` column",
            "the Deadine property must name the tracker column as its source",
        ),
        (
            SKILL,
            "### Step 3b: Record the Application",
            "`deadline` is the application deadline",
            "the /scrape path reaches Step 3b without running /apply Step 0, so it must still be told what the field is and where it comes from",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "no data row is touched",
            "a migration that rewrites rows is a different and far riskier change than one that appends to the header line, and only the second was agreed",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "no data row is touched",
            "same rule, stated in both files, because either command may be the one that meets a legacy tracker first",
        ),
        (
            APPLY,
            "### Step 6b: Record the Application",
            "read as an empty deadline",
            "rows written before the migration have no fourteenth field; if that is not stated, a reader may treat the short row as malformed and drop it",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "read as an empty deadline",
            "same rule, stated in both files",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "one edit to an existing tracker",
            "Step 4 forbids restructuring the CSV, so without this the header append reads as a violation of the same command's own rule and an implementer has a documented reason to skip the migration",
        ),
        (
            NOTION_SYNC,
            None,
            "never reconcile the two by picking the earlier or later date",
            "the tracker-wins rule says which source to prefer but does not forbid the plausible-looking min() of the two, which syncs a date the user never applied against",
        ),
    ];

    def test_deadline_survives_every_write -> any;
}

class FallbackGlobFindsOneRolesDocuments(unittest.TestCase) {
    static has COMPANY: any = "Acme";

    static has ROLES: any = ("Data Scientist", "ML Engineer", "ML Engineer II");

    static has CASES: any = [
        (
            OUTCOME,
            "## Step 3: Archive the Application Materials",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "the archive locator must derive the stem by the one documented rule, not invent a second derivation that drifts from it",
        ),
        (
            OUTCOME,
            "## Step 3: Archive the Application Materials",
            "Never widen those globs to the company alone",
            "without the prohibition the next edit relaxes the glob when it finds no match, which is exactly the wrong-file-recorded-as-submitted case",
        ),
        (
            INTERVIEW,
            "## Step 1: Load the Application Context",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "interview's fallback must resolve the same stem /apply wrote",
        ),
        (
            INTERVIEW,
            "## Step 1: Load the Application Context",
            "Never widen those globs to the company alone",
            "prep built from the sibling role's CV is a live-conversation failure",
        ),
    ];

    def test_both_readers_glob_the_full_stem -> any;

    static def globs(path, heading) -> any;

    def resolve(`glob, role) -> any;

    def drafted_files(ext=".tex") -> any;

    def test_the_cv_glob_selects_the_row_s_own_role -> any;

    def test_archiving_keeps_each_submitted_sources_extension_and_bytes -> any;

    def test_the_glob_finds_a_non_tex_template -> any;
}

class ArchiveNameIsOnePathComponent(unittest.TestCase) {
    static has CASES: any = [
        (
            DOCS_README,
            "## applications/",
            "not a letter, digit or underscore is dropped",
            "the character rule is stated nowhere else; without it the naming convention leaves `/` untouched and the archive nests",
        ),
        (
            DOCS_README,
            "## applications/",
            "single path component",
            "the sentence that says why the rule exists; without it the next edit simplifies the rule back to spaces-only",
        ),
        (
            OUTCOME,
            "## Step 1: Load State and Identify the Application",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "Step 1.4 is the derivation every other writer cites; paraphrasing the rule here is how the two copies drifted apart originally",
        ),
        (
            APPLY,
            "### Requirement coverage (both documents)",
            "the same rule `/outcome` Step 1.4 uses",
            "CV and cover-letter filenames use the same unsanitised values; a `/` there sends the draft to a path lualatex never writes a PDF back to, and the Step 4 compile check fails on a phantom path",
        ),
        (
            SKILL,
            "### Step 2: Tailor CV",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "the /scrape path writes its documents before Step 3b consults /apply, so /apply's filename rule cannot protect it",
        ),
        (
            GMAIL_SYNC,
            "## Step 2: Load State",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "gmail-sync both locates and creates archives; its old spaces-only paraphrase would split state across two folders",
        ),
        (
            INTERVIEW,
            "## Step 1: Load the Application Context",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "interview must read the same archive /apply and /outcome wrote",
        ),
        (
            INTERVIEW,
            "### 6. Logistics",
            "archive folder derived in Step 1",
            "interview must reuse its canonical read path when writing the prep pack",
        ),
        (
            NOTION_SYNC,
            "## Step 5: Write the Detail Page",
            "by the **Subfolder naming** rule in `documents/README.md`",
            "notion-sync otherwise reports that the sanitized local archive is absent",
        ),
        (
            DOCS_README,
            "## applications/",
            "If the derived name is empty",
            "dropping untrusted punctuation can produce no component at all, which would write files directly under documents/applications",
        ),
    ];

    def test_the_rule_has_one_home_and_every_deriver_cites_it -> any;

    static def derive(company, role) -> any;

    static has DERIVATIONS: any = [
        ("Novo Nordisk A/S", "Data Scientist", "novo_nordisk_as_data_scientist"),
        ("Acme", "Data Scientist / ML Engineer", "acme_data_scientist_ml_engineer"),
        ("Ørsted A/S", "ML Engineer", "ørsted_as_ml_engineer"),
        ("../..", "Data Scientist", "data_scientist"),
        ("../..", "///", None),
    ];

    def test_documented_rule_yields_a_single_path_component -> any;
}

with entry:__main__ {
    unittest.main();
}
