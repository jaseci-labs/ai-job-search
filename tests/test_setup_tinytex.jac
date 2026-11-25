"""Run SETUP.md's TinyTeX PATH snippet under bash and zsh against a fake HOME.

The snippet is pasted into the user's interactive shell, which is zsh on
macOS. zsh aborts a command whose glob matches nothing, so a lookup that
globs both install locations came back empty there, and the snippet then
persisted `export PATH=":$PATH"` - the current directory first on PATH in
every future shell. bash's failglob aborts on an unmatched glob the same
way, so that variant keeps the regression guarded on runners without zsh.
The installer download is stripped; everything after it runs as written.
"""

import operator;

import os;

import re;

import shutil;

import subprocess;

import tempfile;

import unittest;

import from pathlib { Path }

glob REPO: any;

glob SETUP: any;

glob INSTALL_LINES: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    SETUP = REPO / "SETUP.md";
    INSTALL_LINES = re.compile("^\\s*(curl |sh .*install-bin-unix\\.sh)");
}

def tinytex_snippet -> any;

@unittest.skipIf(
    operator.eq(os.name, "nt"), "the snippet targets macOS and Linux; Windows uses MiKTeX"
)
class TestTinyTeXPathSnippet(unittest.TestCase) {
    def run_snippet(shell, layout, *shell_opts_, existing=(), fake_os=None) -> any;

    def assert_persists_bin_dir(shell, *shell_opts__) -> any;

    def assert_writes_nothing_without_install(shell, *shell_opts___) -> any;

    def test_bash_persists_the_tinytex_bin_dir -> any;

    def test_bash_writes_nothing_when_tinytex_is_missing -> any;

    def test_failglob_bash_persists_the_tinytex_bin_dir -> any;

    def test_bash_appends_to_the_startup_file_bash_reads -> any;

    def test_zsh_persists_the_tinytex_bin_dir -> any;

    def test_zsh_writes_nothing_when_tinytex_is_missing -> any;
}

with entry:__main__ {
    unittest.main();
}
