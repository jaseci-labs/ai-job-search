impl symlinks_available -> bool {
    with TemporaryDirectory() as directory {
        target: Path = Path(directory) / "target";
        target.touch();
        try {
            (Path(directory) / "link").symlink_to(target);
        } except NotImplementedError {
            return False;
        } except OSError as exc {
            if exc.errno in (errno.ENOSYS, errno.ENOTSUP, errno.EPERM)
                or getattr(exc, "winerror", None) in (5, 1314)
            {
                return False;
            }
            raise;
        }
        return True;
    }
}

impl populate(base: Path, folders: list[str], files: list[str]) -> Path {
    documents: Path = base / "documents";
    for path in [documents / folder / name for folder in folders for name in files] {
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text(f"{path.name}\n");
    }
    for path in (documents / "README.md", base / "outside" / "keep.md") {
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text("Keep.\n");
    }
    return documents;
}

impl reset(shell: str | None, base: Path) -> subprocess.CompletedProcess {
    return subprocess.run(
        [shell, "-c", bash_block(command("reset"), "### Documents reset")],
        cwd=base,
        capture_output=True,
        text=True,
    );
}

impl ResetDocuments.test_documents_are_removed_and_the_scaffold_is_kept {
    full: list[str] = [".gitkeep", "summary.md", ".source.md", "project-or-application/README.md"];
    cases: list[tuple[str, list[str], list[str]]] = [
        ("populated", FOLDERS, full),
        ("empty", FOLDERS, [".gitkeep"]),
        ("missing folder", [name for name in FOLDERS if name != "diplomas"], full),
    ];
    for shell in SHELLS {
        for (label, folders, files) in cases {
            with self.subTest(shell=shell, tree=label), TemporaryDirectory() as directory {
                documents: Path = populate(Path(directory), folders, files);
                result = reset(shell, Path(directory));
                self.assertEqual((result.returncode, result.stderr), (0, ""));
                self.assertEqual(
                    {path.name for path in documents.iterdir()}, {*folders, "README.md"}
                );
                for kept in ("documents/README.md", "outside/keep.md") {
                    self.assertEqual((Path(directory) / kept).read_text(), "Keep.\n");
                }
                for name in folders {
                    self.assertEqual(
                        [path.name for path in (documents / name).iterdir()], [".gitkeep"], name
                    );
                    self.assertEqual((documents / name / ".gitkeep").read_text(), ".gitkeep\n");
                }
            }
        }
    }
}

impl ResetDocuments.test_block_uses_no_bash_only_builtins {
    check(
        self,
        bash_block(command("reset"), "### Documents reset"),
        [],
        ["shopt", "declare ", "[[", "{cv,"],
    );
}

impl ResetDocuments.test_symlinked_roots_stop_before_any_deletion {
    for linked in ["documents", *[f"documents/{name}" for name in FOLDERS]] {
        with self.subTest(linked_root=linked), TemporaryDirectory() as directory {
            base: Path = Path(directory);
            documents: Path = populate(base, FOLDERS, ["local.md"]);
            shutil.rmtree(base / linked);
            (base / linked).symlink_to(base / "outside", target_is_directory=True);
            survivors: list[Path] = [
                path
                for name in FOLDERS
                for path in (documents / name).glob("local.md")
            ];
            result = reset(BASH, base);
            self.assertNotEqual(result.returncode, 0);
            self.assertIn("symbolic link", result.stderr);
            self.assertEqual((base / "outside/keep.md").read_text(), "Keep.\n");
            for path in survivors {
                self.assertEqual(path.read_text(), "local.md\n");
            }
        }
    }
}

impl ResetDocuments.test_internal_symlink_is_removed_without_following_its_target {
    with TemporaryDirectory() as directory {
        base: Path = Path(directory);
        populate(base, FOLDERS, [".gitkeep"]);
        link: Path = base / "documents/projects/external";
        link.symlink_to(base / "outside", target_is_directory=True);
        result = reset(BASH, base);
        self.assertEqual(result.returncode, 0, result.stderr);
        self.assertFalse(link.is_symlink());
        self.assertEqual((base / "outside/keep.md").read_text(), "Keep.\n");
    }
}
