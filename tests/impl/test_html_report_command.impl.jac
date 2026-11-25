impl row(
    company: str,
    role: str,
    status: str,
    source: str = "",
    date: str = "2026-10-01",
    sector: str = "AI",
    notes: str = "",
) -> list[str] {
    values = {
        "date": date,
        "company": company,
        "role": role,
        "status": status,
        "sector": sector,
        "channel": "online",
        "source": source,
        "notes": notes,
    };
    return [values.get(h, "") for h in HEADER];
}

impl tracker(rows: list[list[str]]) -> str {
    text = io.StringIO();
    csv.writer(text, lineterminator="\n").writerows([HEADER] + rows);
    return text.getvalue();
}

impl folder(company: str, role: str) -> str {
    name = re.sub("[^\\w]", "", f"{company} {role}".lower().replace(" ", "_"));
    return re.sub("_+", "_", name).strip("_");
}

impl table(html: str, caption: str) -> dict[str, str] {
    body = re.search(f"<caption>{re.escape(caption)}</caption>(.*?)</table>", html).group(1);
    return dict(re.findall("<th scope='row'>(.*?)</th><td>(.*?)</td>", body));
}

impl HtmlReportCommandFile.test_command_file_has_its_header_and_a_body {
    first_line = COMMAND_TEXT.lstrip().splitlines()[0];
    self.assertTrue(first_line.startswith("# /html-report"), first_line);
    self.assertGreater(len(COMMAND_TEXT.strip()), 100, "Command file appears suspiciously short");
}

impl HtmlReportCommandFile.test_step1_parses_every_canonical_tracker_column {
    found = re.search(
        "Parse every row into a record with fields:\\n\\s+((?:`[^`]+`,?\\s*)+)", COMMAND_TEXT
    );
    self.assertIsNotNone(found, "Step 1 field enumeration not found");
    self.assertEqual([f.strip() for f in re.findall("`([^`]+)`", found.group(1))], HEADER);
}

impl HtmlReportCommandFile.test_command_file_states_the_table_order_and_the_figure_rules {
    columns = re.search("### Table: columns to include\\n\\n(.+)\\n", COMMAND_TEXT);
    self.assertIsNotNone(columns, "Step 3 table column list not found");
    self.assertIn("`Date` · `Deadline` · `Company`", columns.group(1));
    step2 = COMMAND_TEXT.split("## Step 3")[0].split("## Step 2")[1];
    for (needle, text) in [
        ("stage checkboxes", step2),
        ("not current status", COMMAND_TEXT),
        ("`offer_declined`", step2),
        ("not rejections", COMMAND_TEXT),
    ] {
        with self.subTest(needle=needle) {
            self.assertIn(needle, text);
        }
    }
}

impl HtmlReportCommandFile.test_reports_folder_is_gitignored {
    rules = (REPO_ROOT / ".gitignore").read_text(encoding="utf-8").splitlines();
    self.assertIn("reports/", [line.strip() for line in rules]);
}

impl HtmlReportScript.site(text: str | bytes | None, archives: dict[str, any] = {}) -> Path {
    directory = TemporaryDirectory();
    self.addCleanup(directory.cleanup);
    base = Path(directory.name);
    if text is not None {
        (base / "job_search_tracker.csv").write_bytes(
            text if isinstance(text, bytes) else text.encode("utf-8")
        );
    }
    for (name, outcome) in archives.items() {
        d = base / "documents" / "applications" / name;
        d.mkdir(parents=True);
        if outcome is not None {
            (d / "outcome.md").write_bytes(
                outcome if isinstance(outcome, bytes) else outcome.encode("utf-8")
            );
        }
    }
    return base;
}

impl HtmlReportScript.launch(
    base: Path, out: str | Path = "out.html", **kwargs: any
) -> subprocess.CompletedProcess {
    return subprocess.run(
        [*tool("html_report"), "--root", str(base), "--out", str(base / out)],
        **{"capture_output": True, "text": True, "cwd": REPO_ROOT, **kwargs},
    );
}

impl HtmlReportScript.render(
    rows: list[list[str]], archives: dict[str, any] = {}
) -> tuple[str, str] {
    base = self.site(tracker(rows), archives);
    result = self.launch(base, check=True);
    return ((base / "out.html").read_text(encoding="utf-8"), result.stdout);
}

impl HtmlReportScript.test_fixture_tracker_pins_every_figure {
    statuses = "drafted,applied,interview,offer,hired,rejected,no_response,no response,offer_declined,offer declined,withdrawn,ghosted".split(
        ","
    );
    rows = [row(f"Co{i}", "Dev", st) for (i, st) in enumerate(statuses)];
    rows[1] = row("Co1", "Dev", "applied", notes=PAYLOAD);
    (html, summary) = self.render(rows + [row("Legacy", "Dev", "applied")[:13]]);
    self.assertEqual(
        summary.split(": ", 1)[1].strip(),
        "sent 12, drafted 1, active 2, interview 1, offer 1, hired 1, closed 7, past CV screen 42%, rejection rate 43%; unrecognised status values: ghosted",
    );
    for leak in ("onmouseover='alert", "onfocus=\"alert", "<img src=x") {
        self.assertNotIn(leak, html);
    }
    self.assertIn("x&#x27; onmouseover=&#x27;alert(1)&#x27; &quot; onfocus=", html);
}

impl HtmlReportScript.test_values_are_escaped_and_page_is_offline {
    (html, _) = self.render([
        row("<script>alert(1)</script>", "Engineer", "applied", "https://example.com/job"),
        row("Acme", "Frontend", "rejected", "javascript:alert(1)"),
        row("Draftco", "Dev", "drafted"),
    ]);
    for leak in ("<script>alert(1)</script>", "href='javascript:", "@font-face") {
        self.assertNotIn(leak, html);
    }
    self.assertIn("&lt;script&gt;", html);
    self.assertEqual(
        re.findall("(?:src|href)=[\"\\'](https?://[^\"\\']+)", html), ["https://example.com/job"]
    );
}

impl HtmlReportScript.test_out_must_be_an_html_file {
    base = self.site(tracker([]));
    notes = base / "notes.txt";
    notes.write_text("keep me", encoding="utf-8");
    targets = [notes];
    try {
        (base / "out.html").symlink_to(notes);
        targets.append(base / "out.html");
    } except OSError {}
    for out in targets {
        result = self.launch(base, out);
        self.assertNotEqual(result.returncode, 0, out);
        self.assertIn("--out must end in .html", result.stderr);
        self.assertEqual(notes.read_text(encoding="utf-8"), "keep me");
    }
    hard = base / "hard.html";
    os.link(notes, hard);
    self.launch(base, hard, check=True);
    self.assertEqual(notes.read_text(encoding="utf-8"), "keep me");
    self.assertIn("<!doctype html>", hard.read_text(encoding="utf-8"));
}

impl HtmlReportScript.test_out_expands_a_quoted_home_path {
    home = self.site(tracker([]));
    subprocess.run(
        [*tool("html_report"), "--root", str(home), "--out", "~/report.html"],
        check=True,
        capture_output=True,
        cwd=home,
        env=dict(os.environ, HOME=str(home), USERPROFILE=str(home)),
    );
    self.assertTrue((home / "report.html").is_file());
    self.assertFalse((home / "~").exists());
}

impl HtmlReportScript.test_settings_and_guards_allow_the_script {
    rule = "Bash(neojac run jobsearch -- html_report:*)";
    settings = json.loads((REPO_ROOT / ".claude" / "settings.json").read_text(encoding="utf-8"));
    self.assertIn(rule, settings["permissions"]["allow"]);
    self.assertIn(rule, ALLOWED_PERMISSIONS);
    result = subprocess.run(
        [*tool("security_guards")], capture_output=True, text=True, cwd=REPO_ROOT
    );
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}

impl HtmlReportScript.test_trackers_are_read_or_refused_with_a_message {
    one = tracker([row("Acme", "Dev", "applied")]);
    short = [row("Acme", "Dev", "applied")[:13], row("Beta", "Dev", "applied")[:5]];
    resave = "re-save it as comma-separated CSV UTF-8";
    cases: list[tuple[str, bytes | None, int, str]] = [
        ("Excel UTF-8 with BOM", one.encode("utf-8-sig"), 0, "sent 1,"),
        ("rows shorter than the header", tracker(short).encode(), 0, "sent 2,"),
        (
            "capitalised header",
            b"Date,Company,Role,Status\n2026-10-01,Acme,Dev,applied\n",
            0,
            "sent 1,",
        ),
        (
            "future date",
            tracker([row("Acme", "Dev", "applied", date="2999-01-04")]).encode(),
            0,
            "sent 1,",
        ),
        (
            "cp1252",
            tracker([row("Café Ünïon", "Dev", "applied")]).encode("cp1252"),
            1,
            "re-save it as CSV UTF-8",
        ),
        ("semicolons", one.replace(",", ";").encode("utf-8-sig"), 1, resave),
        ("empty file", b"", 1, resave),
        ("no tracker", None, 1, "job_search_tracker.csv not found"),
        ("outcome.md not UTF-8", one.encode(), 1, "re-save it as UTF-8"),
    ];
    for (name, text, code, needle) in cases {
        with self.subTest(name) {
            archives: dict[str, any] = {"acme_dev": b"- [x] Phone screen caf\xe9\n"}
                if "outcome" in name
                else {};
            base = self.site(text, archives);
            result = self.launch(base);
            self.assertNotIn("Traceback", result.stderr);
            self.assertEqual(result.returncode, code, result.stderr);
            self.assertIn(needle, result.stdout + result.stderr);
            if "BOM" in name {
                self.assertIn(
                    "data-v='2026-10-01'", (base / "out.html").read_text(encoding="utf-8")
                );
            }
        }
    }
}

impl HtmlReportScript.test_archive_folders_match_only_their_own_application {
    revolut = [
        ("Revolut", "Frontend Software Engineer"),
        ("Revolut", "Software Engineer (Frontend)"),
    ];
    roles = [("Acme", "Engineering Manager"), ("Acme", "Engineer")];
    prefix = [("Metabase", "Software Engineer"), ("Meta", "Software Engineer")];
    older = [("Coca-Cola Europacific Partners", "Data Analyst"), ("Acme Inc.", "Sr. Engineer")];
    cafe = ("Café Müller", "Développeur");
    scripts = [
        ("Яндекс", "Инженер"),
        ("Сбер", "Аналитик"),
        ("Τράπεζα", "Μηχανικός"),
        ("Εταιρεία", "Αναλυτής"),
        ("楽天", "エンジニア"),
        ("任天堂", "開発者"),
    ];
    nfd = lambda (s: str) -> str { unicodedata.normalize("NFD", s) };
    cases: list[tuple[str, list[tuple[str, str]], str, dict[str, any], str]] = [
        (
            "new archive without outcome, older one of the same company",
            revolut,
            "rejected applied",
            {
                "revolut_frontend_software_engineer": INTERVIEWED,
                "revolut_software_engineer_frontend": None,
            },
            "50%",
        ),
        (
            "shorter role, both folders",
            roles,
            "rejected applied",
            {folder(*roles[0]): INTERVIEWED, folder(*roles[1]): None},
            "50%",
        ),
        (
            "shorter role, one folder",
            roles,
            "rejected applied",
            {folder(*roles[0]): INTERVIEWED},
            "50%",
        ),
        ("company prefix", prefix, "rejected applied", {folder(*prefix[0]): SCREEN}, "50%"),
        (
            "underscores only",
            [("Ab", "C"), ("A", "Bc")],
            "rejected rejected",
            {folder("Ab", "C"): "- [x] Final round\n", folder("A", "Bc"): None},
            "50%",
        ),
        (
            "folders named under the older rule",
            older,
            "rejected rejected",
            {
                "coca-cola_europacific_partners_data_analyst": SCREEN,
                "acme_inc._sr._engineer": SCREEN,
            },
            "100%",
        ),
        ("vowel signs", [("टाटा", "इंजीनियर")], "rejected", {"टाटा_इंजीनियर": SCREEN}, "100%"),
        ("NFD folder", [cafe], "rejected", {nfd("café_müller_développeur"): SCREEN}, "100%"),
        (
            "NFD row",
            [(nfd(cafe[0]), nfd(cafe[1]))],
            "rejected",
            {unicodedata.normalize("NFC", "café_müller_développeur"): SCREEN},
            "100%",
        ),
        (
            "non-Latin scripts",
            scripts,
            "rejected rejected rejected rejected rejected rejected",
            {folder(*n): (SCREEN if n == scripts[3] else None) for n in scripts},
            "17%",
        ),
    ];
    for (name, names, statuses, archives, expected) in cases {
        with self.subTest(name) {
            rows = [row(c, r, st) for ((c, r), st) in zip(names, statuses.split())];
            (_, summary) = self.render(rows, archives);
            self.assertEqual(re.search("past CV screen (\\S+),", summary).group(1), expected);
        }
    }
}

impl HtmlReportScript.test_rendered_figures {
    rejected = [row("Acme", "Dev", "rejected")];
    checklist = "# Outcome: Acme — Dev\n\n## Interview stages reached\n- [X] Phone screen\n- [ ] Final round\n\n## Notes\n- [x] Offer received from someone else\n";
    over_time = "Applications over time";
    stopped = "Where closed applications stopped";
    cases: list[dict[str, any]] = [
        {
            "name": "empty cells and the rate reading",
            "rows": [row("Acme", "Dev", "ghosted", sector="")],
            "html": ["(ghosted) are counted under Closed but left out of the rate"],
            "not html": [">None<"],
        },
        {
            "name": "hired and unrecognised statuses",
            "rows": [row("Acme", "Dev", "hired"), row("Beta", "Dev", "ghosted")],
            "summary": ["hired 1,", "; unrecognised status values: ghosted"],
            "html": ["Hired</span><span class='kpi-value num'>1<"],
        },
        {
            "name": "rows of bare commas",
            "rows": [row("Acme", "Dev", "applied"), [""] * len(HEADER)],
            "summary": ["sent 1,"],
            "not summary": ["unrecognised"],
        },
        {
            "name": "finished search charted by month up to its last application",
            "rows": [
                row("Acme", "Dev", "applied", date="2024-01-05"),
                row("Beta", "Dev", "rejected", date="2024-03-20"),
            ],
            "html": ["Sent, per month"],
            "exact": {over_time: {"Jan 2024": "1", "Feb 2024": "0", "Mar 2024": "1"}},
        },
        {
            "name": "recent search charted by week",
            "rows": [row("Acme", "Dev", "applied", date=datetime.date.today().isoformat())],
            "html": ["Sent, per week"],
        },
        {
            "name": "active rows without a usable date",
            "rows": [
                row("Acme", "Dev", "applied", date="01-10-2026"),
                row("Beta", "Dev", "applied", date="02-10-2026"),
            ],
            "html": ["2 active applications have no usable date"],
            "not html": ["Nothing is waiting on a reply"],
        },
        {
            "name": "year-only date is charted and waits",
            "rows": [
                row("Acme", "Dev", "applied", date="2025"),
                row("Beta", "Dev", "rejected", date="2026-02-11"),
            ],
            "html": ["since 2025"],
            "exact": {over_time: {"2025": "1", "2026": "1"}},
        },
        {
            "name": "typo years and slash dates",
            "rows": [
                row(c, "Dev", "applied", date=d)
                for (c, d) in zip(
                    "ABCDE", ["2999", "9999-12-31", "0001-01-01", "2026/02/03", "2026-03-04"]
                )
            ],
            "html": ["3 without a usable date, left out"],
            "exact": {over_time: {"Feb 2026": "1", "Mar 2026": "1"}},
        },
        {
            "name": "uppercase scheme links and blank sector",
            "rows": [row("Acme", "Dev", "applied", "HTTPS://example.com/job", sector="   ")],
            "html": ["href='HTTPS://example.com/job'"],
            "tables": {"Sent by sector": {"Unspecified": "1"}},
        },
        {
            "name": "offer_declined reached offer",
            "rows": [row("Acme", "Dev", "offer_declined")],
            "tables": {
                "Application funnel": {"Interview": "1", "Offer": "1", "Hired": "0"},
                stopped: {"Offer": "1"},
            },
        },
        {
            "name": "stopped chart agrees with the funnel on ticked stages",
            "rows": rejected,
            "archives": {"acme_dev": INTERVIEWED + "- [ ] Final round\n"},
            "tables": {
                "Application funnel": {"Interview": "1"},
                stopped: {"Technical round": "1", "Application screen": "0"},
            },
        },
        {
            "name": "folders sharing a key merge their stages",
            "rows": [row("Acme Inc.", "Dev", "rejected")],
            "archives": {
                "acme_inc._dev": SCREEN + "- [x] Final round\n",
                "acme_inc_dev": "- [ ] Phone screen\n",
            },
            "summary": ["past CV screen 100%"],
            "tables": {stopped: {"Final round": "1"}},
        },
        {
            "name": "only the stages checklist counts, uppercase ticks included",
            "rows": rejected,
            "archives": {"acme_dev": checklist},
            "summary": ["past CV screen 100%"],
            "tables": {"Application funnel": {"Offer": "0"}},
        },
    ];
    for c in cases {
        with self.subTest(c["name"]) {
            (html, summary) = self.render(c["rows"], c.get("archives", {}));
            for (key, text) in (("html", html), ("summary", summary)) {
                for needle in c.get(key, []) {
                    self.assertIn(needle, text);
                }
                for needle in c.get("not " + key, []) {
                    self.assertNotIn(needle, text);
                }
            }
            for (caption, expected) in c.get("exact", {}).items() {
                self.assertEqual(table(html, caption), expected);
            }
            for (caption, expected) in c.get("tables", {}).items() {
                found = table(html, caption);
                self.assertEqual({k: found.get(k) for k in expected}, expected, caption);
            }
        }
    }
}

impl HtmlReportScript.test_malformed_dates_are_not_charted_and_dates_sort_chronologically {
    dates = ["2026-foo", "2026-02-03foo", "2026-9-30", "2026-10-01"];
    (html, _) = self.render([row(c, "Dev", "applied", date=d) for (c, d) in zip("ABCD", dates)]);
    self.assertIn("2 without a usable date, left out", html);
    order = re.findall("<td class='num' data-v='([^']*)'>", html);
    self.assertEqual(order[:2], ["2026-10-01", "2026-09-30"]);
}

impl HtmlReportLintIntegration.test_lint_passes_on_real_repo {
    result = subprocess.run([*tool("lint_skills")], capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
    self.assertIn("OK", result.stdout);
}
