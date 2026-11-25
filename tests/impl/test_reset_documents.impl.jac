impl symlinks_available -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        target: any = `root / "target";
        target.touch();
        try {
            (`root / "link").symlink_to(target);
        } except NotImplementedError {
            return False;
        } except OSError as exc {
            if exc.errno in (errno.ENOSYS, errno.ENOTSUP, errno.EPERM) {
                return False;
            }
            comptime if target_().os == "windows" {
                if getattr(exc, "winerror", None) in (5, 1314) {
                    return False;
                }
            }
            raise;
        }
        return True;
    }
}

impl ResetDocuments.reset_script -> any {
    section: any = COMMAND.read_text(encoding="utf-8").split("### Documents reset", 1)[1];
    return re.search("```bash\\n(.*?)```", section, re.S).group(1);
}

impl ResetDocuments.run_reset(populated) -> any {
    for shell in SHELLS {
        with self.subTest(shell=shell) {
            self.run_reset_with(shell, populated);
        }
    }
}

impl ResetDocuments.run_reset_with(shell, populated) -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        documents: any = `root / "documents";
        documents.mkdir();
        readme: any = documents / "README.md";
        readme.write_text("Keep these framework instructions.\n");
        sibling: any = `root / "outside-documents.md";
        sibling.write_text("Keep this external file.\n");
        name: any;
        for name in FOLDERS {
            folder: any = documents / name;
            folder.mkdir();
            (folder / ".gitkeep").write_text("Keep this scaffold.\n");
            if populated {
                (folder / "summary.md").write_text("A document\n");
                (folder / ".source.md").write_text("A hidden document\n");
                nested: any = folder / "project-or-application";
                nested.mkdir();
                (nested / "README.md").write_text("A nested document\n");
            }
        }
        result: any = subprocess.run(
            [shell, "-c", self.reset_script()], cwd=`root, capture_output=True, text=True
        );
        self.assertEqual(result.returncode, 0, result.stderr);
        self.assertEqual(result.stderr, "");
        self.assertEqual(readme.read_text(), "Keep these framework instructions.\n");
        self.assertEqual(sibling.read_text(), "Keep this external file.\n");
        self.assertEqual({path.name for path in documents.iterdir()}, {*FOLDERS, "README.md"});
        for name in FOLDERS {
            self.assertEqual([path.name for path in (documents / name).iterdir()], [".gitkeep"]);
            self.assertEqual((documents / name / ".gitkeep").read_text(), "Keep this scaffold.\n");
        }
    }
}

impl ResetDocuments.test_all_document_entries_are_removed_without_removing_the_scaffold -> any {
    self.run_reset(populated=True);
}

impl ResetDocuments.test_empty_document_folders_remain_usable -> any {
    self.run_reset(populated=False);
}

impl ResetDocuments.test_a_missing_folder_is_skipped_and_the_rest_are_still_cleared -> any {
    name: any;
    for shell in SHELLS {
        with self.subTest(shell=shell) {
            directory: any;
            with TemporaryDirectory() as directory {
                `root: any = Path(directory);
                documents: any = `root / "documents";
                documents.mkdir();
                (documents / "README.md").write_text("Keep.\n");
                present: any = [name for name in FOLDERS if name != "diplomas"];
                for name in present {
                    folder: any = documents / name;
                    folder.mkdir();
                    (folder / ".gitkeep").write_text("Keep.\n");
                    (folder / "summary.md").write_text("A document\n");
                }
                result: any = subprocess.run(
                    [shell, "-c", self.reset_script()], cwd=`root, capture_output=True, text=True
                );
                self.assertEqual(result.returncode, 0, result.stderr);
                self.assertEqual(result.stderr, "");
                for name in present {
                    self.assertEqual(
                        [path.name for path in (documents / name).iterdir()], [".gitkeep"], name
                    );
                }
                self.assertFalse((documents / "diplomas").exists());
            }
        }
    }
}

impl ResetDocuments.test_block_uses_no_bash_only_builtins -> any {
    script: any = self.reset_script();
    for bashism in ("shopt", "declare ", "[[", "{cv,") {
        self.assertNotIn(
            bashism, script, f"the documents reset block must stay POSIX: found {bashism!r}"
        );
    }
}

impl ResetDocuments.test_symlinked_roots_stop_before_any_deletion -> any {
    name: any;
    path: any;
    for linked_root in ("documents", *(f"documents/{name}" for name in FOLDERS)) {
        directory: any;
        with self.subTest(linked_root=linked_root), TemporaryDirectory() as directory {
            `root: any = Path(directory);
            outside: any = `root / "outside";
            outside.mkdir();
            sentinel: any = outside / "keep.md";
            sentinel.write_text("External document.\n");
            documents: any = `root / "documents";
            documents.mkdir();
            for name in FOLDERS {
                folder: any = documents / name;
                folder.mkdir();
                (folder / "local.md").write_text("Local document.\n");
            }
            target: any = `root / linked_root;
            shutil.rmtree(target);
            target.symlink_to(outside, target_is_directory=True);
            locals_before: any = [
                path
                for name in FOLDERS
                for path in (documents / name).glob("local.md")
            ];
            result: any = subprocess.run(
                [BASH, "-c", self.reset_script()], cwd=`root, capture_output=True, text=True
            );
            self.assertNotEqual(result.returncode, 0);
            self.assertIn("symbolic link", result.stderr);
            self.assertEqual(sentinel.read_text(), "External document.\n");
            for path in locals_before {
                self.assertEqual(path.read_text(), "Local document.\n");
            }
        }
    }
}

impl ResetDocuments.test_internal_symlink_is_removed_without_following_its_target -> any {
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        outside: any = `root / "outside";
        outside.mkdir();
        sentinel: any = outside / "keep.md";
        sentinel.write_text("External document.\n");
        for name in FOLDERS {
            (`root / "documents" / name).mkdir(parents=True);
        }
        link: any = `root / "documents/projects/external";
        link.symlink_to(outside, target_is_directory=True);
        result: any = subprocess.run(
            [BASH, "-c", self.reset_script()], cwd=`root, capture_output=True, text=True
        );
        self.assertEqual(result.returncode, 0, result.stderr);
        self.assertFalse(link.is_symlink());
        self.assertEqual(sentinel.read_text(), "External document.\n");
    }
}
