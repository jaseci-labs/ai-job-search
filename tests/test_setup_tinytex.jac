import os, re, shutil, subprocess, tempfile, unittest;
import from pathlib { Path }

glob DARWIN: str = "Library/TinyTeX/bin/universal-darwin";

def tinytex_snippet -> str {
    block: str = bash_block(doc("SETUP.md"), "#### macOS and Linux: TinyTeX");
    return "\n".join([
        line
        for line in block.splitlines()
        if not re.match("^\\s*(curl |sh .*install-bin-unix\\.sh)", line)
    ]);
}

@unittest.skipIf(os.name == "nt", "the snippet targets macOS and Linux; Windows uses MiKTeX")
class TestTinyTeXPathSnippet(unittest.TestCase) {
    def which(name: str) -> str {
        return shutil.which(name) or self.skipTest(f"{name} not installed");
    }

    def run_snippet(
        shell: str,
        layout: str | None,
        opts: list[str] = [],
        existing: list[str] = [],
        fake_os: str = "",
    ) -> tuple[subprocess.CompletedProcess, Path, dict[str, str]] {
        home: Path = Path(tempfile.mkdtemp());
        self.addCleanup(shutil.rmtree, home);
        for name in existing {
            (home / name).touch();
        }
        scripts: dict[str, str] = {};
        if fake_os {
            scripts["fakebin/uname"] = f"echo {fake_os}";
        }
        if layout {
            scripts[f"{layout}/lualatex"] = "echo stub lualatex";
        }
        for (rel, body) in scripts.items() {
            (home / rel).parent.mkdir(parents=True);
            (home / rel).write_text(f"#!/bin/sh\n{body}\n");
            (home / rel).chmod(493);
        }
        path: str = os.environ["PATH"];
        result = subprocess.run(
            [shell, *opts, "-c", tinytex_snippet()],
            env={
                "HOME": str(home),
                "SHELL": shell,
                "PATH": f"{home}/fakebin:{path}" if fake_os else path,
            },
            cwd=home,
            capture_output=True,
            text=True,
        );
        return (result, home, {p.name: p.read_text() for p in home.glob(".*") if p.is_file()});
    }

    def test_shells_persist_the_tinytex_bin_dir {
        for (name, opts) in (("bash", []), ("bash", ["-O", "failglob"]), ("zsh", [])) {
            for layout in (DARWIN, ".TinyTeX/bin/x86_64-linux") {
                with self.subTest(shell=name, opts=opts, layout=layout) {
                    (result, home, rc) = self.run_snippet(self.which(name), layout, opts);
                    self.assertIn(
                        f"export PATH=\"{home / layout}:$PATH\"",
                        "".join(rc.values()),
                        result.stderr,
                    );
                    self.assertIn("stub lualatex", result.stdout, result.stderr);
                }
            }
        }
    }

    def test_shells_write_nothing_when_tinytex_is_missing {
        for name in ("bash", "zsh") {
            with self.subTest(shell=name) {
                (result, _, rc) = self.run_snippet(self.which(name), None);
                self.assertNotIn("PATH", "".join(rc.values()));
                self.assertIn("not found", result.stderr);
                self.assertNotEqual(
                    result.returncode, 0, "a failed install must not look like success"
                );
            }
        }
    }

    def test_bash_appends_to_the_startup_file_bash_reads {
        cases: list[tuple[str, list[str], str]] = [
            ("Linux", [], ".bashrc"),
            ("Darwin", [], ".profile"),
            ("Darwin", [".bash_profile"], ".bash_profile"),
            ("Darwin", [".bash_login"], ".bash_login"),
            ("Darwin", [".bash_login", ".bash_profile"], ".bash_profile"),
        ];
        for (fake_os, existing, expected) in cases {
            with self.subTest(os=fake_os, existing=existing) {
                (result, _, rc) = self.run_snippet(
                    self.which("bash"), DARWIN, existing=existing, fake_os=fake_os
                );
                self.assertEqual(
                    [name for (name, text) in rc.items() if "PATH" in text],
                    [expected],
                    result.stderr,
                );
            }
        }
    }
}
