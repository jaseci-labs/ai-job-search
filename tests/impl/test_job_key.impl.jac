impl Slugify.test_basic -> any {
    self.assertEqual(slugify("Acme Corp"), "acme-corp");
}

impl Slugify.test_strips_punctuation_that_breaks_paths -> any {
    self.assertEqual(slugify("Ops Consulting, LLC"), "ops-consulting-llc");
    self.assertEqual(slugify("Penetration Tester / Red Teamer"), "penetration-tester-red-teamer");
    self.assertEqual(
        slugify("Junior Cybersecurity Analyst (OT/IoT)"), "junior-cybersecurity-analyst-ot-iot"
    );
}

impl Slugify.test_non_latin_script_reduces_to_empty -> any {
    self.assertEqual(slugify("시큐리온"), "");
    self.assertEqual(slugify("Код Безопасности"), "");
}

impl MakeKey.test_shape -> any {
    key: any = make_key("Acme Corp", "SOC Analyst (L2)");
    self.assertEqual(key, "acme-corp_soc-analyst-l2");
    self.assertTrue(is_canonical(key));
}

impl MakeKey.test_deterministic_across_calls -> any {
    title: any = "Cyber Intelligence Center Security Analyst with an unusually long title";
    self.assertEqual(make_key("Deloitte", title), make_key("Deloitte", title));
}

impl MakeKey.test_long_titles_never_collide_after_truncation -> any {
    a: any = make_key(
        "Deloitte", "Cyber Intelligence Center Security Analyst with trailing text A"
    );
    b: any = make_key(
        "Deloitte", "Cyber Intelligence Center Security Analyst with trailing text B"
    );
    self.assertNotEqual(a, b);
}

impl MakeKey.test_non_latin_title_falls_back_to_the_portal_job_id -> any {
    key: any = make_key(
        "SecuriON", "안드로이드 앱(악성코드) 분석가 채용", url="https://kr.linkedin.com/jobs/view/x-4461771225"
    );
    self.assertEqual(key, "securion_4461771225");
}

impl MakeKey.test_non_latin_title_with_no_url_id_still_produces_a_canonical_key -> any {
    key: any = make_key("SecuriON", "안드로이드 앱 분석가", url="");
    self.assertTrue(is_canonical(key));
    self.assertNotEqual(key, "securion_");
}

impl MakeKey.test_non_latin_company_falls_back_without_producing_a_bare_prefix -> any {
    key: any = make_key("Код Безопасности", "Malware Analytic", url="");
    self.assertTrue(is_canonical(key));
    self.assertFalse(key.startswith("_"));
}

impl MakeKey.test_one_url_keeps_one_key_when_a_non_latin_title_is_re_listed -> any {
    url: any = "https://freehire.me/jobs/inzhener-ooo-chen-hlk3qjfg";
    company: any = "ООО Чен";
    first: any = make_key(company, "Инженер", url=url);
    recased: any = make_key(company, "инженер", url=url);
    retitled: any = make_key(company, "Инженер-механик", url=url);
    self.assertTrue(is_canonical(first));
    self.assertEqual(first, recased);
    self.assertEqual(first, retitled);
}

impl MakeKey.test_distinct_urls_still_get_distinct_keys -> any {
    company: any = "ООО Чен";
    a: any = make_key(
        company, "Инженер", url="https://freehire.me/jobs/inzhener-ooo-chen-hlk3qjfg"
    );
    b: any = make_key(
        company, "Инженер", url="https://freehire.me/jobs/inzhener-mup-g-khabarovska-tep"
    );
    self.assertNotEqual(a, b);
}

impl MixedScriptNamesKeepTheirIdentity.test_titles_sharing_a_digit_fragment_get_distinct_keys -> any {
    company: any = "Яндекс";
    a: any = make_key(company, "Программист 1С", url="https://freehire.me/jobs/programmist-1s-aaa");
    b: any = make_key(company, "Аналитик 1С", url="https://freehire.me/jobs/analitik-1s-bbb");
    self.assertNotEqual(a, b);
    self.assertTrue(is_canonical(a) and is_canonical(b));
}

impl MixedScriptNamesKeepTheirIdentity.test_titles_sharing_a_latin_word_get_distinct_keys -> any {
    company: any = "ООО Чен";
    a: any = make_key(
        company, "Python-разработчик", url="https://freehire.me/jobs/python-razrabotchik-x1"
    );
    b: any = make_key(
        company, "Python-аналитик", url="https://freehire.me/jobs/python-analitik-x2"
    );
    self.assertNotEqual(a, b);
    self.assertTrue(a.split("_", 1)[1].startswith("python-"));
}

impl MixedScriptNamesKeepTheirIdentity.test_lossy_title_prefers_the_portal_numeric_id -> any {
    key: any = make_key(
        "Acme", "Инженер 1 категории", url="https://kr.linkedin.com/jobs/view/x-4461771225"
    );
    self.assertEqual(key, "acme_1-4461771225");
}

impl MixedScriptNamesKeepTheirIdentity.test_companies_sharing_a_latin_word_get_distinct_keys -> any {
    a: any = make_key("Сбер AI", "ML Engineer", url="https://example.com/1");
    b: any = make_key("Яндекс AI", "ML Engineer", url="https://example.com/2");
    self.assertNotEqual(a, b);
    self.assertTrue(a.startswith("ai-") and b.startswith("ai-"));
    self.assertTrue(is_canonical(a) and is_canonical(b));
}

impl MixedScriptNamesKeepTheirIdentity.test_lossy_company_is_stable_across_case_and_urls -> any {
    a: any = make_key("Сбер AI", "ML Engineer", url="https://example.com/1");
    b: any = make_key("сбер ai", "ML Engineer", url="https://example.com/2");
    self.assertEqual(a.split("_", 1)[0], b.split("_", 1)[0]);
}

impl MixedScriptNamesKeepTheirIdentity.test_empty_title_with_a_non_numeric_url_keeps_its_pre_fragment_key -> any {
    self.assertEqual(
        make_key("Acme", "", url="https://example.com/jobs/abc-xyz"),
        "acme_https-example-com-jobs-abc-xyz",
    );
    self.assertTrue(make_key("Acme", "", url="").startswith("acme_untitled-"));
}

impl MixedScriptNamesKeepTheirIdentity.test_latin_names_with_accents_and_ligatures_are_not_lossy -> any {
    self.assertEqual(
        make_key("Zürich Versicherung", "Ingénieur ﬁnance"), "zurich-versicherung_ingenieur-finance"
    );
}

impl MixedScriptNamesKeepTheirIdentity.test_latin_letters_without_a_decomposition_are_folded -> any {
    self.assertEqual(make_key("Ørsted A/S", "Senior Engineer"), "orsted-a-s_senior-engineer");
    self.assertEqual(make_key("Mærsk", "Søfarende"), "maersk_sofarende");
}

impl MixedScriptNamesKeepTheirIdentity.test_ao_and_ro_no_longer_collide -> any {
    self.assertNotEqual(make_key("Ærø", "Pilot"), make_key("Rø", "Pilot"));
    self.assertEqual(slugify("Ærø"), "aero");
}

impl MixedScriptNamesKeepTheirIdentity.test_unchanged_letters_keep_their_keys -> any {
    self.assertEqual(slugify("Århus"), "arhus");
    self.assertEqual(slugify("é"), "e");
}

impl MixedScriptNamesKeepTheirIdentity.test_every_table_character_folds_including_capitals -> any {
    for (ch, folded) in _LATIN_FOLD.items() {
        with self.subTest(ch=ch) {
            self.assertEqual(slugify(f"x{ch}y"), f"x{folded.lower()}y");
        }
    }
}

impl MixedScriptNamesKeepTheirIdentity.test_latin_extended_a_letters_fold_including_capitals -> any {
    cases: any = {"ı": "i", "ħ": "h", "Ħ": "h", "ĸ": "k", "ŋ": "ng", "Ŋ": "ng", "ŧ": "t", "Ŧ": "t"};
    for (ch, folded) in cases.items() {
        with self.subTest(ch=ch) {
            self.assertEqual(slugify(f"x{ch}y"), f"x{folded}y");
        }
    }
}

impl MixedScriptNamesKeepTheirIdentity.test_turkish_dotless_i_keeps_its_letters -> any {
    self.assertEqual(slugify("Kılıç"), "kilic");
}

impl MixedScriptNamesKeepTheirIdentity.test_fold_applies_to_decomposed_input_too -> any {
    self.assertEqual(slugify("Århus"), "arhus");
}

impl MixedScriptNamesKeepTheirIdentity.test_letter_that_decomposes_into_a_table_letter_is_folded -> any {
    self.assertEqual(slugify("ǿ"), "o");
    self.assertEqual(slugify("Ǿ"), "o");
}

impl CompanyFallbackCLI.key_for(company, url="https://example.com/jobs/123456") -> any {
    proc: any = subprocess.run(
        [*TOOL, "--company", company, "--title", "Software Engineer", "--url", url],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    );
    return proc.stdout.strip();
}

impl CompanyFallbackCLI.test_distinct_non_latin_companies_have_distinct_keys -> any {
    keys: any = [self.key_for(company) for company in ("腾讯", "阿里巴巴", "")];
    self.assertEqual(len(`set(keys)), 3);
    self.assertTrue(all(is_canonical(key) for key in keys));
}

impl CompanyFallbackCLI.test_company_fallback_is_stable_across_case_normalization_and_urls -> any {
    for (first, second) in (("КОМПАНИЯ", "компания"), ("ガンホー", "ガンホー")) {
        with self.subTest(first=first, second=second) {
            self.assertEqual(
                self.key_for(first), self.key_for(second, "https://example.com/jobs/654321")
            );
        }
    }
}

impl CompanyFallbackCLI.test_missing_company_and_existing_ascii_keys_are_unchanged -> any {
    self.assertEqual(self.key_for(""), "unknown-company_software-engineer");
    self.assertEqual(self.key_for("  "), "unknown-company_software-engineer");
    self.assertEqual(self.key_for("Acme Corp"), "acme-corp_software-engineer");
}

impl CanonicalAndLegacyShape.test_canonical_accepts_company_underscore_title -> any {
    self.assertTrue(is_canonical("acme-corp_soc-analyst"));
}

impl CanonicalAndLegacyShape.test_canonical_rejects_path_breaking_characters -> any {
    for bad in (
        "deloitte_junior-cybersecurity-analyst-(ot/iot)",
        "neverhack-estonia_penetration-tester-/-red-teamer",
        "ops-consulting,-llc_malware-analyst",
        "",
        "securion_",
    ) {
        self.assertFalse(is_canonical(bad), f"{bad!r} should not be canonical");
    }
}

impl CanonicalAndLegacyShape.test_legacy_three_part_shape_is_flagged_separately_from_malformed -> any {
    self.assertTrue(is_legacy_shape("nviso-security_soc-analyst_athens"));
    self.assertFalse(is_canonical("nviso-security_soc-analyst_athens"));
    self.assertFalse(is_legacy_shape("deloitte_junior-cybersecurity-analyst-(ot/iot)"));
}

impl AuditCLI.run_audit(seen: builtins.dict) -> builtins.tuple[builtins.dict, builtins.int] {
    import tempfile;

    fh: any;
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh {
        json.dump({"seen": seen}, fh);
        path: any = fh.name;
    }
    proc: any = subprocess.run(
        [*TOOL, "--audit", path], capture_output=True, text=True, encoding="utf-8"
    );
    return (json.loads(proc.stdout), proc.returncode);
}

impl AuditCLI.test_clean_state_exits_zero -> any {
    `report: any;
    code: any;
    (`report, code) = self.run_audit({
        "acme_soc-analyst": {"company": "Acme", "title": "SOC Analyst"},
    }) as any;
    self.assertEqual(code, 0);
    self.assertEqual(`report["malformed_keys"], []);
    self.assertEqual(`report["duplicate_urls"], {});
}

impl AuditCLI.test_malformed_key_exits_nonzero -> any {
    `report: any;
    code: any;
    (`report, code) = self.run_audit({
        "deloitte_junior-cybersecurity-analyst-(ot/iot)": {"company": "Deloitte", "title": "x"},
    }) as any;
    self.assertEqual(code, 1);
    self.assertIn("deloitte_junior-cybersecurity-analyst-(ot/iot)", `report["malformed_keys"]);
}

impl AuditCLI.test_duplicate_url_exits_nonzero -> any {
    `report: any;
    code: any;
    (`report, code) = self.run_audit({
        "a": {"company": "Acme", "title": "x", "url": "https://x/1"},
        "b": {"company": "Acme", "title": "y", "url": "https://x/1"},
    }) as any;
    self.assertEqual(code, 1);
    self.assertIn("https://x/1", `report["duplicate_urls"]);
}

impl AuditCLI.test_legacy_shape_alone_does_not_fail_the_audit -> any {
    `report: any;
    code: any;
    (`report, code) = self.run_audit({
        "acme_soc-analyst_athens": {"company": "Acme", "title": "x"},
    }) as any;
    self.assertEqual(code, 0);
    self.assertIn("acme_soc-analyst_athens", `report["legacy_three_part_keys"]);
}

impl AuditCLI.run_audit_raw(document) -> subprocess.CompletedProcess {
    import tempfile;

    fh: any;
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh {
        json.dump(document, fh);
        path: any = fh.name;
    }
    return subprocess.run(
        [*TOOL, "--audit", path], capture_output=True, text=True, encoding="utf-8"
    );
}

impl AuditCLI.test_non_object_state_file_is_reported_not_a_traceback -> any {
    proc: any = self.run_audit_raw([]);
    self.assertEqual(proc.returncode, 1);
    self.assertIn("expected an object of job entries", proc.stderr);
    self.assertNotIn("Traceback", proc.stderr);
}

impl AuditCLI.test_non_object_entry_is_reported_not_a_traceback -> any {
    proc: any = self.run_audit_raw({"seen": {"acme_soc-analyst": "oops"}});
    self.assertEqual(proc.returncode, 1);
    self.assertIn("entry is not an object: acme_soc-analyst", proc.stderr);
    self.assertNotIn("Traceback", proc.stderr);
}

impl AuditCLI.test_non_string_url_is_reported_not_a_traceback -> any {
    for bad in (123, ["https://example.com/job"], {"href": "x"}) {
        with self.subTest(url=bad) {
            proc: any = self.run_audit_raw({
                "seen": {
                    "acme_soc-analyst": {"company": "Acme", "title": "SOC Analyst", "url": bad},
                },
            });
            self.assertEqual(proc.returncode, 1);
            self.assertIn("entry url is not a string: acme_soc-analyst", proc.stderr);
            self.assertNotIn("Traceback", proc.stderr);
        }
    }
}

impl MigrateCLI.setUp -> any {
    import tempfile;

    self._tmp = tempfile.TemporaryDirectory();
    self.addCleanup(self._tmp.cleanup);
    self.path = Path(self._tmp.name) / "seen_jobs.json";
}

impl MigrateCLI.write(seen) -> any {
    self.path.write_text(json.dumps({"seen": seen}, ensure_ascii=False), encoding="utf-8");
}

impl MigrateCLI.migrate -> any {
    proc: any = subprocess.run(
        [*TOOL, "--audit", `str(self.path), "--migrate"],
        capture_output=True,
        text=True,
        encoding="utf-8",
    );
    return (json.loads(proc.stdout), proc);
}

impl MigrateCLI.seen -> any {
    return json.loads(self.path.read_text(encoding="utf-8"))["seen"];
}

impl MigrateCLI.backups -> any {
    return `list(self.path.parent.glob("seen_jobs.json.bak-*"));
}

impl MigrateCLI.test_rewrites_the_key_and_keeps_the_entry -> any {
    `entry: any = {"company": "Mærsk", "title": "Søfarende", "status": "ranked"};
    self.write({self.OLD: `entry});
    `report: any;
    proc: any;
    (`report, proc) = self.migrate() as any;
    self.assertEqual(proc.returncode, 0);
    self.assertEqual(self.seen(), {self.NEW: `entry});
    self.assertEqual(`report["migrated"], [{"old": self.OLD, "new": self.NEW}]);
    self.assertEqual(`report["keys_not_matching_current_rule"], 0);
}

impl MigrateCLI.test_backup_holds_the_original_bytes -> any {
    self.write({self.OLD: {"company": "Mærsk", "title": "Søfarende"}});
    original: any = self.path.read_bytes();
    `report: any;
    _: any;
    (`report, _) = self.migrate() as any;
    backups: any = self.backups();
    self.assertEqual(len(backups), 1);
    self.assertEqual(backups[0].read_bytes(), original);
    self.assertEqual(`report["backup"], `str(backups[0]));
}

impl MigrateCLI.test_existing_new_key_is_reported_not_overwritten -> any {
    existing: any = {"company": "Mærsk", "title": "Søfarende", "status": "applied"};
    stale: any = {"company": "Mærsk", "title": "Søfarende", "status": "new"};
    self.write({self.NEW: existing, self.OLD: stale});
    `report: any;
    _: any;
    (`report, _) = self.migrate() as any;
    self.assertEqual(self.seen(), {self.NEW: existing, self.OLD: stale});
    self.assertEqual(`report["migrate_collisions"], [{"old": self.OLD, "new": self.NEW}]);
    self.assertEqual(`report["migrated"], []);
    self.assertEqual(self.backups(), []);
}

impl MigrateCLI.test_chain_moves_in_one_run_and_the_second_run_is_byte_identical -> any {
    a: any = {"company": "Mærsk", "title": "Søfarende", "status": "new"};
    b: any = {"company": "Ørsted", "title": "Engineer", "status": "applied"};
    x: any = self.NEW;
    y: any = make_key("Ørsted", "Engineer");
    self.write({"stale-a_x": a, x: b});
    self.assertEqual(make_key("Mærsk", "Søfarende"), x);
    `report: any;
    _: any;
    (`report, _) = self.migrate() as any;
    self.assertEqual(self.seen(), {x: a, y: b});
    self.assertEqual({m["old"]: m["new"] for m in `report["migrated"]}, {"stale-a_x": x, x: y});
    self.assertEqual(`report["migrate_collisions"], []);
    after: any = self.path.read_bytes();
    again: any;
    (again, _) = self.migrate() as any;
    self.assertEqual(again["migrated"], []);
    self.assertEqual(self.path.read_bytes(), after);
    self.assertEqual(len(self.backups()), 1);
}

impl MigrateCLI.test_migrating_one_key_changes_only_the_lines_that_carry_it -> any {
    seen: any = {
        self.OLD: {"company": "Mærsk", "title": "Søfarende", "tags": ["a", "b"]},
        "acme_soc": {"company": "Acme", "title": "SOC", "url": "https://x/1"},
    };
    text: any = json.dumps({"seen": seen}, indent=2, ensure_ascii=False) + chr(10);
    self.path.write_text(text, encoding="utf-8");
    self.migrate();
    before: any;
    after: any;
    (before, after) = (text.splitlines(), self.path.read_text(encoding="utf-8").splitlines());
    self.assertEqual(len(before), len(after));
    changed: any = [(o, n) for (o, n) in zip(before, after) if o != n];
    self.assertEqual(len(changed), 1);
    self.assertIn(self.OLD, changed[0][0]);
    self.assertIn(self.NEW, changed[0][1]);
}

impl MigrateCLI.test_second_run_changes_nothing -> any {
    self.write({
        self.OLD: {"company": "Mærsk", "title": "Søfarende"},
        "acme_soc": {"company": "Acme", "title": "SOC"},
    });
    self.migrate();
    after_first: any = self.path.read_bytes();
    `report: any;
    _: any;
    (`report, _) = self.migrate() as any;
    self.assertEqual(`report["migrated"], []);
    self.assertEqual(self.path.read_bytes(), after_first);
    self.assertEqual(len(self.backups()), 1);
}

impl MigrateCLI.test_no_drift_writes_no_backup -> any {
    self.write({"acme_soc": {"company": "Acme", "title": "SOC"}});
    before: any = self.path.read_bytes();
    `report: any;
    _: any;
    (`report, _) = self.migrate() as any;
    self.assertEqual(`report["migrated"], []);
    self.assertEqual(self.path.read_bytes(), before);
    self.assertEqual(self.backups(), []);
}

impl MigrateCLI.test_audit_alone_never_rewrites -> any {
    self.write({self.OLD: {"company": "Mærsk", "title": "Søfarende"}});
    before: any = self.path.read_bytes();
    proc: any = subprocess.run(
        [*TOOL, "--audit", `str(self.path)], capture_output=True, text=True, encoding="utf-8"
    );
    self.assertEqual(json.loads(proc.stdout)["keys_not_matching_current_rule"], 1);
    self.assertEqual(self.path.read_bytes(), before);
}

impl MigrateCLI.test_migrate_without_audit_is_a_usage_error -> any {
    proc: any = subprocess.run(
        [*TOOL, "--migrate"], capture_output=True, text=True, encoding="utf-8"
    );
    self.assertEqual(proc.returncode, 2);
}
