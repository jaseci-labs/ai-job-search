graph layers {
    layer all { *; }
}

graph spaces {
    space jobsearch: cpython { entry cli; salary_lookup | tests | tests.* | tools.*; }

    app jobsearch { run jobsearch; }
}

graph import {
    tools.page_decode ++> tools.fetch_page { decode_page }
    tools.robots_check ++> tools.fetch_page { BROWSER, _force_utf8_output, gate }
    tools.report_data ++> tools.html_report { STAGES, STATUS_ORDER, load, when }
    tools.security_guards ++> tools.install_portal_clis { FORBIDDEN_SCRIPTS, INSTALL_CONFIG_FILES }
    tools.page_decode ++> tools.posting_guard { decode_page }
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
    tests._tools ++> tests.test_apply_records_application { tool }
    tests._tools ++> tests.test_check_framework_version { root_at, tool }
    tests._tools ++> tests.test_check_upstream_updates { root_at, tool }
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
    tests._tools ++> tests.test_salary_cli { root_at, tool }
    tools.fetch_page as fetch_page ++> tests.test_fetch_deflate;
    tests._tools ++> tests.test_html_report_command { tool }
    tests._tools ++> tests.test_install_portal_hooks { rooted, tool }
    tools.job_key ++> tests.test_job_key {
        _LATIN_FOLD,
        is_canonical,
        is_legacy_shape,
        make_key,
        slugify,
    }
    tests._tools ++> tests.test_job_key { tool }
    tests._tools ++> tests.test_lint_skills { root_at, tool }
    tests._tools ++> tests.test_notion_sync_command { tool }
    tests._tools ++> tests.test_outcome_followup { tool }
    tools.page_decode ++> tests.test_page_decode { decode_page, declared_codec }
    tools.posting_guard as posting_guard ++> tests.test_posting_guard;
    tests._tools ++> tests.test_rank_command { tool }
    tests._tools ++> tests.test_rank_rounding_cli { tool }
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
    tests._tools ++> tests.test_upskill_skill { tool }
    tests.test_check_upstream_updates ++> tests.test_upstream_crossrefs {
        UpstreamCheckerRepoFixture,
        FRONTMATTER,
    }
    tests._tools ++> tests.test_upstream_crossrefs { tool }
    tests._tools ++> tests.test_upstream_triage { tool }
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
    tests._tools ++> tests.test_rank_state { tool }
    tests._bash ++> tests.test_reset_command { find_bash }
    tests._upstream ++> tests.test_reset_command { is_upstream_checkout }
    tools.check_upstream_updates ++> tests.test_reset_command { get_framework_version_from_text }
    tests._bash ++> tests.test_reset_documents { find_bash }
    tools.security_guards as security_guards ++> tests.test_security_guards;
    tests._tools ++> tests.test_security_guards { rooted, tool }
    tests._upstream ++> tests.test_security_guards { is_upstream_checkout }
    tests._upstream ++> tests.test_setup_command { is_upstream_checkout }
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
    tests._tools ++> tests.test_install_portal_clis { rooted, tool }
    tools.check_framework_version as check_framework_version ++> tests.test_check_framework_version;
    tests._tools ++> tests.test_salary_lookup { root_at, tool }
    tests._tools ++> tests.test_tools_utf8_output { rooted, tool }
    tools.verify_layout as verify_layout ++> tests.test_tools_utf8_output;
    tools.rank_state as rank_state ++> tests.test_rank_command;
    tests._tools ++> tests.test_robots_check { REPO, tool }
}
