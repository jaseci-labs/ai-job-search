impl indent(line: builtins.str) -> builtins.int {
    return len(line) - len(line.lstrip());
}

impl key_indent(line: builtins.str) -> builtins.int {
    return indent(line) + (2 if line.lstrip().startswith("- ") else 0);
}

impl WorkflowHardeningTests.test_workflows_found -> any {
    self.assertTrue(WORKFLOWS);
}

impl WorkflowHardeningTests.test_every_checkout_drops_its_credentials -> any {
    for path in WORKFLOWS {
        lines: any = path.read_text(encoding="utf-8").splitlines();
        for (i, line) in enumerate(lines) {
            if "uses: actions/checkout@" not in line {
                continue;
            }
            keys: any = key_indent(line);
            block: any = [];
            for following in lines[i + 1:] {
                if following.strip() and indent(following) < keys {
                    break;
                }
                block.append(following.strip());
            }
            with self.subTest(workflow=path.name, line=i + 1) {
                self.assertIn("persist-credentials: false", block);
            }
        }
    }
}

impl WorkflowHardeningTests.test_pull_request_values_stay_out_of_run_scripts -> any {
    for path in WORKFLOWS {
        lines: any = path.read_text(encoding="utf-8").splitlines();
        run_keys: any = None;
        for (i, line) in enumerate(lines, 1) {
            if run_keys is not None and line.strip() and indent(line) <= run_keys {
                run_keys = None;
            }
            stripped: any = line.strip();
            if run_keys is None and stripped.startswith(("run:", "- run:")) {
                run_keys = key_indent(line);
                script: any = stripped.split("run:", 1)[1];
            } else {
                script = line if run_keys is not None else "";
            }
            for value in UNTRUSTED {
                with self.subTest(workflow=path.name, line=i, value=value) {
                    self.assertNotIn(value, script);
                }
            }
        }
    }
}
