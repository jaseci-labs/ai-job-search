"""Guards for /apply's source host verification rule in Step 1 (#431).

Pins the invariants from the maintainer design in issue #431:
- URLs must be verified before drafting against installed portal boards or known ATS apexes.
- The 6 standard ATS apex domains must be checked: greenhouse.io, lever.co,
  myworkdayjobs.com (or workday.com), ashbyhq.com, smartrecruiters.com, workable.com.
- Look-alike attacks (prefixes, suffixes, userinfo tricks) must fail closed.
- Any other host must be named plainly in the output as unverified.

The installed-portal half is derived, not copied (#497). Rule 1 in apply.md
defines an installed portal as "any configured job portal in `.agents/skills/`",
so the source of truth is the skills tree: the host literals in each
`*-search/cli/src/**/*.ts`. A hand-copied set in this file went stale the moment
a portal was added or dropped, and a new portal CLI fetching from a host the
copy lacked had its postings classified "unverified" with no test failing.
The ATS apex list stays the fixed set it is.
"""

import builtins;

import operator;

import re;

import tempfile;

import unittest;

import from pathlib { Path }

import from urllib.parse { urlparse }

glob REPO: any;

glob APPLY_COMMAND_FILE: any;

glob SKILLS_DIR: any;

glob HOST_LITERAL: any;

glob NON_PORTAL_HOSTS: any;

glob INSTALLED_PORTAL_HOSTS: any;

glob KNOWN_ATS_APEXES: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    APPLY_COMMAND_FILE = REPO / ".claude" / "commands" / "apply.md";
    SKILLS_DIR = REPO / ".agents" / "skills";
    HOST_LITERAL = re.compile("https?://([A-Za-z0-9.-]+\\.[A-Za-z]{2,})");
    NON_PORTAL_HOSTS = {"schema.org", "www.w3.org", "example.com", "localhost"};
    skills_dir_default_ = SKILLS_DIR;
}

glob skills_dir_default_: any;

"""Every `*-search` skill with a CLI source tree, enabled or not.

    Rule 1 says "configured job portal in `.agents/skills/`" - a portal that is
    installed but `enabled: false` for /scrape is still a legitimate board for
    a posting the user pastes into /apply, so discovery is by installation.
    """
def installed_portal_skills(skills_dir: Path = skills_dir_default_) -> builtins.list[Path];

"""The `enabled:` frontmatter flag /scrape honours; a missing key means enabled."""
def portal_enabled(skill_dir: Path) -> builtins.bool;

"""The board hosts a portal CLI fetches from, as registrable names.

    A leading `www.` is dropped so the classifier's exact-or-subdomain rule
    accepts both `jobindex.dk` and `www.jobindex.dk` (the CLI builds its URLs
    with the latter; postings link to both).
    """
def portal_hosts(skill_dir: Path) -> builtins.set[builtins.str];

glob skills_dir_default__: any;

with entry {
    skills_dir_default__ = SKILLS_DIR;
}

def discover_installed_portal_hosts(
    skills_dir: Path = skills_dir_default__
) -> builtins.set[builtins.str];

with entry {
    INSTALLED_PORTAL_HOSTS = discover_installed_portal_hosts();

    KNOWN_ATS_APEXES = {
        "greenhouse.io",
        "lever.co",
        "myworkdayjobs.com",
        "workday.com",
        "ashbyhq.com",
        "smartrecruiters.com",
        "workable.com",
    };
    skills_dir_default___ = SKILLS_DIR;
}

glob skills_dir_default___: any;

"""Resolve a posting URL to its matching installed portal skill directory, if any."""
def resolve_portal_skill(url_str: builtins.str, skills_dir: Path = skills_dir_default___) -> Path
    | None;

"""Reference implementation of the host provenance rule in /apply Step 1.

    `installed_portals` defaults to the set discovered from the skills tree, so
    the classifier can never lag a portal that /add-portal installed.

    Returns (tier, host), where tier is one of:
      - 'installed_portal'
      - 'official_ats'
      - 'unverified'
    """
def classify_posting_host(
    url_str: builtins.str, installed_portals: builtins.set[builtins.str] | None = None
) -> builtins.tuple[builtins.str, builtins.str];

"""The posting passes tools/posting_guard.jac before Step 1 evaluates it, the
    component that fetches it has no Edit/Write, and the reviewer returns its
    research as text for the orchestrator to write."""
class ApplyPostingGateWiringTests(unittest.TestCase) {
    def setUp -> any;

    def test_step0_dispatches_posting_fetcher_and_runs_guard -> any;

    def test_step1_prints_posting_integrity_line -> any;

    def test_step3_dispatches_application_reviewer_and_orchestrator_writes_cache -> any;
}

class ApplyHostVerificationSpecTests(unittest.TestCase) {
    def setUp -> any;

    def test_step0_documents_portal_cli_detail_before_webfetch -> any;

    def test_step1_contains_source_host_verification_heading -> any;

    def test_step1_documents_all_six_ats_apexes -> any;

    def test_step1_documents_look_alike_fail_closed_rules -> any;

    def test_step1_requires_unverified_hosts_to_be_named_plainly -> any;

    def test_classifier_identifies_official_ats_subdomains -> any;

    def test_classifier_default_is_the_discovered_set_not_a_copy -> any;
}

"""Every installed portal CLI's board host must classify as installed_portal.

    This is the assertion the hand-copied set could not make: a portal added
    by /add-portal fetches from a host the copy never heard of, and its
    postings reached /apply flagged "unverified" while the suite stayed green.
    """
class InstalledPortalsAreVerifiedTests(unittest.TestCase) {
    def test_every_installed_portal_has_a_discoverable_host -> any;

    def test_every_installed_portals_host_classifies_as_installed_portal -> any;

    def test_portal_hosts_are_registrable_names_without_www -> any;

    def test_classifier_fails_closed_on_look_alikes_and_unverified_hosts -> any;

    """Every installed portal skill must resolve URLs for each host it queries (#535)."""
    def test_resolve_portal_skill_maps_all_installed_portal_hosts -> any;

    def test_resolve_portal_skill_returns_none_for_non_portal_urls -> any;
}

"""A portal copied into .agents/skills/ from community-portals is discovered
    from its own CLI source. Upstream ships no portal, so the tree-wide tests
    above only bite in a fork; this fixture keeps discovery itself covered."""
class CopiedPortalDiscoveryTests(unittest.TestCase) {
    def setUp -> any;

    def add_portal(
        name: builtins.str, source: builtins.str, skill_md: builtins.str | None = None
    ) -> Path;

    def test_only_skills_with_a_cli_source_tree_are_portals -> any;

    def test_hosts_come_from_cli_source_without_www_or_vocabularies -> any;

    def test_apex_and_subdomains_classify_and_resolve -> any;

    def test_enabled_flag_reads_like_scrape -> any;
}

class WebResearchEscalationOrderTests(unittest.TestCase) {
    def setUp -> any;

    def test_escalation_order_lists_portal_cli_first -> any;
}

class RankBatchFetchSpecTests(unittest.TestCase) {
    def setUp -> any;

    def test_rank_step2_documents_portal_cli_detail_fetch -> any;
}

with entry:__main__ {
    unittest.main();
}
