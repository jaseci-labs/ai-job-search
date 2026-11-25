impl tinytex_snippet -> any {
    text: any = SETUP.read_text(encoding="utf-8");
    section: any = text.split("#### macOS and Linux: TinyTeX", 1)[1];
    block: any = re.search("```bash\\n(.*?)```", section, re.DOTALL).group(1);
    return "\n".join(line for line in block.splitlines() if not INSTALL_LINES.match(line));
}

impl TestTinyTeXPathSnippet.run_snippet(
    shell, layout, *shell_opts_, existing=(), fake_os=None
) -> any {
    shell_opts: any = tuple(shell_opts_);
    home: any = Path(tempfile.mkdtemp());
    self.addCleanup(shutil.rmtree, home);
    for name in existing {
        (home / name).touch();
    }
    path: any = os.environ["PATH"];
    if fake_os {
        fake_bin: any = home / "fakebin";
        fake_bin.mkdir();
        uname: any = fake_bin / "uname";
        uname.write_text(f"#!/bin/sh\necho {fake_os}\n");
        uname.chmod(493);
        path = f"{fake_bin}:{path}";
    }
    bin_dir: any = None;
    if layout {
        bin_dir = home / layout;
        bin_dir.mkdir(parents=True);
        stub: any = bin_dir / "lualatex";
        stub.write_text("#!/bin/sh\necho stub lualatex\n");
        stub.chmod(493);
    }
    env: any = {"HOME": `str(home), "SHELL": shell, "PATH": path};
    result: any = subprocess.run(
        [shell, *shell_opts, "-c", tinytex_snippet()],
        env=env,
        cwd=home,
        capture_output=True,
        text=True,
    );
    rc_text: any = "".join(p.read_text() for p in home.glob(".*") if p.is_file());
    return (bin_dir, result, rc_text, home);
}

impl TestTinyTeXPathSnippet.assert_persists_bin_dir(shell, *shell_opts__) -> any {
    shell_opts: any = tuple(shell_opts__);
    for layout in ("Library/TinyTeX/bin/universal-darwin", ".TinyTeX/bin/x86_64-linux") {
        with self.subTest(shell=shell, opts=shell_opts, layout=layout) {
            bin_dir: any;
            result: any;
            rc_text: any;
            _: any;
            (bin_dir, result, rc_text, _) = self.run_snippet(shell, layout, *shell_opts) as any;
            self.assertIn(f"export PATH=\"{bin_dir}:$PATH\"", rc_text, result.stderr);
            self.assertIn("stub lualatex", result.stdout, result.stderr);
        }
    }
}

impl TestTinyTeXPathSnippet.assert_writes_nothing_without_install(shell, *shell_opts___) -> any {
    shell_opts: any = tuple(shell_opts___);
    _: any;
    result: any;
    rc_text: any;
    (_, result, rc_text, _) = self.run_snippet(shell, None, *shell_opts) as any;
    self.assertNotIn("PATH", rc_text, "a failed install must not persist an empty PATH entry");
    self.assertIn("not found", result.stderr);
    self.assertNotEqual(result.returncode, 0, "a failed install must not look like success");
}

impl TestTinyTeXPathSnippet.test_bash_persists_the_tinytex_bin_dir -> any {
    self.assert_persists_bin_dir(shutil.which("bash") or self.skipTest("bash not installed"));
}

impl TestTinyTeXPathSnippet.test_bash_writes_nothing_when_tinytex_is_missing -> any {
    self.assert_writes_nothing_without_install(
        shutil.which("bash") or self.skipTest("bash not installed")
    );
}

impl TestTinyTeXPathSnippet.test_failglob_bash_persists_the_tinytex_bin_dir -> any {
    self.assert_persists_bin_dir(
        shutil.which("bash") or self.skipTest("bash not installed"), "-O", "failglob"
    );
}

impl TestTinyTeXPathSnippet.test_bash_appends_to_the_startup_file_bash_reads -> any {
    bash: any = shutil.which("bash") or self.skipTest("bash not installed");
    cases: any = (
        ("Linux", (), ".bashrc"),
        ("Darwin", (), ".profile"),
        ("Darwin", (".bash_profile",), ".bash_profile"),
        ("Darwin", (".bash_login",), ".bash_login"),
        ("Darwin", (".bash_login", ".bash_profile"), ".bash_profile"),
    );
    for (fake_os, existing, expected) in cases {
        with self.subTest(os=fake_os, existing=existing) {
            _: any;
            result: any;
            home: any;
            (_, result, _, home) = self.run_snippet(
                bash, "Library/TinyTeX/bin/universal-darwin", existing=existing, fake_os=fake_os
            ) as any;
            written: any = [
                p.name
                for p in home.glob(".*")
                if p.is_file() and "PATH" in p.read_text()
            ];
            self.assertEqual(written, [expected], result.stderr);
        }
    }
}

impl TestTinyTeXPathSnippet.test_zsh_persists_the_tinytex_bin_dir -> any {
    self.assert_persists_bin_dir(shutil.which("zsh") or self.skipTest("zsh not installed"));
}

impl TestTinyTeXPathSnippet.test_zsh_writes_nothing_when_tinytex_is_missing -> any {
    self.assert_writes_nothing_without_install(
        shutil.which("zsh") or self.skipTest("zsh not installed")
    );
}
