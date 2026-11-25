impl indent(line: str) -> int {
    return len(line) - len(line.lstrip());
}

impl key_indent(line: str) -> int {
    return indent(line) + (2 if line.lstrip().startswith("- ") else 0);
}

impl WorkflowHardeningTests.test_workflows_found {
    self.assertTrue(WORKFLOWS);
}

impl WorkflowHardeningTests.test_every_checkout_drops_its_credentials {
    for path in WORKFLOWS {
        lines: list[str] = path.read_text(encoding="utf-8").splitlines();
        for (i, line) in enumerate(lines) {
            if "uses: actions/checkout@" not in line {
                continue;
            }
            block: list[str] = [];
            for following in lines[i + 1:] {
                if following.strip() and indent(following) < key_indent(line) {
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

impl WorkflowHardeningTests.test_pull_request_values_stay_out_of_run_scripts {
    for path in WORKFLOWS {
        run_keys: int | None = None;
        for (i, line) in enumerate(path.read_text(encoding="utf-8").splitlines(), 1) {
            if run_keys is not None and line.strip() and indent(line) <= run_keys {
                run_keys = None;
            }
            script: str = line if run_keys is not None else "";
            if run_keys is None and line.strip().startswith(("run:", "- run:")) {
                run_keys = key_indent(line);
                script = line.split("run:", 1)[1];
            }
            for value in UNTRUSTED {
                with self.subTest(workflow=path.name, line=i, value=value) {
                    self.assertNotIn(value, script);
                }
            }
        }
    }
}
