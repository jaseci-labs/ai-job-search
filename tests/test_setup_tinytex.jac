import os;
import re;
import shutil;
import subprocess;
import tempfile;
import unittest;
import from pathlib { Path }

glob DARWIN: str = "Library/TinyTeX/bin/universal-darwin";

def tinytex_snippet -> str;

@unittest.skipIf(os.name == "nt", "the snippet targets macOS and Linux; Windows uses MiKTeX")
class TestTinyTeXPathSnippet(unittest.TestCase) {
    def which(name: str) -> str;
    def run_snippet(
        shell: str,
        layout: str | None,
        opts: list[str] = [],
        existing: list[str] = [],
        fake_os: str = "",
    ) -> tuple[subprocess.CompletedProcess, Path, dict[str, str]];

    def test_shells_persist_the_tinytex_bin_dir;
    def test_shells_write_nothing_when_tinytex_is_missing;
    def test_bash_appends_to_the_startup_file_bash_reads;
}
