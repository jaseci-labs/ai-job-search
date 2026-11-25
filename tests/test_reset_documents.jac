import errno;
import shutil;
import subprocess;
import unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob FOLDERS: list[str] = [
         "cv",
         "linkedin",
         "diplomas",
         "references",
         "projects",
         "postings",
         "applications",
     ],
     BASH: str | None = find_bash(),
     SHELLS: list[str] = [
         path
         for path in (BASH, shutil.which("zsh"), shutil.which("sh"), shutil.which("dash"))
         if path
     ],
     SYMLINKS: bool = bool(BASH) and symlinks_available();

def symlinks_available -> bool;

def populate(base: Path, folders: list[str], files: list[str]) -> Path;

def reset(shell: str | None, base: Path) -> subprocess.CompletedProcess;

@unittest.skipUnless(BASH, "requires Bash to replay the documented /reset command")
class ResetDocuments(unittest.TestCase) {
    def test_documents_are_removed_and_the_scaffold_is_kept;
    def test_block_uses_no_bash_only_builtins;

    @unittest.skipUnless(SYMLINKS, "requires filesystem symlinks and Windows symlink privilege")
    def test_symlinked_roots_stop_before_any_deletion;

    @unittest.skipUnless(SYMLINKS, "requires filesystem symlinks and Windows symlink privilege")
    def test_internal_symlink_is_removed_without_following_its_target;
}
