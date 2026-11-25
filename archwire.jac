graph layers {
    layer all { *; }
}

graph spaces {
    """The tools, compiled to machine code: a run starts CPython only for a tool that loads a PyPI package."""
    space jobsearch: native { entry cli; }
    """The test suite, which imports the tools as CPython modules and runs them as the jobsearch program."""
    space tests: cpython { entry tests._run; tests | tests.*; }

    """lint_skills, convert_salary_excel and verify_pdf, which load PyPI packages; jobsearch runs them as this app."""
    space pytools: cpython { entry pycli; }

    app jobsearch { run jobsearch; }
    app pytools { run pytools; }
    app tests { run tests; }
}

graph import {
    tools.check_framework_version as check_framework_version ++> cli;
    tools.check_upstream_updates as check_upstream_updates ++> cli;
    tools.convert_salary_excel as convert_salary_excel ++> pycli;
    tools.fetch_page as fetch_page ++> cli;
    tools.html_report as html_report ++> cli;
    tools.install_portal_clis as install_portal_clis ++> cli;
    tools.job_key as job_key ++> cli;
    tools.lint_skills as lint_skills ++> pycli;
    tools.posting_guard as posting_guard ++> cli;
    tools.rank_state as rank_state ++> cli;
    tools.robots_check as robots_check ++> cli;
    tools.scrape_state as scrape_state ++> cli;
    tools.security_guards as security_guards ++> cli;
    tools.upstream_triage as upstream_triage ++> cli;
    tools.verify_layout as verify_layout ++> cli;
    tools.verify_pdf as verify_pdf ++> pycli;
    salary_lookup as salary_lookup ++> cli;
    tools.page_decode ++> tools.fetch_page { decode_page }
    tools.robots_check ++> tools.fetch_page { BROWSER, _force_utf8_output, gate }
    tools.report_data ++> tools.html_report { STAGES, STATUS_ORDER, load, when }
    tools.security_guards ++> tools.install_portal_clis { FORBIDDEN_SCRIPTS, INSTALL_CONFIG_FILES }
    tools.page_decode ++> tools.posting_guard { decode_page }
    tools.rank_state ++> tools.job_key { _force_utf8_output, save_state }
    tools.job_key ++> tools.scrape_state { make_key }
    tools.rank_state ++> tools.scrape_state {
        STATE,
        TRACKER,
        _force_utf8_output,
        load_state,
        norm,
        save_state,
        tracker_pairs,
    }
    tests._tools ++> tests._specs { tool }
    tests._specs ++> tests.test_apply_records_application {
        APPLY,
        ASSISTANT,
        GMAIL_SYNC,
        HTML_REPORT,
        INTERVIEW,
        NOTION_SYNC,
        OUTCOME,
        SCRAPER,
        doc,
        expect,
        expect_all,
        lint_skills_passes,
        section,
    }
    tests._tools ++> tests.test_check_framework_version { capture, root_at, tool }
    tests._tools ++> tests.test_check_upstream_updates { capture, root_at, tool }
    salary_lookup ++> tests.test_convert_salary_excel { format_entry }
    tools.convert_salary_excel ++> tests.test_convert_salary_excel {
        INDEX_PATTERNS,
        detect_column_type,
        COMPANY_PATTERNS,
        header_matches,
        parse_numeric_cell,
        parse_sheet,
    }
    salary_lookup ++> tests.test_salary_cli { collect_validation_issues, format_entry }
    tests._tools ++> tests.test_salary_cli { capture, root_at, tool }
    tools.fetch_page as fetch_page ++> tests.test_fetch_deflate;
    tests._tools ++> tests.test_html_report_command { capture, tool }
    tools.security_guards ++> tests.test_html_report_command { ALLOWED_PERMISSIONS }
    tests._tools ++> tests.test_install_portal_hooks { capture, rooted, tool }
    tools.job_key ++> tests.test_job_key {
        _LATIN_FOLD,
        is_canonical,
        is_legacy_shape,
        make_key,
        slugify,
    }
    tests._tools ++> tests.test_job_key { capture, tool }
    tests._tools ++> tests.test_lint_skills { capture, root_at, tool }
    tests._specs ++> tests.test_notion_sync_command {
        NOTION_SYNC,
        between,
        doc,
        expect,
        expect_not,
        lint_skills_passes,
    }
    tests._specs ++> tests.test_outcome_followup {
        OUTCOME,
        between,
        doc,
        expect,
        lint_skills_passes,
    }
    tools.page_decode ++> tests.test_page_decode { decode_page, declared_codec }
    tools.posting_guard as posting_guard ++> tests.test_posting_guard;
    tests._specs ++> tests.test_apply_host_check {
        APPLY,
        RANK,
        REPO,
        between,
        doc,
        expect,
        expect_not,
        section,
    }
    tests._specs ++> tests.test_rank_command {
        EVALUATION,
        RANK,
        SCRAPER,
        between,
        doc,
        expect,
        expect_not,
        expect_re,
        h2,
        lint_skills_passes,
        section,
    }
    tests._tools ++> tests.test_rank_rounding_cli { capture, tool }
    tools.robots_check as robots_check ++> tests.test_robots_check;
    salary_lookup ++> tests.test_salary_lookup {
        format_entry,
        normalize,
        anglicize,
        extract_core_words,
        match_score,
        search_company,
        validate_data,
        collect_validation_issues,
    }
    tools.scrape_state as scrape_state ++> tests.test_scrape_state;
    tests._tools ++> tests.test_upskill_skill { capture, tool }
    tests._specs ++> tests.test_upskill_skill {
        SCRAPER,
        between,
        doc,
        expect,
        expect_not,
        h2,
        lint_skills_passes,
    }
    tests._specs ++> tests.test_company_research_cache {
        APPLY,
        EVALUATION,
        INTERVIEW,
        doc,
        expect,
        expect_re,
        h2,
        section,
    }
    tests._specs ++> tests.test_outcome_stale { OUTCOME, between, doc, expect }
    tests.test_check_upstream_updates ++> tests.test_upstream_crossrefs {
        UpstreamCheckerRepoFixture,
        FRONTMATTER,
    }
    tests._tools ++> tests.test_upstream_crossrefs { capture, tool }
    tests._tools ++> tests.test_upstream_triage { capture, tool }
    tools.verify_pdf ++> tests.test_verify_pdf {
        ROOT,
        VerificationError,
        build_parser,
        check_dump_target,
        extract_text_layer,
        find_non_ascii_date_ranges,
        normalize_text,
        parse_page_count,
        main,
        run_tool,
        verify_pdf,
    }
    tests._bash as _bash ++> tests.test_bash;
    tests._upstream ++> tests.test_changelog_structure { is_upstream_checkout }
    tests._upstream ++> tests.test_placeholder_integrity { is_upstream_checkout }
    tests._tools ++> tests.test_rank_state { capture, tool }
    tests._bash ++> tests.test_reset_command { find_bash }
    tests._upstream ++> tests.test_reset_command { is_upstream_checkout }
    tools.check_upstream_updates ++> tests.test_reset_command { get_framework_version_from_text }
    tests._bash ++> tests.test_reset_documents { find_bash }
    tools.security_guards as security_guards ++> tests.test_security_guards;
    tests._tools ++> tests.test_security_guards { capture, rooted, tool }
    tests._upstream ++> tests.test_security_guards { is_upstream_checkout }
    tests._upstream ++> tests.test_setup_command { is_upstream_checkout }
    tests._docs ++> tests.test_add_portal_command { command, check }
    tests._docs ++> tests.test_add_template_build_dir { command }
    tests._docs ++> tests.test_gmail_sync_command { command }
    tests._docs ++> tests.test_changelog_structure { REPO }
    tests._docs ++> tests.test_readme_assets { REPO, doc }
    tests._docs ++> tests.test_release_workflow { doc }
    tests._docs ++> tests.test_expand_command { REPO, between, check, command, h2, quoted, skill }
    tests._docs ++> tests.test_tracker_status_vocab { check, command, under }
    tests._docs ++> tests.test_tracker_notes_csv_safe { command, under }
    tests._docs ++> tests.test_placeholder_integrity { check, doc, skill }
    tests._docs ++> tests.test_onboarding_privacy { check, command, doc, parts }
    tests._docs ++> tests.test_latex_guidance { check, doc, under }
    tests._docs ++> tests.test_setup_command { check, command, h2, parts, quoted, skill }
    tests._docs ++> tests.test_setup_tinytex { bash_block, doc }
    tests._docs ++> tests.test_reset_documents { bash_block, check, command }
    tests._docs ++> tests.test_reset_command {
        REPO,
        bash_block,
        between,
        check,
        command,
        h2,
        skill,
    }
    tests._upstream as _upstream ++> tests.test_upstream_checkout;
    tests._upstream ++> tests.test_upstream_checkout { is_upstream_checkout }
    tools.verify_layout as verify_layout ++> tests.test_verify_layout;
    tools.verify_layout ++> tests.test_verify_layout {
        Line,
        Page,
        find_orphans,
        main,
        parse_pdf,
        `report,
        text_start,
    }
    tools.fetch_page as fetch_page ++> tests.test_fetch_page;
    tools.robots_check as robots_check ++> tests.test_fetch_page;
    tests._tools ++> tests.test_fetch_page { REPO }
    tools.install_portal_clis ++> tests.test_install_portal_clis { discover, unsafe_reason }
    tools.install_portal_clis as install_portal_clis ++> tests.test_install_portal_clis;
    tests._tools ++> tests.test_install_portal_clis { capture, rooted, tool }
    tools.check_framework_version as check_framework_version ++> tests.test_check_framework_version;
    tests._tools ++> tests.test_salary_lookup { capture, root_at, tool }
    tests._tools ++> tests.test_tools_utf8_output { rooted, tool }
    tools.verify_layout as verify_layout ++> tests.test_tools_utf8_output;
    tools.rank_state as rank_state ++> tests.test_rank_command;
    tests._tools ++> tests.test_robots_check { REPO, capture, tool }
    tests._tools ++> tests.test_reset_command { capture }
    tests._tools ++> tests.test_reset_documents { capture }
    tests._tools ++> tests.test_setup_tinytex { capture }
}
