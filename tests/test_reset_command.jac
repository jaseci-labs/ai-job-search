"""Guards for /reset's two scopes: documents and profile.

Both scopes have the same failure mode - /reset promises a clean slate it
does not deliver, because something that writes personal data is missing
from the Step 1 preview the user confirms and from the Step 3 execution.

Documents scope: /reset ends its documents pass by telling the user "The
`documents/` folder is now empty." That statement is only true if every
personal-data drop folder is actually covered by both the Step 1 preview
and the Step 3 delete block. `documents/postings/` was missing from both
while being documented in documents/README.md and protected as personal
data by tools/security_guards.jac (review finding F26, 2026-08-19), so a
reset silently kept the user's hand-pasted job postings.

Profile scope: the same class of gap, one scope over. /setup Step 3
populates six skill files, and /reset profile cleared four of them -
`04-job-evaluation.md` (the user's match areas, career goals, financial
situation and schedule constraints) was listed by name as containing
"framework rules, not candidate data", and `job-scraper/search-queries.md`
(their role titles, city and commute tiers) appeared nowhere in reset.md.
Both are tracked and unignored, and CI's placeholder-integrity job guards
04-job-evaluation.md under "personal data may have been committed", so a
"blank" profile left /rank scoring against the old skills and /scrape
running the old city.

Both file lists are derived - the documents folders from the repository
tree, the profile files from /setup Step 3's own headings - so a new drop
folder or a new /setup target fails this test until /reset covers it.
"""

import builtins;

import re;

import subprocess;

import unittest;

import from pathlib { Path }

import from tempfile { TemporaryDirectory }

glob REPO: any;

glob RESET: any;

glob SETUP: any;

glob BASH: any;

glob SKILL_DIR: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    RESET = REPO / ".claude" / "commands" / "reset.md";
    SETUP = REPO / ".claude" / "commands" / "setup.md";
    BASH = find_bash();
}

"""Names of documents/ subfolders tracked in git (ignores local noise)."""
def tracked_document_subfolders -> any;

class TestResetCoversEveryDocumentsSubfolder(unittest.TestCase) {
    def setUp -> any;

    def test_preview_lists_every_subfolder -> any;

    @unittest.skipUnless(BASH, "requires Bash to replay the documented /reset command")
    def test_delete_block_removes_every_subfolder -> any;
}

"""The slice of text from the start marker up to the end marker."""
def section(text: builtins.str, start: builtins.str, end: builtins.str) -> builtins.str;

"""Skill files /setup Step 3 populates, derived from its own headings.

    Step 3's targets are written as '### <n>. <verb> `<target>`', where the
    target is either a bare filename resolved against .claude/skills/ or a
    repo-relative path. Non-skill targets (CLAUDE.md, cv/main_example.tex)
    are dropped: /reset profile's scope is skill files only.
    """
def setup_step3_skill_files -> any;

"""(skill file, section headings) pairs /setup Path A's Step A5 writes into.

    Step A5's inference rules are bullets of the form
    '- **`<file>`** ...: ... under "## <Heading>" ...'. Path A writes from the
    user's own documents and past applications, outside Step 3's headings, so
    deriving coverage from Step 3 alone missed these targets.
    """
def setup_path_a_inference_rules -> any;

"""/reset profile must clear what /setup Path A infers from past applications.

    The regression: Path A adds '## Patterns Observed in Past Applications' to
    03-writing-style.md from the user's own cover letters, while reset.md listed
    03 as 'NOT touched (they contain framework rules, not candidate data)' - so
    the user's past phrasing survived a reset that said the file held none.
    """
class TestResetCoversPathAInferredContent(unittest.TestCase) {
    def setUp -> any;

    """The preview's has-content/nothing-to-clear verdicts come from Step 1's read list."""
    def test_step1_reads_every_path_a_file -> any;

    def test_preview_lists_every_path_a_file -> any;

    def test_preserved_list_claims_no_path_a_file_is_framework_only -> any;

    """Each heading must be named in the Step 3 instruction for its own file.

        An instruction runs from its '**For `<file>`**' line to the next one, so
        a heading attached to another file's instruction does not count.
        """
    def test_execution_removes_every_section_path_a_adds -> any;
}

class TestResetCoversEveryPersonalizedSkillFile(unittest.TestCase) {
    def setUp -> any;

    def test_preview_lists_every_personalized_skill_file -> any;

    def test_execution_clears_every_personalized_skill_file -> any;

    """A file /setup personalizes must never be listed as framework-only.

        This is the specific regression: 04-job-evaluation.md was named in the
        "NOT touched (they contain framework rules, not candidate data)" list,
        so merely searching reset.md for the filename would have found it.
        """
    def test_preserved_list_claims_no_personalized_file_is_framework_only -> any;
}

with entry {
    SKILL_DIR = REPO / ".claude" / "skills" / "job-application-assistant";
}

"""(instruction sentence, fenced markdown) /reset uses to rewrite `filename` in Step 3."""
def skeleton_step(reset_text, filename) -> any;

"""The fenced markdown /reset writes over `filename` in Step 3."""
def skeleton_block(reset_text, filename) -> any;

"""The leading `---` block of a skill file, or '' when it has none."""
def frontmatter(text) -> any;

def h2_headings(text) -> any;

"""Whether every needle occurs in haystack, in the same relative order."""
def appear_in_order(needles, haystack) -> any;

"""Step 3's skeletons and anchors must name sections that exist.

    Two of them drifted from the files they rewrite. The behavioral-profile
    skeleton used "Strongest Behavioral Traits" / "How I Work Best" / "Growth
    Areas" where the shipped file has "Strongest Behaviors" / "How You Work
    Best" / "Growth Areas (frame positively in applications)", and dropped
    "Core Behavioral Drives" - the structured assessment table /setup collects
    and /interview reads - so one reset left the file's headings permanently
    different from every other fork's. The CV-guide step anchored on a line
    beginning "**Profile statement templates", which the guide has never
    contained (its heading is "**Create 2-3 profile statement templates for
    your main role types:**"), so the wipe found nothing and the user's
    role-tailored statements survived a reset that reported success. Both are
    derived here from the shipped files, so a renamed heading fails this test
    until /reset follows it.
    """
class TestResetTargetsTheHeadingsTheShippedFilesHave(unittest.TestCase) {
    def setUp -> any;

    def test_full_file_skeletons_keep_the_shipped_headings -> any;

    def test_fork_heading_check_rejects_a_renamed_dropped_or_reordered_heading -> any;

    def test_full_file_skeletons_keep_the_framework_version_frontmatter -> any;

    def test_candidate_skeleton_keeps_the_languages_table_under_identity -> any;

    def test_partial_anchors_exist_in_the_files_they_target -> any;
}

with entry:__main__ {
    unittest.main();
}
