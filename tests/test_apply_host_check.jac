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

def installed_portal_skills(skills_dir: Path = SKILLS_DIR) -> list[Path] {
    return sorted([d for d in skills_dir.glob("*-search") if (d / "cli" / "src").is_dir()]);
}

"""Whether SKILL.md leaves the portal enabled (the default)."""
def portal_enabled(skill_dir: Path) -> bool {
    skill_md: Path = skill_dir / "SKILL.md";
    if not skill_md.is_file() {
        return True;
    }
    flag: re.Match | None = re.search(
        "^enabled:\\s*(true|false)\\b", skill_md.read_text(encoding="utf-8"), re.M
    );
    return flag is None or flag.group(1) == "true";
}

"""The hosts named in a portal's CLI source, without `www.`."""
def portal_hosts(skill_dir: Path) -> set[str] {
    hosts: set[str] = set();
    for source in (skill_dir / "cli" / "src").rglob("*.ts") {
        for found in HOST_LITERAL.findall(source.read_text(encoding="utf-8")) {
            host: str = found.lower();
            if host not in NON_PORTAL_HOSTS {
                hosts.add(host.removeprefix("www."));
            }
        }
    }
    return hosts;
}

def discover_installed_portal_hosts(skills_dir: Path = SKILLS_DIR) -> set[str] {
    hosts: set[str] = set();
    for skill in installed_portal_skills(skills_dir) {
        hosts |= portal_hosts(skill);
    }
    return hosts;
}

"""The URL's lower-case host, or "" when it has none."""
def host_of(url: str) -> str {
    try {
        return (urlparse(url).hostname or "").lower().strip();
    } except Exception {
        return "";
    }
}

"""Whether `host` is one of `names` or a subdomain of one."""
def under(host: str, names: set[str]) -> bool {
    return any([host == name or host.endswith(f".{name}") for name in names]);
}

def resolve_portal_skill(url: str, skills_dir: Path = SKILLS_DIR) -> Path | None {
    host: str = host_of(url);
    for skill in installed_portal_skills(skills_dir) {
        if host and under(host, portal_hosts(skill)) {
            return skill;
        }
    }
    return None;
}

"""(tier, host), tier being installed_portal, official_ats or unverified."""
def classify_posting_host(url: str, installed_portals: set[str] | None = None) -> tuple[str, str] {
    host: str = host_of(url);
    portals: set[str] = discover_installed_portal_hosts()
        if installed_portals is None
        else installed_portals;
    if host and under(host, portals) {
        return ("installed_portal", host);
    }
    if host and under(host, KNOWN_ATS_APEXES) {
        return ("official_ats", host);
    }
    return ("unverified", host);
}

class ApplyHostVerificationSpecTests(unittest.TestCase) {
    def test_apply_steps_wire_the_posting_gate_and_host_verification {
        text: str = doc(APPLY);
        step0: str = between(text, "## Step 0: Parse Input", "## Step 1:");
        step1: str = between(text, "## Step 1: DRAFTER - Evaluate Fit", "## Step 2:");
        step3: str = between(text, "## Step 3: REVIEWER - Research & Critique", "## Step 4:");
        step4: str = between(text, "## Step 4: DRAFTER - Revise Based on Feedback", "## Step 5:");
        expect(self, step0, "posting-fetcher", "posting_guard", "--text", "detail");
        self.assertLess(step0.index("Portal CLI first"), step0.index("WebFetch fallback"));
        expect(
            self,
            step1,
            "Continue with this posting?",
            "Source Host Verification",
            "greenhouse.io",
            "lever.co",
            "myworkdayjobs.com",
            "ashbyhq.com",
            "smartrecruiters.com",
            "workable.com",
            "evil-greenhouse.io",
            "fail closed",
            "Unverified source host",
        );
        self.assertLess(step1.index("Posting integrity"), step1.index("Source host verification"));
        expect(self, step3, "application-reviewer", "### Company research (for the cache)");
        expect_not(self, step3, "general-purpose");
        expect(self, step4, "company_research/");
    }

    def test_web_research_escalation_order_lists_portal_cli_first {
        order: str = section(
            doc(".claude/skills/job-application-assistant/09-web-research.md"),
            "## Escalation order",
            "## ",
        );
        self.assertLess(
            order.index("Installed portal CLI `detail` command"), order.index("`WebFetch`")
        );
    }

    def test_rank_step2_documents_portal_cli_detail_fetch {
        step2: str = between(doc(RANK), "## Step 2: Batch-Fetch and Score", "## Step 3:");
        expect(self, step2, "detail", "09-web-research.md");
    }

    def test_classifier_tiers {
        tiers: dict[str, list[str]] = {
            "official_ats": [
                "https://boards.greenhouse.io/acme/jobs/12345",
                "https://job-boards.greenhouse.io/acme/jobs/12345",
                "https://jobs.lever.co/corp/67890",
                "https://acme.myworkdayjobs.com/en-US/Careers/job/1",
                "https://jobs.ashbyhq.com/startup/abc-123",
                "https://jobs.smartrecruiters.com/Enterprise/456",
                "https://apply.workable.com/tech-corp/j/789/",
            ],
            "unverified": [
                "https://evil-greenhouse.io/job/1",
                "https://boards.greenhouse.io.evil.com/job/1",
                "https://boards.greenhouse.io@evil-domain.com/job/1",
                "https://myworkdayjobs.com.phishing.net/login",
                "https://lever.co.attacker.org/apply",
                "https://unknown-board.example.com/posting/123",
                "https://github.com/acme-careers/jobs/blob/main/README.md",
                "https://gist.github.com/someone/0123456789abcdef",
            ],
        };
        for (tier, urls) in tiers.items() {
            for url in urls {
                with self.subTest(url=url) {
                    self.assertEqual(classify_posting_host(url)[0], tier);
                }
            }
        }
    }

    def test_classifier_default_is_the_discovered_set_not_a_copy {
        url: str = "https://jobs.newboard.test/x";
        self.assertEqual(getattr(classify_posting_host as any, "__defaults__"), (None,));
        self.assertEqual(classify_posting_host(url, {"newboard.test"})[0], "installed_portal");
        self.assertEqual(classify_posting_host(url)[0], "unverified");
    }
}

class InstalledPortalsAreVerifiedTests(unittest.TestCase) {
    def test_every_installed_portals_hosts_classify_and_resolve {
        for skill in installed_portal_skills() {
            hosts: list[str] = sorted(portal_hosts(skill));
            self.assertTrue(hosts, f"{skill.name}/cli/src has no host literal");
            for host in hosts {
                with self.subTest(portal=skill.name, host=host, enabled=portal_enabled(skill)) {
                    self.assertFalse(host.startswith("www."));
                    self.assertRegex(host, "^[a-z0-9.-]+\\.[a-z]{2,}$");
                    for prefix in ("", "www.", "sub.") {
                        url: str = f"https://{prefix}{host}/job/1";
                        self.assertEqual(classify_posting_host(url)[0], "installed_portal", url);
                    }
                    for prefix in ("", "sub.") {
                        resolved: Path | None = resolve_portal_skill(
                            f"https://{prefix}{host}/posting/123"
                        );
                        assert resolved is not None;
                        self.assertEqual(resolved.name, skill.name);
                        self.assertTrue((resolved / "cli" / "src" / "cli.ts").is_file());
                    }
                }
            }
        }
    }

    def test_resolve_portal_skill_returns_none_for_non_portal_urls {
        for url in (
            "https://example.com/posting/123",
            "https://greenhouse.io/corp/123",
            "not-a-valid-url",
        ) {
            with self.subTest(url=url) {
                self.assertIsNone(resolve_portal_skill(url));
            }
        }
    }
}

class CopiedPortalDiscoveryTests(unittest.TestCase) {
    def setUp {
        directory: tempfile.TemporaryDirectory = tempfile.TemporaryDirectory();
        self.addCleanup(directory.cleanup);
        self.skills = Path(directory.name);
        self.board = self.add_portal(
            "board-search", "const BASE_URL = \"https://www.board.test\";\n"
        );
        self.add_portal(
            "quiet-search",
            "const API = \"https://api.quiet.test/v1\";\nconst SCHEMA = \"https://schema.org\";\n",
            "---\nname: quiet-search\nenabled: false\n---\n",
        );
        (self.skills / "notes-search").mkdir();
    }

    def add_portal(name: str, source: str, skill_md: str | None = None) -> Path {
        skill: Path = self.skills / name;
        (skill / "cli" / "src").mkdir(parents=True);
        (skill / "cli" / "src" / "cli.ts").write_text(source, encoding="utf-8");
        if skill_md is not None {
            (skill / "SKILL.md").write_text(skill_md, encoding="utf-8");
        }
        return skill;
    }

    def test_discovery_reads_cli_source_trees_only {
        self.assertEqual(
            [d.name for d in installed_portal_skills(self.skills)], ["board-search", "quiet-search"]
        );
        self.assertEqual(
            discover_installed_portal_hosts(self.skills), {"board.test", "api.quiet.test"}
        );
    }

    def test_apex_and_subdomains_classify_and_resolve {
        hosts: set[str] = discover_installed_portal_hosts(self.skills);
        for sub in ("", "www.", "dk.") {
            url: str = f"https://{sub}board.test/job/1";
            with self.subTest(url=url) {
                self.assertEqual(classify_posting_host(url, hosts)[0], "installed_portal");
                self.assertEqual(resolve_portal_skill(url, self.skills), self.board);
            }
        }
        self.assertEqual(classify_posting_host(EVIL, hosts)[0], "unverified");
        self.assertIsNone(resolve_portal_skill(EVIL, self.skills));
    }

    def test_enabled_flag_reads_like_scrape {
        self.assertTrue(portal_enabled(self.board));
        self.assertFalse(portal_enabled(self.skills / "quiet-search"));
        self.assertTrue(portal_enabled(self.skills / "does-not-exist-search"));
    }
}
