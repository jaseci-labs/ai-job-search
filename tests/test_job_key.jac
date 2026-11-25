import json, subprocess, tempfile, unittest;
import from pathlib { Path }

glob TOOL: list[str] = tool("job_key"),
     OLD: str = "mrsk_sfarende",
     NEW: str = "maersk_sofarende",
     MAERSK: dict[str, str] = {"company": "Mærsk", "title": "Søfarende"},
     LINKEDIN: str = "https://kr.linkedin.com/jobs/view/x-4461771225",
     FREEHIRE: str = "https://freehire.me/jobs/";

class Slugify(unittest.TestCase) {
    def test_slugs {
        cases: list[tuple[str, str]] = [
            ("Acme Corp", "acme-corp"),
            ("Ops Consulting, LLC", "ops-consulting-llc"),
            ("Penetration Tester / Red Teamer", "penetration-tester-red-teamer"),
            ("Junior Cybersecurity Analyst (OT/IoT)", "junior-cybersecurity-analyst-ot-iot"),
            ("시큐리온", ""),
            ("Код Безопасности", ""),
            ("Ærø", "aero"),
            ("Århus", "arhus"),
            ("A" + chr(0x30A) + "rhus", "arhus"),
            ("é", "e"),
            ("Kılıç", "kilic"),
            ("ǿ", "o"),
            ("Ǿ", "o"),
            ("xıy", "xiy"),
            ("xħy xĦy", "xhy-xhy"),
            ("xĸy", "xky"),
            ("xŋy xŊy", "xngy-xngy"),
            ("xŧy xŦy", "xty-xty"),
        ];
        for (text, slug) in cases {
            with self.subTest(text=text) {
                self.assertEqual(slugify(text), slug);
            }
        }
    }

    def test_every_table_character_folds_including_capitals {
        for (ch, folded) in _LATIN_FOLD.items() {
            with self.subTest(ch=ch) {
                self.assertEqual(slugify(f"x{ch}y"), f"x{folded.lower()}y");
            }
        }
    }
}

class MakeKey(unittest.TestCase) {
    def test_exact_keys {
        cases: list[tuple[str, str, str, str]] = [
            ("Acme Corp", "SOC Analyst (L2)", "", "acme-corp_soc-analyst-l2"),
            ("SecuriON", "안드로이드 앱(악성코드) 분석가 채용", LINKEDIN, "securion_4461771225"),
            ("Acme", "Инженер 1 категории", LINKEDIN, "acme_1-4461771225"),
            ("Acme", "", "https://example.com/jobs/abc-xyz", "acme_https-example-com-jobs-abc-xyz"),
            (
                "Zürich Versicherung",
                "Ingénieur ﬁnance",
                "",
                "zurich-versicherung_ingenieur-finance",
            ),
            ("Ørsted A/S", "Senior Engineer", "", "orsted-a-s_senior-engineer"),
            ("Mærsk", "Søfarende", "", NEW),
        ];
        for (company, title, url, key) in cases {
            with self.subTest(key=key) {
                self.assertEqual(make_key(company, title, url=url), key);
                self.assertTrue(is_canonical(key));
            }
        }
    }

    def test_distinct_postings_get_distinct_canonical_keys {
        long_title: str = "Cyber Intelligence Center Security Analyst with trailing text ";
        cases: list[tuple[tuple[str, str, str], tuple[str, str, str]]] = [
            (("Deloitte", long_title + "A", ""), ("Deloitte", long_title + "B", "")),
            (
                ("ООО Чен", "Инженер", FREEHIRE + "inzhener-ooo-chen-hlk3qjfg"),
                ("ООО Чен", "Инженер", FREEHIRE + "inzhener-mup-g-khabarovska-tep"),
            ),
            (
                ("Яндекс", "Программист 1С", FREEHIRE + "programmist-1s-aaa"),
                ("Яндекс", "Аналитик 1С", FREEHIRE + "analitik-1s-bbb"),
            ),
            (
                ("ООО Чен", "Python-разработчик", FREEHIRE + "python-razrabotchik-x1"),
                ("ООО Чен", "Python-аналитик", FREEHIRE + "python-analitik-x2"),
            ),
            (
                ("Сбер AI", "ML Engineer", "https://example.com/1"),
                ("Яндекс AI", "ML Engineer", "https://example.com/2"),
            ),
            (("Ærø", "Pilot", ""), ("Rø", "Pilot", "")),
        ];
        for (first, second) in cases {
            with self.subTest(first=first, second=second) {
                (a, b) = (make_key(*first), make_key(*second));
                self.assertNotEqual(a, b);
                self.assertTrue(is_canonical(a) and is_canonical(b));
            }
        }
    }

    def test_one_posting_keeps_one_key {
        long_title: str = "Cyber Intelligence Center Security Analyst with an unusually long title";
        self.assertEqual(make_key("Deloitte", long_title), make_key("Deloitte", long_title));
        url: str = FREEHIRE + "inzhener-ooo-chen-hlk3qjfg";
        first: str = make_key("ООО Чен", "Инженер", url=url);
        self.assertTrue(is_canonical(first));
        for title in ("инженер", "Инженер-механик") {
            self.assertEqual(make_key("ООО Чен", title, url=url), first);
        }
        self.assertEqual(
            make_key("Сбер AI", "ML Engineer", url="https://example.com/1").split("_", 1)[0],
            make_key("сбер ai", "ML Engineer", url="https://example.com/2").split("_", 1)[0],
        );
    }

    def test_fallbacks_keep_a_readable_canonical_shape {
        cases: list[tuple[str, str, str, str]] = [
            ("SecuriON", "안드로이드 앱 분석가", "", "^securion_."),
            ("Код Безопасности", "Malware Analytic", "", "^[^_]"),
            (
                "ООО Чен",
                "Python-разработчик",
                FREEHIRE + "python-razrabotchik-x1",
                "^[^_]+_python-",
            ),
            ("Сбер AI", "ML Engineer", "https://example.com/1", "^ai-"),
            ("Яндекс AI", "ML Engineer", "https://example.com/2", "^ai-"),
            ("Acme", "", "", "^acme_untitled-"),
        ];
        for (company, title, url, shape) in cases {
            with self.subTest(company=company, title=title) {
                key: str = make_key(company, title, url=url);
                self.assertRegex(key, shape);
                self.assertTrue(is_canonical(key));
            }
        }
    }
}

class CompanyFallbackCLI(unittest.TestCase) {
    def key_for(company: str, url: str = "https://example.com/jobs/123456") -> str {
        return capture(
            [*TOOL, "--company", company, "--title", "Software Engineer", "--url", url],
            encoding="utf-8",
            check=True,
        ).stdout.strip();
    }

    def test_distinct_non_latin_companies_have_distinct_keys {
        keys: list[str] = [self.key_for(company) for company in ("腾讯", "阿里巴巴", "")];
        self.assertEqual(len(set(keys)), 3);
        self.assertTrue(all([is_canonical(key) for key in keys]));
    }

    def test_company_fallback_is_stable_across_case_normalization_and_urls {
        for (first, second) in (("КОМПАНИЯ", "компания"), ("ガンホー", "カ" + chr(0x3099) + "ンホー")) {
            with self.subTest(first=first, second=second) {
                self.assertEqual(
                    self.key_for(first), self.key_for(second, "https://example.com/jobs/654321")
                );
            }
        }
    }

    def test_missing_company_and_existing_ascii_keys_are_unchanged {
        for (company, key) in (
            ("", "unknown-company"),
            ("  ", "unknown-company"),
            ("Acme Corp", "acme-corp"),
        ) {
            with self.subTest(company=company) {
                self.assertEqual(self.key_for(company), f"{key}_software-engineer");
            }
        }
    }
}

class CanonicalAndLegacyShape(unittest.TestCase) {
    def test_shapes {
        cases: list[tuple[str, bool, bool]] = [
            ("acme-corp_soc-analyst", True, False),
            ("nviso-security_soc-analyst_athens", False, True),
            ("deloitte_junior-cybersecurity-analyst-(ot/iot)", False, False),
            ("neverhack-estonia_penetration-tester-/-red-teamer", False, False),
            ("ops-consulting,-llc_malware-analyst", False, False),
            ("", False, False),
            ("securion_", False, False),
        ];
        for (key, canonical, legacy) in cases {
            with self.subTest(key=key) {
                self.assertEqual((is_canonical(key), is_legacy_shape(key)), (canonical, legacy));
            }
        }
    }
}

class StateFile(unittest.TestCase) {
    def setUp {
        tmp: tempfile.TemporaryDirectory = tempfile.TemporaryDirectory();
        self.addCleanup(tmp.cleanup);
        self.path = Path(tmp.name) / "seen_jobs.json";
    }

    def write(seen: any) -> bytes {
        self.path.write_text(json.dumps({"seen": seen}, ensure_ascii=False), encoding="utf-8");
        return self.path.read_bytes();
    }

    def audit(*flags: str) -> subprocess.CompletedProcess {
        return capture([*TOOL, "--audit", str(self.path), *flags], encoding="utf-8");
    }

    def migrate -> dict[str, any] {
        return json.loads(self.audit("--migrate").stdout);
    }

    def seen -> dict[str, any] {
        return json.loads(self.path.read_text(encoding="utf-8"))["seen"];
    }

    def backups -> list[Path] {
        return list(self.path.parent.glob("seen_jobs.json.bak-*"));
    }
}

class AuditCLI(StateFile) {
    def test_exit_code_and_report {
        bad: str = "deloitte_junior-cybersecurity-analyst-(ot/iot)";
        legacy: str = "acme_soc-analyst_athens";
        cases: list[tuple[dict[str, any], int, dict[str, any]]] = [
            (
                {"acme_soc-analyst": {"company": "Acme", "title": "SOC Analyst"}},
                0,
                {"malformed_keys": [], "duplicate_urls": {}},
            ),
            ({bad: {"company": "Deloitte", "title": "x"}}, 1, {"malformed_keys": [bad]}),
            (
                {
                    "a": {"company": "Acme", "title": "x", "url": "https://x/1"},
                    "b": {"company": "Acme", "title": "y", "url": "https://x/1"},
                },
                1,
                {"duplicate_urls": {"https://x/1": ["a", "b"]}},
            ),
            ({legacy: {"company": "Acme", "title": "x"}}, 0, {"legacy_three_part_keys": [legacy]}),
        ];
        for (seen, code, expected) in cases {
            with self.subTest(expected=expected) {
                self.write(seen);
                proc: subprocess.CompletedProcess = self.audit();
                self.assertEqual(proc.returncode, code);
                found: dict[str, any] = json.loads(proc.stdout);
                self.assertEqual({field: found[field] for field in expected}, expected);
            }
        }
    }

    def test_unusable_state_is_reported_not_a_traceback {
        job: dict[str, any] = {"company": "Acme", "title": "SOC Analyst"};
        cases: list[tuple[any, str]] = [
            ([], "expected an object of job entries"),
            ({"seen": {"acme_soc-analyst": "oops"}}, "entry is not an object: acme_soc-analyst"),
            *[
                (
                    {"seen": {"acme_soc-analyst": {**job, "url": url}}},
                    "entry url is not a string: acme_soc-analyst",
                )
                for url in (123, ["https://example.com/job"], {"href": "x"})
            ],
        ];
        for (document, message) in cases {
            with self.subTest(document=document) {
                self.path.write_text(json.dumps(document), encoding="utf-8");
                proc: subprocess.CompletedProcess = self.audit();
                self.assertEqual(proc.returncode, 1);
                self.assertIn(message, proc.stderr);
                self.assertNotIn("Traceback", proc.stderr);
            }
        }
    }
}

class MigrateCLI(StateFile) {
    def test_rewrites_the_key_and_keeps_the_entry {
        job: dict[str, str] = {**MAERSK, "status": "ranked"};
        self.write({OLD: job});
        proc: subprocess.CompletedProcess = self.audit("--migrate");
        found: dict[str, any] = json.loads(proc.stdout);
        self.assertEqual(proc.returncode, 0);
        self.assertEqual(self.seen(), {NEW: job});
        self.assertEqual(found["migrated"], [{"old": OLD, "new": NEW}]);
        self.assertEqual(found["keys_not_matching_current_rule"], 0);
    }

    def test_backup_holds_the_original_bytes {
        original: bytes = self.write({OLD: MAERSK});
        found: dict[str, any] = self.migrate();
        backups: list[Path] = self.backups();
        self.assertEqual(len(backups), 1);
        self.assertEqual(backups[0].read_bytes(), original);
        self.assertEqual(found["backup"], str(backups[0]));
    }

    def test_existing_new_key_is_reported_not_overwritten {
        state: dict[str, any] = {
            NEW: {**MAERSK, "status": "applied"},
            OLD: {**MAERSK, "status": "new"},
        };
        self.write(state);
        found: dict[str, any] = self.migrate();
        self.assertEqual(self.seen(), state);
        self.assertEqual(found["migrate_collisions"], [{"old": OLD, "new": NEW}]);
        self.assertEqual(found["migrated"], []);
        self.assertEqual(self.backups(), []);
    }

    def test_chain_moves_in_one_run_and_the_second_run_is_byte_identical {
        a: dict[str, str] = {**MAERSK, "status": "new"};
        b: dict[str, str] = {"company": "Ørsted", "title": "Engineer", "status": "applied"};
        moved: str = make_key("Ørsted", "Engineer");
        self.write({"stale-a_x": a, NEW: b});
        found: dict[str, any] = self.migrate();
        self.assertEqual(self.seen(), {NEW: a, moved: b});
        self.assertEqual(
            {m["old"]: m["new"] for m in found["migrated"]}, {"stale-a_x": NEW, NEW: moved}
        );
        self.assertEqual(found["migrate_collisions"], []);
        after: bytes = self.path.read_bytes();
        self.assertEqual(self.migrate()["migrated"], []);
        self.assertEqual(self.path.read_bytes(), after);
        self.assertEqual(len(self.backups()), 1);
    }

    def test_migrating_one_key_changes_only_the_lines_that_carry_it {
        seen: dict[str, any] = {
            OLD: {**MAERSK, "tags": ["a", "b"]},
            "acme_soc": {"company": "Acme", "title": "SOC", "url": "https://x/1"},
        };
        text: str = json.dumps({"seen": seen}, indent=2, ensure_ascii=False) + "\n";
        self.path.write_text(text, encoding="utf-8");
        self.migrate();
        (before, after) = (text.splitlines(), self.path.read_text(encoding="utf-8").splitlines());
        self.assertEqual(len(before), len(after));
        changed: list[tuple[str, str]] = [(o, n) for (o, n) in zip(before, after) if o != n];
        self.assertEqual(len(changed), 1);
        self.assertIn(OLD, changed[0][0]);
        self.assertIn(NEW, changed[0][1]);
    }

    def test_second_run_changes_nothing {
        self.write({OLD: MAERSK, "acme_soc": {"company": "Acme", "title": "SOC"}});
        self.migrate();
        after_first: bytes = self.path.read_bytes();
        self.assertEqual(self.migrate()["migrated"], []);
        self.assertEqual(self.path.read_bytes(), after_first);
        self.assertEqual(len(self.backups()), 1);
    }

    def test_no_drift_writes_no_backup {
        before: bytes = self.write({"acme_soc": {"company": "Acme", "title": "SOC"}});
        self.assertEqual(self.migrate()["migrated"], []);
        self.assertEqual(self.path.read_bytes(), before);
        self.assertEqual(self.backups(), []);
    }

    def test_audit_alone_never_rewrites {
        before: bytes = self.write({OLD: MAERSK});
        self.assertEqual(json.loads(self.audit().stdout)["keys_not_matching_current_rule"], 1);
        self.assertEqual(self.path.read_bytes(), before);
    }

    def test_migrate_without_audit_is_a_usage_error {
        proc: subprocess.CompletedProcess = capture([*TOOL, "--migrate"], encoding="utf-8");
        self.assertEqual(proc.returncode, 2);
    }
}
