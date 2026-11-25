impl HtmlReportCommandFileTests.test_command_file_exists -> any {
    self.assertTrue(COMMAND_FILE.exists(), f"{COMMAND_FILE} not found");
}

impl HtmlReportCommandFileTests.test_command_file_starts_with_correct_header -> any {
    text: any = COMMAND_FILE.read_text(encoding="utf-8");
    first_line: any = text.lstrip().splitlines()[0];
    self.assertTrue(
        first_line.startswith("# /html-report"),
        f"Command file must start with '# /html-report', got: {first_line!r}",
    );
}

impl HtmlReportCommandFileTests.test_command_file_is_non_empty -> any {
    text: any = COMMAND_FILE.read_text(encoding="utf-8").strip();
    self.assertGreater(len(text), 100, "Command file appears suspiciously short");
}

impl HtmlReportTrackerFieldTests.test_step1_parses_every_canonical_tracker_column -> any {
    text: any = COMMAND_FILE.read_text(encoding="utf-8");
    `match: any = re.search(
        "Parse every row into a record with fields:\\n\\s+((?:`[^`]+`,?\\s*)+)", text
    );
    self.assertIsNotNone(`match, "Step 1 field enumeration not found");
    fields: any = [f.strip() for f in re.findall("`([^`]+)`", `match.group(1))];
    self.assertEqual(fields, self.CANONICAL_HEADER);
}

impl HtmlReportTrackerFieldTests.test_step3_table_columns_include_deadline_after_date -> any {
    text: any = COMMAND_FILE.read_text(encoding="utf-8");
    `match: any = re.search("### Table: columns to include\\n\\n(.+)\\n", text);
    self.assertIsNotNone(`match, "Step 3 table column list not found");
    line: any = `match.group(1);
    self.assertIn(
        "`Date` · `Deadline` · `Company`",
        line,
        "Step 3 must offer the Deadline column directly after Date - the list defines the dashboard's column order, and a swapped order reads as a different table",
    );
}

impl HtmlReportGitignoreTests.test_funnel_is_computed_from_stage_history_not_current_status -> any {
    text: any = COMMAND_FILE.read_text(encoding="utf-8");
    self.assertIn(
        "stage checkboxes",
        text.split("## Step 3")[0].split("## Step 2")[1],
        "Step 2's funnel definition must derive stage-reached from the merged outcome.md stage checkboxes",
    );
    self.assertIn(
        "not current status",
        text,
        "the funnel rule must say explicitly that current status alone undercounts",
    );
}

impl HtmlReportGitignoreTests.test_rejection_rate_excludes_declined_offers_and_withdrawals -> any {
    text: any = COMMAND_FILE.read_text(encoding="utf-8");
    self.assertIn(
        "`offer_declined`",
        text.split("## Step 3")[0].split("## Step 2")[1],
        "the rejection-rate definition must address offer_declined",
    );
    self.assertIn(
        "not rejections", text, "the rate must exclude candidate-initiated outcomes explicitly"
    );
}

impl HtmlReportGitignoreTests.test_reports_folder_is_gitignored -> any {
    rules: any = {line.strip() for line in GITIGNORE.read_text(encoding="utf-8").splitlines()};
    self.assertIn(
        "reports/",
        rules,
        "reports/ must be listed in .gitignore — generated dashboards are personal output",
    );
}

impl HtmlReportScriptTests.render(rows, archives=None) -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        `root: any = Path(tmp);
        f: any;
        with open(`root / "job_search_tracker.csv", "w", newline="", encoding="utf-8") as f {
            csv.writer(f).writerows([self.HEADER] + rows);
        }
        for (name, outcome) in (archives or {}).items() {
            d: any = `root / "documents" / "applications" / name;
            d.mkdir(parents=True);
            if outcome is not None {
                (d / "outcome.md").write_text(outcome, encoding="utf-8");
            }
        }
        out: any = `root / "out.html";
        result: any = subprocess.run(
            [*tool("html_report"), "--root", `str(`root), "--out", `str(out)],
            check=True,
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        );
        return (out.read_text(encoding="utf-8"), result.stdout);
    }
}

impl HtmlReportScriptTests.row(company, role, status, source="") -> any {
    values: any = {
        "date": "2026-10-01",
        "company": company,
        "role": role,
        "status": status,
        "sector": "AI",
        "channel": "online",
        "source": source,
    };
    return [values.get(h, "") for h in self.HEADER];
}

impl HtmlReportScriptTests.test_fixture_tracker_pins_every_figure -> any {
    statuses: any = [
        "drafted",
        "applied",
        "interview",
        "offer",
        "hired",
        "rejected",
        "no_response",
        "no response",
        "offer_declined",
        "offer declined",
        "withdrawn",
        "ghosted",
    ];
    rows: any = [self.row(f"Co{i}", "Dev", st) for (i, st) in enumerate(statuses)];
    rows.append(self.row("Legacy", "Dev", "applied")[:13]);
    rows[1][self.HEADER.index("notes")] = self.PAYLOAD;
    html: any;
    summary: any;
    (html, summary) = self.render(rows) as any;
    self.assertEqual(
        summary.split(": ", 1)[1].strip(),
        "sent 12, drafted 1, active 2, interview 1, offer 1, hired 1, closed 7, past CV screen 42%, rejection rate 43%; unrecognised status values: ghosted",
    );
    self.assertNotIn("onmouseover='alert", html);
    self.assertNotIn("onfocus=\"alert", html);
    self.assertNotIn("<img src=x", html);
    self.assertIn("x&#x27; onmouseover=&#x27;alert(1)&#x27; &quot; onfocus=", html);
}

impl HtmlReportScriptTests.test_empty_cells_do_not_print_none_and_the_rate_reading_is_stated -> any {
    row: any = self.row("Acme", "Dev", "ghosted");
    row[self.HEADER.index("sector")] = "";
    html: any;
    _: any;
    (html, _) = self.render([row]) as any;
    self.assertNotIn(">None<", html);
    self.assertIn("(ghosted) are counted under Closed but left out of the rate", html);
}

impl HtmlReportScriptTests.test_values_are_escaped_and_page_is_offline -> any {
    html: any;
    _: any;
    (html, _) = self.render([
        self.row("<script>alert(1)</script>", "Engineer", "applied", "https://example.com/job"),
        self.row("Acme", "Frontend", "rejected", "javascript:alert(1)"),
        self.row("Draftco", "Dev", "drafted"),
    ]) as any;
    self.assertNotIn("<script>alert(1)</script>", html);
    self.assertIn("&lt;script&gt;", html);
    self.assertNotIn("href='javascript:", html);
    external: any = re.findall("(?:src|href)=[\"\\'](https?://[^\"\\']+)", html);
    self.assertEqual(external, ["https://example.com/job"]);
    self.assertNotIn("@font-face", html);
}

impl HtmlReportScriptTests.test_out_must_be_an_html_file -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        `root: any = Path(tmp);
        (`root / "job_search_tracker.csv").write_text(
            ",".join(self.HEADER) + "\n", encoding="utf-8"
        );
        notes: any = `root / "notes.txt";
        notes.write_text("keep me", encoding="utf-8");
        link: any = `root / "out.html";
        try {
            link.symlink_to(notes);
            targets: any = [notes, link];
        } except OSError {
            targets = [notes];
        }
        for out in targets {
            result: any = subprocess.run(
                [*tool("html_report"), "--root", tmp, "--out", `str(out)],
                capture_output=True,
                text=True,
                cwd=REPO_ROOT,
            );
            self.assertNotEqual(result.returncode, 0, out);
            self.assertIn("--out must end in .html", result.stderr);
            self.assertEqual(notes.read_text(encoding="utf-8"), "keep me");
        }
        hard: any = `root / "hard.html";
        os.link(notes, hard);
        subprocess.run(
            [*tool("html_report"), "--root", tmp, "--out", `str(hard)],
            check=True,
            capture_output=True,
            cwd=REPO_ROOT,
        );
        self.assertEqual(notes.read_text(encoding="utf-8"), "keep me");
        self.assertIn("<!doctype html>", hard.read_text(encoding="utf-8"));
    }
}

impl HtmlReportScriptTests.test_out_expands_a_quoted_home_path -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        home: any = Path(tmp);
        (home / "job_search_tracker.csv").write_text(
            ",".join(self.HEADER) + "\n", encoding="utf-8"
        );
        env: any = `dict(os.environ, HOME=tmp, USERPROFILE=tmp);
        subprocess.run(
            [*tool("html_report"), "--root", tmp, "--out", "~/report.html"],
            check=True,
            capture_output=True,
            cwd=tmp,
            env=env,
        );
        self.assertTrue((home / "report.html").is_file());
        self.assertFalse((home / "~").exists());
    }
}

impl HtmlReportScriptTests.test_settings_and_guards_allow_the_script -> any {
    import from tools { security_guards }
    allow: any = json.loads(
        (REPO_ROOT / ".claude" / "settings.json").read_text(encoding="utf-8")
    )["permissions"]["allow"];
    for `entry in ("Bash(neojac run jobsearch -- html_report:*)",) {
        self.assertIn(`entry, allow, f"{`entry} missing from .claude/settings.json");
        self.assertIn(
            `entry,
            security_guards.ALLOWED_PERMISSIONS,
            f"{`entry} missing from security_guards.jac's reviewed allowlist",
        );
    }
    result: any = subprocess.run(
        [*tool("security_guards")], capture_output=True, text=True, cwd=REPO_ROOT
    );
    self.assertEqual(result.returncode, 0, result.stdout + result.stderr);
}

impl HtmlReportScriptTests.test_new_archive_without_outcome_is_not_matched_to_older_same_company_archive -> any {
    _: any;
    summary: any;
    (_, summary) = self.render(
        [
            self.row("Revolut", "Frontend Software Engineer", "rejected"),
            self.row("Revolut", "Software Engineer (Frontend)", "applied"),
        ],
        {
            "revolut_frontend_software_engineer": "- [x] Phone screen\n- [x] Technical interview\n",
            "revolut_software_engineer_frontend": None,
        },
    ) as any;
    self.assertIn("past CV screen 50%", summary);
}

impl HtmlReportScriptTests.run_raw(tracker_bytes) -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        `root: any = Path(tmp);
        if tracker_bytes is not None {
            (`root / "job_search_tracker.csv").write_bytes(tracker_bytes);
        }
        return subprocess.run(
            [*tool("html_report"), "--root", `str(`root), "--out", `str(`root / "out.html")],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        );
    }
}

impl HtmlReportScriptTests.csv_text(rows) -> any {
    return "\n".join([",".join(self.HEADER)] + [",".join(r) for r in rows]) + "\n";
}

impl HtmlReportScriptTests.assert_clean_exit(result, code, needle) -> any {
    self.assertNotIn("Traceback", result.stderr);
    self.assertEqual(result.returncode, code, result.stderr);
    self.assertIn(needle, result.stdout + result.stderr);
}

impl HtmlReportScriptTests.test_excel_csv_utf8_with_bom_is_read -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        `root: any = Path(tmp);
        (`root / "job_search_tracker.csv").write_bytes(
            self.csv_text([self.row("Acme", "Dev", "applied")]).encode("utf-8-sig")
        );
        result: any = subprocess.run(
            [*tool("html_report"), "--root", tmp, "--out", `str(`root / "o.html")],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        );
        self.assert_clean_exit(result, 0, "sent 1,");
        self.assertIn(
            "data-v='2026-10-01'",
            (`root / "o.html").read_text(encoding="utf-8"),
            "the BOM must not swallow the date header",
        );
    }
}

impl HtmlReportScriptTests.test_row_with_fewer_fields_than_the_header_is_kept -> any {
    short: any = self.row("Acme", "Dev", "applied")[:13];
    result: any = self.run_raw(
        self.csv_text([short, self.row("Beta", "Dev", "applied")[:5]]).encode()
    );
    self.assert_clean_exit(result, 0, "sent 2,");
}

impl HtmlReportScriptTests.test_cp1252_tracker_asks_for_a_utf8_resave -> any {
    result: any = self.run_raw(
        self.csv_text([self.row("Café Ünïon", "Dev", "applied")]).encode("cp1252")
    );
    self.assert_clean_exit(result, 1, "re-save it as CSV UTF-8");
}

impl HtmlReportScriptTests.test_semicolon_tracker_asks_for_a_comma_separated_resave -> any {
    text: any = self.csv_text([self.row("Acme", "Dev", "applied")]).replace(",", ";");
    result: any = self.run_raw(text.encode("utf-8-sig"));
    self.assert_clean_exit(result, 1, "re-save it as comma-separated CSV UTF-8");
}

impl HtmlReportScriptTests.test_empty_tracker_exits_with_a_message -> any {
    self.assert_clean_exit(self.run_raw(b""), 1, "re-save it as comma-separated CSV UTF-8");
}

impl HtmlReportScriptTests.test_capitalised_header_is_read -> any {
    result: any = self.run_raw(b"Date,Company,Role,Status\n2026-10-01,Acme,Dev,applied\n");
    self.assert_clean_exit(result, 0, "sent 1,");
}

impl HtmlReportScriptTests.test_missing_tracker_exits_with_a_message -> any {
    self.assert_clean_exit(self.run_raw(None), 1, "job_search_tracker.csv not found");
}

impl HtmlReportScriptTests.test_sent_rows_dated_in_the_future_render -> any {
    row: any = self.row("Acme", "Dev", "applied");
    row[self.HEADER.index("date")] = "2999-01-04";
    self.assert_clean_exit(self.run_raw(self.csv_text([row]).encode()), 0, "sent 1,");
}

impl HtmlReportScriptTests.test_summary_names_hired_and_unrecognised_statuses -> any {
    html: any;
    summary: any;
    (html, summary) = self.render([
        self.row("Acme", "Dev", "hired"),
        self.row("Beta", "Dev", "ghosted"),
    ]) as any;
    self.assertIn("hired 1,", summary);
    self.assertIn("; unrecognised status values: ghosted", summary);
    self.assertRegex(html, "Hired</span><span class='kpi-value num'>1<");
}

impl HtmlReportScriptTests.dated(date, status="applied", company="Acme") -> any {
    row: any = self.row(company, "Dev", status);
    row[self.HEADER.index("date")] = date;
    return row;
}

impl HtmlReportScriptTests.test_a_finished_search_is_charted_by_month_up_to_its_last_application -> any {
    html: any;
    _: any;
    (html, _) = self.render([
        self.dated("2024-01-05"),
        self.dated("2024-03-20", "rejected", "Beta"),
    ]) as any;
    self.assertIn("Sent, per month", html);
    self.assertEqual(
        self.table(html, "Applications over time"),
        {"Jan 2024": "1", "Feb 2024": "0", "Mar 2024": "1"},
    );
}

impl HtmlReportScriptTests.test_a_recent_search_is_charted_by_week -> any {
    html: any;
    _: any;
    (html, _) = self.render([self.dated(datetime.date.today().isoformat())]) as any;
    self.assertIn("Sent, per week", html);
}

impl HtmlReportScriptTests.test_active_rows_without_a_usable_date_are_counted_in_the_waiting_table -> any {
    html: any;
    _: any;
    (html, _) = self.render([
        self.dated("01-10-2026"),
        self.dated("02-10-2026", company="Beta"),
    ]) as any;
    self.assertIn("2 active applications have no usable date", html);
    self.assertNotIn("Nothing is waiting on a reply", html);
}

impl HtmlReportScriptTests.test_a_year_only_date_is_charted_and_waits -> any {
    html: any;
    _: any;
    (html, _) = self.render([
        self.dated("2025"),
        self.dated("2026-02-11", "rejected", "Beta"),
    ]) as any;
    self.assertEqual(self.table(html, "Applications over time"), {"2025": "1", "2026": "1"});
    self.assertIn("since 2025", html);
}

impl HtmlReportScriptTests.test_folders_named_under_the_older_rule_still_match -> any {
    rows: any = [
        ("Coca-Cola Europacific Partners", "Data Analyst", "rejected"),
        ("Acme Inc.", "Sr. Engineer", "rejected"),
    ];
    _: any;
    summary: any;
    (_, summary) = self.render(
        [self.row(*r) for r in rows],
        {
            "coca-cola_europacific_partners_data_analyst": "- [x] Phone screen\n",
            "acme_inc._sr._engineer": "- [x] Phone screen\n",
        },
    ) as any;
    self.assertIn("past CV screen 100%", summary);
}

impl HtmlReportScriptTests.test_folders_sharing_a_key_merge_their_stages -> any {
    html: any;
    summary: any;
    (html, summary) = self.render(
        [self.row("Acme Inc.", "Dev", "rejected")],
        {
            "acme_inc._dev": "- [x] Phone screen\n- [x] Final round\n",
            "acme_inc_dev": "- [ ] Phone screen\n",
        },
    ) as any;
    self.assertIn("past CV screen 100%", summary);
    self.assertEqual(self.table(html, "Where closed applications stopped")["Final round"], "1");
}

impl HtmlReportScriptTests.test_names_with_vowel_signs_match_a_folder_that_keeps_them -> any {
    company: any;
    role: any;
    (company, role) = ("टाटा", "इंजीनियर");
    _: any;
    summary: any;
    (_, summary) = self.render(
        [self.row(company, role, "rejected")], {f"{company}_{role}": "- [x] Phone screen\n"}
    ) as any;
    self.assertIn("past CV screen 100%", summary);
}

impl HtmlReportScriptTests.test_names_that_differ_only_in_underscores_or_accent_encoding_match_their_own_folder -> any {
    self.assertEqual(
        self.past_screen(
            [("Ab", "C", "rejected"), ("A", "Bc", "rejected")],
            {("Ab", "C"): "- [x] Final round\n", ("A", "Bc"): None},
        ),
        "50%",
    );
    nfd: any = unicodedata.normalize("NFD", "café_müller_développeur");
    _: any;
    summary: any;
    (_, summary) = self.render(
        [self.row("Café Müller", "Développeur", "rejected")], {nfd: "- [x] Phone screen\n"}
    ) as any;
    self.assertIn("past CV screen 100%", summary);
    nfd_row: any = [unicodedata.normalize("NFD", v) for v in ("Café Müller", "Développeur")];
    (_, summary) = self.render(
        [self.row(*nfd_row, "rejected")],
        {unicodedata.normalize("NFC", "café_müller_développeur"): "- [x] Phone screen\n"},
    ) as any;
    self.assertIn("past CV screen 100%", summary);
}

impl HtmlReportScriptTests.test_outcome_that_is_not_utf8_asks_for_a_resave -> any {
    tmp: any;
    with tempfile.TemporaryDirectory() as tmp {
        `root: any = Path(tmp);
        (`root / "job_search_tracker.csv").write_text(
            self.csv_text([self.row("Acme", "Dev", "applied")]), encoding="utf-8"
        );
        (`root / "documents" / "applications" / "acme_dev").mkdir(parents=True);
        (`root / "documents" / "applications" / "acme_dev" / "outcome.md").write_bytes(
            b"- [x] Phone screen caf\xe9\n"
        );
        result: any = subprocess.run(
            [*tool("html_report"), "--root", tmp, "--out", `str(`root / "o.html")],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        );
        self.assert_clean_exit(result, 1, "re-save it as UTF-8");
    }
}

impl HtmlReportScriptTests.test_typo_years_and_slash_dates_do_not_distort_the_chart -> any {
    html: any;
    _: any;
    (html, _) = self.render([
        self.dated("2999"),
        self.dated("9999-12-31", company="B"),
        self.dated("0001-01-01", company="C"),
        self.dated("2026/02/03", company="D"),
        self.dated("2026-03-04", company="E"),
    ]) as any;
    self.assertEqual(
        self.table(html, "Applications over time"), {"Feb 2026": "1", "Mar 2026": "1"}
    );
    self.assertIn("3 without a usable date, left out", html);
}

impl HtmlReportScriptTests.test_rows_of_bare_commas_are_not_applications -> any {
    _: any;
    summary: any;
    (_, summary) = self.render([
        self.row("Acme", "Dev", "applied"),
        [""] * len(self.HEADER),
    ]) as any;
    self.assertIn("sent 1,", summary);
    self.assertNotIn("unrecognised", summary);
}

impl HtmlReportScriptTests.test_only_the_stages_checklist_counts_and_uppercase_ticks_count -> any {
    outcome: any = "# Outcome: Acme — Dev\n\n## Interview stages reached\n- [X] Phone screen\n- [ ] Final round\n\n## Notes\n- [x] Offer received from someone else\n";
    html: any;
    summary: any;
    (html, summary) = self.render(
        [self.row("Acme", "Dev", "rejected")], {"acme_dev": outcome}
    ) as any;
    self.assertIn("past CV screen 100%", summary);
    self.assertEqual(self.table(html, "Application funnel")["Offer"], "0");
}

impl HtmlReportScriptTests.test_malformed_dates_are_not_charted_and_dates_sort_chronologically -> any {
    html: any;
    _: any;
    (html, _) = self.render([
        self.dated("2026-foo"),
        self.dated("2026-02-03foo", company="B"),
        self.dated("2026-9-30", company="C"),
        self.dated("2026-10-01", company="D"),
    ]) as any;
    self.assertIn("2 without a usable date, left out", html);
    order: any = re.findall("<td class='num' data-v='([^']*)'>", html);
    self.assertEqual(order[:2], ["2026-10-01", "2026-09-30"]);
}

impl HtmlReportScriptTests.test_uppercase_scheme_links_and_blank_sector_falls_back -> any {
    row: any = self.row("Acme", "Dev", "applied", "HTTPS://example.com/job");
    row[self.HEADER.index("sector")] = "   ";
    html: any;
    _: any;
    (html, _) = self.render([row]) as any;
    self.assertIn("href='HTTPS://example.com/job'", html);
    self.assertIn("Unspecified", self.table(html, "Sent by sector"));
}

impl HtmlReportScriptTests.table(html, caption) -> any {
    body: any = re.search(f"<caption>{re.escape(caption)}</caption>(.*?)</table>", html).group(1);
    return `dict(re.findall("<th scope='row'>(.*?)</th><td>(.*?)</td>", body));
}

impl HtmlReportScriptTests.test_offer_declined_reached_offer_in_the_funnel_and_the_stopped_chart -> any {
    html: any;
    _: any;
    (html, _) = self.render([self.row("Acme", "Dev", "offer_declined")]) as any;
    funnel: any = self.table(html, "Application funnel");
    self.assertEqual((funnel["Interview"], funnel["Offer"], funnel["Hired"]), ("1", "1", "0"));
    self.assertEqual(self.table(html, "Where closed applications stopped")["Offer"], "1");
}

impl HtmlReportScriptTests.test_stopped_chart_agrees_with_the_funnel_on_ticked_stages -> any {
    html: any;
    _: any;
    (html, _) = self.render(
        [self.row("Acme", "Dev", "rejected")],
        {"acme_dev": "- [x] Phone screen\n- [x] Technical interview\n- [ ] Final round\n"},
    ) as any;
    self.assertEqual(self.table(html, "Application funnel")["Interview"], "1");
    stopped: any = self.table(html, "Where closed applications stopped");
    self.assertEqual((stopped["Technical round"], stopped["Application screen"]), ("1", "0"));
}

impl HtmlReportScriptTests.folder(company, role) -> any {
    name: any = re.sub("[^\\w]", "", f"{company} {role}".lower().replace(" ", "_"));
    return re.sub("_+", "_", name).strip("_");
}

impl HtmlReportScriptTests.past_screen(rows, archives) -> any {
    _: any;
    summary: any;
    (_, summary) = self.render(
        [self.row(*r) for r in rows], {self.folder(c, r): o for ((c, r), o) in archives.items()}
    ) as any;
    return re.search("past CV screen (\\S+),", summary).group(1);
}

impl HtmlReportScriptTests.test_shorter_role_does_not_match_a_longer_roles_folder -> any {
    rows: any = [("Acme", "Engineering Manager", "rejected"), ("Acme", "Engineer", "applied")];
    both: any = {("Acme", "Engineering Manager"): self.INTERVIEWED, ("Acme", "Engineer"): None};
    self.assertEqual(self.past_screen(rows, both), "50%");
    first_only: any = {("Acme", "Engineering Manager"): self.INTERVIEWED};
    self.assertEqual(self.past_screen(rows, first_only), "50%");
}

impl HtmlReportScriptTests.test_company_prefix_does_not_match_another_company -> any {
    rows: any = [
        ("Metabase", "Software Engineer", "rejected"),
        ("Meta", "Software Engineer", "applied"),
    ];
    archives: any = {("Metabase", "Software Engineer"): "- [x] Phone screen\n"};
    self.assertEqual(self.past_screen(rows, archives), "50%");
}

impl HtmlReportScriptTests.test_non_latin_names_match_their_own_folder -> any {
    names: any = [
        ("Яндекс", "Инженер"),
        ("Сбер", "Аналитик"),
        ("Τράπεζα", "Μηχανικός"),
        ("Εταιρεία", "Αναλυτής"),
        ("楽天", "エンジニア"),
        ("任天堂", "開発者"),
    ];
    archives: any = {n: None for n in names};
    archives[names[3]] = "- [x] Phone screen\n";
    self.assertEqual(self.past_screen([(c, r, "rejected") for (c, r) in names], archives), "17%");
}

impl HtmlReportLintIntegrationTests.test_lint_passes_on_real_repo -> any {
    result: any = subprocess.run([*LINT_SCRIPT], capture_output=True, text=True);
    self.assertEqual(
        result.returncode, 0, f"lint_skills.jac failed:\n{result.stdout}{result.stderr}"
    );
    self.assertIn("OK", result.stdout);
}
