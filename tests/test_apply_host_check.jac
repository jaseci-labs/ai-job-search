import re;
import tempfile;
import unittest;
import from pathlib { Path }
import from urllib.parse { urlparse }

glob SKILLS_DIR: Path = REPO / ".agents" / "skills",
     HOST_LITERAL: re.Pattern = re.compile("https?://([A-Za-z0-9.-]+\\.[A-Za-z]{2,})"),
     NON_PORTAL_HOSTS: set[str] = {"schema.org", "www.w3.org", "example.com", "localhost"},
     KNOWN_ATS_APEXES: set[str] = {
         "greenhouse.io",
         "lever.co",
         "myworkdayjobs.com",
         "workday.com",
         "ashbyhq.com",
         "smartrecruiters.com",
         "workable.com",
     },
     EVIL: str = "https://evil-board.test/job/1";

def installed_portal_skills(skills_dir: Path = SKILLS_DIR) -> list[Path];

"""Whether SKILL.md leaves the portal enabled (the default)."""
def portal_enabled(skill_dir: Path) -> bool;

"""The hosts named in a portal's CLI source, without `www.`."""
def portal_hosts(skill_dir: Path) -> set[str];

def discover_installed_portal_hosts(skills_dir: Path = SKILLS_DIR) -> set[str];

"""The URL's lower-case host, or "" when it has none."""
def host_of(url: str) -> str;

"""Whether `host` is one of `names` or a subdomain of one."""
def under(host: str, names: set[str]) -> bool;

def resolve_portal_skill(url: str, skills_dir: Path = SKILLS_DIR) -> Path | None;

"""(tier, host), tier being installed_portal, official_ats or unverified."""
def classify_posting_host(url: str, installed_portals: set[str] | None = None) -> tuple[str, str];

class ApplyHostVerificationSpecTests(unittest.TestCase) {
    def test_apply_steps_wire_the_posting_gate_and_host_verification;
    def test_web_research_escalation_order_lists_portal_cli_first;
    def test_rank_step2_documents_portal_cli_detail_fetch;
    def test_classifier_tiers;
    def test_classifier_default_is_the_discovered_set_not_a_copy;
}

class InstalledPortalsAreVerifiedTests(unittest.TestCase) {
    def test_every_installed_portals_hosts_classify_and_resolve;
    def test_resolve_portal_skill_returns_none_for_non_portal_urls;
}

class CopiedPortalDiscoveryTests(unittest.TestCase) {
    def setUp;
    def add_portal(name: str, source: str, skill_md: str | None = None) -> Path;
    def test_discovery_reads_cli_source_trees_only;
    def test_apex_and_subdomains_classify_and_resolve;
    def test_enabled_flag_reads_like_scrape;
}
