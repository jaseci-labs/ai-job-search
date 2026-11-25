impl installed_portal_skills(skills_dir: Path = skills_dir_default_) -> builtins.list[Path] {
    return sorted(d for d in skills_dir.glob("*-search") if (d / "cli" / "src").is_dir());
}

impl portal_enabled(skill_dir: Path) -> builtins.bool {
    skill_md: any = skill_dir / "SKILL.md";
    if not skill_md.is_file() {
        return True;
    }
    `match: any = re.search(
        "^enabled:\\s*(true|false)\\b", skill_md.read_text(encoding="utf-8"), re.M
    );
    return `match is None or operator.eq(`match.group(1), "true");
}

impl portal_hosts(skill_dir: Path) -> builtins.set[builtins.str] {
    hosts: builtins.set[builtins.str] = set[any]();
    for source in (skill_dir / "cli" / "src").rglob("*.ts") {
        host: any;
        for host in HOST_LITERAL.findall(source.read_text(encoding="utf-8")) {
            host = host.lower();
            if host in NON_PORTAL_HOSTS {
                continue;
            }
            hosts.add(host[4:] if host.startswith("www.") else host);
        }
    }
    return hosts;
}

impl discover_installed_portal_hosts(
    skills_dir: Path = skills_dir_default__
) -> builtins.set[builtins.str] {
    return set[any]().union(*(portal_hosts(d) for d in installed_portal_skills(skills_dir)));
}

impl resolve_portal_skill(url_str: builtins.str, skills_dir: Path = skills_dir_default___) -> Path
    | None {
    try {
        parsed: any = urlparse(url_str);
        host: any = (parsed.hostname or "").lower().strip();
    } except Exception {
        return None;
    }
    if not host {
        return None;
    }
    for skill in installed_portal_skills(skills_dir) {
        for portal in portal_hosts(skill) {
            if host == portal or host.endswith(f".{portal}") {
                return skill;
            }
        }
    }
    return None;
}

impl classify_posting_host(
    url_str: builtins.str, installed_portals: builtins.set[builtins.str] | None = None
) -> builtins.tuple[builtins.str, builtins.str] {
    if installed_portals is None {
        installed_portals = INSTALLED_PORTAL_HOSTS;
    }
    try {
        parsed: any = urlparse(url_str);
        host: any = (parsed.hostname or "").lower().strip();
    } except Exception {
        return ("unverified", "");
    }

    if not host {
        return ("unverified", "");
    }
    for portal in installed_portals {
        if host == portal or host.endswith(f".{portal}") {
            return ("installed_portal", host);
        }
    }
    for apex in KNOWN_ATS_APEXES {
        if host == apex or host.endswith(f".{apex}") {
            return ("official_ats", host);
        }
    }

    return ("unverified", host);
}

impl ApplyPostingGateWiringTests.setUp -> any {
    self.text = APPLY_COMMAND_FILE.read_text(encoding="utf-8");
    self.step0 = re.search("## Step 0: Parse Input(.*?)(?=## Step 1:)", self.text, re.DOTALL).group(
        1
    );
    self.step1 = re.search(
        "## Step 1: DRAFTER - Evaluate Fit(.*?)(?=## Step 2:)", self.text, re.DOTALL
    ).group(1);
    self.step3 = re.search(
        "## Step 3: REVIEWER - Research & Critique(.*?)(?=## Step 4:)", self.text, re.DOTALL
    ).group(1);
    self.step4 = re.search(
        "## Step 4: DRAFTER - Revise Based on Feedback(.*?)(?=## Step 5:)", self.text, re.DOTALL
    ).group(1);
}

impl ApplyPostingGateWiringTests.test_step0_dispatches_posting_fetcher_and_runs_guard -> any {
    self.assertIn(
        "posting-fetcher", self.step0, "a URL posting is fetched by the least-privilege agent"
    );
    self.assertIn("posting_guard", self.step0, "Step 0 must name the integrity gate");
    self.assertIn("--text", self.step0, "pasted text is gated too, in text mode");
    self.assertIn("Portal CLI first", self.step0);
}

impl ApplyPostingGateWiringTests.test_step1_prints_posting_integrity_line -> any {
    self.assertIn("Posting integrity", self.step1);
    self.assertIn("Continue with this posting?", self.step1);
    self.assertLess(
        self.step1.index("Posting integrity"),
        self.step1.index("Source host verification"),
        "the integrity verdict is the first line of the evaluation",
    );
}

impl ApplyPostingGateWiringTests.test_step3_dispatches_application_reviewer_and_orchestrator_writes_cache -> any {
    self.assertIn("application-reviewer", self.step3);
    self.assertNotIn("general-purpose", self.step3);
    self.assertIn(
        "### Company research (for the cache)",
        self.step3,
        "the reviewer returns the cache as text - it has no Write tool",
    );
    self.assertIn(
        "company_research/",
        self.step4,
        "the orchestrator writes the cache after the reviewer returns",
    );
}

impl ApplyHostVerificationSpecTests.setUp -> any {
    self.text = APPLY_COMMAND_FILE.read_text(encoding="utf-8");
    step0_match: any = re.search("## Step 0: Parse Input(.*?)(?=## Step 1:)", self.text, re.DOTALL);
    self.assertTrue(step0_match, "Step 0 must exist in apply.md");
    self.step0_text = step0_match.group(1);
    step1_match: any = re.search(
        "## Step 1: DRAFTER - Evaluate Fit(.*?)(?=## Step 2:)", self.text, re.DOTALL
    );
    self.assertTrue(step1_match, "Step 1 must exist in apply.md");
    self.step1_text = step1_match.group(1);
}

impl ApplyHostVerificationSpecTests.test_step0_documents_portal_cli_detail_before_webfetch -> any {
    self.assertIn("Portal CLI first", self.step0_text);
    self.assertIn("detail", self.step0_text);
    self.assertIn("WebFetch fallback", self.step0_text);
    cli_pos: any = self.step0_text.find("Portal CLI first");
    webfetch_pos: any = self.step0_text.find("WebFetch fallback");
    self.assertNotEqual(cli_pos, -1);
    self.assertNotEqual(webfetch_pos, -1);
    self.assertLess(
        cli_pos, webfetch_pos, "Portal CLI detail must precede WebFetch in apply.md Step 0"
    );
}

impl ApplyHostVerificationSpecTests.test_step1_contains_source_host_verification_heading -> any {
    self.assertIn("Source Host Verification", self.step1_text);
}

impl ApplyHostVerificationSpecTests.test_step1_documents_all_six_ats_apexes -> any {
    for apex in [
        "greenhouse.io",
        "lever.co",
        "myworkdayjobs.com",
        "ashbyhq.com",
        "smartrecruiters.com",
        "workable.com",
    ] {
        self.assertIn(apex, self.step1_text, f"Step 1 must specify ATS apex: {apex}");
    }
}

impl ApplyHostVerificationSpecTests.test_step1_documents_look_alike_fail_closed_rules -> any {
    self.assertIn("evil-greenhouse.io", self.step1_text);
    self.assertIn("fail closed", self.step1_text);
}

impl ApplyHostVerificationSpecTests.test_step1_requires_unverified_hosts_to_be_named_plainly -> any {
    self.assertIn("Unverified source host", self.step1_text);
}

impl ApplyHostVerificationSpecTests.test_classifier_identifies_official_ats_subdomains -> any {
    urls: any = [
        "https://boards.greenhouse.io/acme/jobs/12345",
        "https://job-boards.greenhouse.io/acme/jobs/12345",
        "https://jobs.lever.co/corp/67890",
        "https://acme.myworkdayjobs.com/en-US/Careers/job/1",
        "https://jobs.ashbyhq.com/startup/abc-123",
        "https://jobs.smartrecruiters.com/Enterprise/456",
        "https://apply.workable.com/tech-corp/j/789/",
    ];
    for url in urls {
        tier: any;
        host: any;
        (tier, host) = classify_posting_host(url) as any;
        self.assertEqual(
            tier, "official_ats", f"{url} should classify as official_ats, got {tier}"
        );
    }
}

impl ApplyHostVerificationSpecTests.test_classifier_default_is_the_discovered_set_not_a_copy -> any {
    self.assertEqual(getattr(classify_posting_host as any, "__defaults__"), (None,));
    self.assertEqual(
        classify_posting_host("https://jobs.newboard.test/x", {"newboard.test"})[0],
        "installed_portal",
    );
    self.assertEqual(classify_posting_host("https://jobs.newboard.test/x")[0], "unverified");
}

impl InstalledPortalsAreVerifiedTests.test_every_installed_portal_has_a_discoverable_host -> any {
    for skill in installed_portal_skills() {
        with self.subTest(portal=skill.name) {
            self.assertTrue(
                portal_hosts(skill),
                f"{skill.name}/cli/src has no host literal - the classifier cannot verify its postings",
            );
        }
    }
}

impl InstalledPortalsAreVerifiedTests.test_every_installed_portals_host_classifies_as_installed_portal -> any {
    for skill in installed_portal_skills() {
        for host in sorted(portal_hosts(skill)) {
            for url in (
                f"https://{host}/job/1",
                f"https://www.{host}/job/1",
                f"https://sub.{host}/job/1",
            ) {
                with self.subTest(portal=skill.name, url=url, enabled=portal_enabled(skill)) {
                    tier: any;
                    _: any;
                    (tier, _) = classify_posting_host(url) as any;
                    self.assertEqual(tier, "installed_portal", f"{url} classified as {tier}");
                }
            }
        }
    }
}

impl InstalledPortalsAreVerifiedTests.test_portal_hosts_are_registrable_names_without_www -> any {
    for skill in installed_portal_skills() {
        for host in portal_hosts(skill) {
            with self.subTest(portal=skill.name, host=host) {
                self.assertFalse(host.startswith("www."), host);
                self.assertRegex(host, "^[a-z0-9.-]+\\.[a-z]{2,}$");
            }
        }
    }
}

impl InstalledPortalsAreVerifiedTests.test_classifier_fails_closed_on_look_alikes_and_unverified_hosts -> any {
    suspicious: any = [
        "https://evil-greenhouse.io/job/1",
        "https://boards.greenhouse.io.evil.com/job/1",
        "https://boards.greenhouse.io@evil-domain.com/job/1",
        "https://myworkdayjobs.com.phishing.net/login",
        "https://lever.co.attacker.org/apply",
        "https://unknown-board.example.com/posting/123",
        "https://github.com/acme-careers/jobs/blob/main/README.md",
        "https://gist.github.com/someone/0123456789abcdef",
    ];
    for url in suspicious {
        tier: any;
        host: any;
        (tier, host) = classify_posting_host(url) as any;
        self.assertEqual(tier, "unverified", f"{url} must fail closed as unverified, got {tier}");
    }
}

impl InstalledPortalsAreVerifiedTests.test_resolve_portal_skill_maps_all_installed_portal_hosts -> any {
    for skill in installed_portal_skills() {
        hosts: any = portal_hosts(skill);
        self.assertGreater(len(hosts), 0, f"{skill.name} must declare at least one host");
        for host in hosts {
            for test_url in (f"https://{host}/posting/123", f"https://sub.{host}/posting/123") {
                with self.subTest(skill=skill.name, host=host, url=test_url) {
                    resolved: any = resolve_portal_skill(test_url);
                    self.assertIsNotNone(resolved, f"failed to resolve skill for {test_url}");
                    self.assertEqual(resolved.name, skill.name);
                    self.assertTrue((resolved / "cli" / "src" / "cli.ts").is_file());
                }
            }
        }
    }
}

impl InstalledPortalsAreVerifiedTests.test_resolve_portal_skill_returns_none_for_non_portal_urls -> any {
    unrelated: any = [
        "https://example.com/posting/123",
        "https://greenhouse.io/corp/123",
        "not-a-valid-url",
    ];
    for url in unrelated {
        with self.subTest(url=url) {
            self.assertIsNone(resolve_portal_skill(url));
        }
    }
}

impl CopiedPortalDiscoveryTests.setUp -> any {
    directory: any = tempfile.TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    self.skills = Path(directory.name);
    self.board = self.add_portal("board-search", "const BASE_URL = \"https://www.board.test\";\n");
    self.add_portal(
        "quiet-search",
        "const API = \"https://api.quiet.test/v1\";\nconst SCHEMA = \"https://schema.org\";\n",
        "---\nname: quiet-search\nenabled: false\n---\n",
    );
    (self.skills / "notes-search").mkdir();
}

impl CopiedPortalDiscoveryTests.add_portal(
    name: builtins.str, source: builtins.str, skill_md: builtins.str | None = None
) -> Path {
    skill: any = self.skills / name;
    (skill / "cli" / "src").mkdir(parents=True);
    (skill / "cli" / "src" / "cli.ts").write_text(source, encoding="utf-8");
    if skill_md is not None {
        (skill / "SKILL.md").write_text(skill_md, encoding="utf-8");
    }
    return skill;
}

impl CopiedPortalDiscoveryTests.test_only_skills_with_a_cli_source_tree_are_portals -> any {
    self.assertEqual(
        [d.name for d in installed_portal_skills(self.skills)], ["board-search", "quiet-search"]
    );
}

impl CopiedPortalDiscoveryTests.test_hosts_come_from_cli_source_without_www_or_vocabularies -> any {
    self.assertEqual(
        discover_installed_portal_hosts(self.skills), {"board.test", "api.quiet.test"}
    );
}

impl CopiedPortalDiscoveryTests.test_apex_and_subdomains_classify_and_resolve -> any {
    hosts: any = discover_installed_portal_hosts(self.skills);
    for url in (
        "https://board.test/job/1",
        "https://www.board.test/job/1",
        "https://dk.board.test/job/1",
    ) {
        with self.subTest(url=url) {
            self.assertEqual(classify_posting_host(url, hosts)[0], "installed_portal");
            self.assertEqual(resolve_portal_skill(url, self.skills), self.board);
        }
    }
    self.assertEqual(
        classify_posting_host("https://evil-board.test/job/1", hosts)[0], "unverified"
    );
    self.assertIsNone(resolve_portal_skill("https://evil-board.test/job/1", self.skills));
}

impl CopiedPortalDiscoveryTests.test_enabled_flag_reads_like_scrape -> any {
    self.assertTrue(portal_enabled(self.board));
    self.assertFalse(portal_enabled(self.skills / "quiet-search"));
    self.assertTrue(portal_enabled(self.skills / "does-not-exist-search"));
}

impl WebResearchEscalationOrderTests.setUp -> any {
    self.research_file = REPO
        / ".claude"
        / "skills"
        / "job-application-assistant"
        / "09-web-research.md";
    self.text = self.research_file.read_text(encoding="utf-8");
    `match: any = re.search("## Escalation order(.*?)(?=## |\\Z)", self.text, re.DOTALL);
    self.assertTrue(`match, "Escalation order section must exist in 09-web-research.md");
    self.order_text = `match.group(1);
}

impl WebResearchEscalationOrderTests.test_escalation_order_lists_portal_cli_first -> any {
    self.assertIn("Installed portal CLI `detail` command", self.order_text);
    self.assertIn("WebFetch", self.order_text);
    portal_pos: any = self.order_text.find("Installed portal CLI `detail` command");
    webfetch_pos: any = self.order_text.find("`WebFetch`");
    self.assertNotEqual(portal_pos, -1);
    self.assertNotEqual(webfetch_pos, -1);
    self.assertLess(
        portal_pos, webfetch_pos, "Portal CLI detail must precede WebFetch in escalation order"
    );
}

impl RankBatchFetchSpecTests.setUp -> any {
    self.rank_file = REPO / ".claude" / "commands" / "rank.md";
    self.text = self.rank_file.read_text(encoding="utf-8");
    `match: any = re.search(
        "## Step 2: Batch-Fetch and Score(.*?)(?=## Step 3:)", self.text, re.DOTALL
    );
    self.assertTrue(`match, "Step 2 must exist in rank.md");
    self.step2_text = `match.group(1);
}

impl RankBatchFetchSpecTests.test_rank_step2_documents_portal_cli_detail_fetch -> any {
    self.assertIn("detail", self.step2_text);
    self.assertIn("09-web-research.md", self.step2_text);
}
