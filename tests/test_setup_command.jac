"""Guards for the /setup command spec.

The command is a markdown spec (the spec IS the implementation). These tests pin
one invariant that broke silently: Step 3 must personalise every contact block
that `/apply` later compiles into a document. `cv/main_example.tex` was covered;
the LaTeX blocks embedded in `05-cv-templates.md` and `06-cover-letter-templates.md`
were not, so a full Path B/C run left `[YOUR_NAME]`, `[YOUR_EMAIL]` and
`[YOUR_PHONE]` in both, and whether they reached a compiled cover letter depended
on the drafter noticing. A real user (#420) ran `/setup` and then hand-edited both
files to close the gap.
"""

import builtins;

import re;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob COMMAND: any;

glob SKILL_DIR: any;

glob CV_TEMPLATES: any;

glob COVER_TEMPLATES: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "setup.md";
    SKILL_DIR = REPO / ".claude" / "skills" / "job-application-assistant";
    CV_TEMPLATES = SKILL_DIR / "05-cv-templates.md";
    COVER_TEMPLATES = SKILL_DIR / "06-cover-letter-templates.md";
}

"""Split a command spec into {heading: body} by '## ' headers."""
def _sections(text: builtins.str) -> builtins.dict[builtins.str, builtins.str];

"""Split a step body into {'### N. ...' heading: body}."""
def _substeps(step_body: builtins.str) -> builtins.dict[builtins.str, builtins.str];

class SetupStep3ContactBlocks(unittest.TestCase) {
    def setUp -> any;

    def _substep_for(filename: builtins.str) -> builtins.str;

    def test_cv_templates_substep_fills_the_contact_block -> any;

    def test_cover_letter_templates_get_their_own_substep -> any;

    def test_completion_summary_lists_the_cover_letter_templates -> any;
}

"""The instructions above target real tokens; if a template renames them,
    the instruction and this test must move together."""
@unittest.skipIf(
    not is_upstream_checkout(),
    "template-placeholder guard targets the pristine upstream template; forks personalize 05-cv-templates.md and 06-cover-letter-templates.md via /setup",
)
class TemplatesStillCarryThePlaceholders(unittest.TestCase) {
    def test_cv_templates_contact_block_tokens -> any;

    def test_cover_letter_templates_contact_and_signature_tokens -> any;
}

"""Step A7 named 02-behavioral-profile.md sections that do not exist.

    "Strongest Behavioral Traits" and "How [Candidate] Works Best" are not
    headings in the shipped file ("Strongest Behaviors", "How You Work Best"
    are), so the "add only to these sections" rule pointed at nothing. The
    section names are read from the bullet and checked against the file's
    `##` headings, with the placeholder-free spelling required: a reader
    cannot match "[Candidate]" against a heading.
    """
class SetupPathAWritesIntoSectionsTheShippedFilesHave(unittest.TestCase) {
    def test_behavioral_profile_bullet_names_real_headings -> any;
}

"""Guards for /setup Path A document ingestion of documents/projects/."""
class SetupPathAProjectsIngestion(unittest.TestCase) {
    def setUp -> any;

    def test_step0_scan_includes_projects -> any;

    def test_step_a1_inventory_includes_projects -> any;

    def test_step_a3_parsing_includes_projects_spec -> any;

    def test_step_a5_and_a6_map_to_independent_projects -> any;
}

with entry:__main__ {
    unittest.main();
}
