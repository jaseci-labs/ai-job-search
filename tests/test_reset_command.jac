import re, subprocess, unittest;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob BASH: str | None = find_bash(),
     FULL_FILES: tuple[str, str] = ("01-candidate-profile.md", "02-behavioral-profile.md"),
     PROFILE_PREVIEW: tuple[str, str] = (
         "### If scope includes `profile`:",
         "### If scope includes `documents`:",
     ),
     PRESERVED: tuple[str, str] = ("The following files are NOT touched", "```"),
     EXECUTION: tuple[str, str] = ("### Profile reset", "### Documents reset");

def tracked_document_subfolders -> set[str] {
    out: str = capture(["git", "ls-files", "documents/"], cwd=REPO, check=True).stdout;
    return {line.split("/")[1] for line in out.splitlines() if line.count("/") >= 2};
}

def setup_step3_skill_files -> set[str] {
    step3: str = between(command("setup"), "## Step 3:", "## Step 4:");
    files: set[str] = set();
    for target in re.findall("^###\\s+\\d+\\.\\s+\\w+\\s+`([^`]+)`", step3, re.MULTILINE) {
        nested: bool = any((REPO / ".claude" / "skills").glob(f"*/{target}"));
        if target.startswith(".claude/skills/") if (REPO / target).exists() else nested {
            files.add(Path(target).name);
        }
    }
    return files;
}

def setup_path_a_inference_rules -> list[tuple[str, list[str]]] {
    a5: str = between(command("setup"), "### Step A5:", "### Step A6:");
    return [
        (found.group(1), re.findall("\"(## [^\"]+)\"", found.group(0)))
        for found in re.finditer("^- \\*\\*`([^`]+\\.md)`.*$", a5, re.MULTILINE)
    ];
}

def skeleton_step(reset_text: str, filename: str) -> tuple[str, str] {
    (instruction, _, rest) = reset_text[reset_text.index(f"**For `{filename}`**"):].partition(
        "```markdown"
    );
    return (instruction, rest[:rest.index("```")]);
}

def frontmatter(text: str) -> str {
    return text[:text.index("\n---", 4) + 5] if text.startswith("---\n") else "";
}

def appear_in_order(needles: list[str], haystack: list[str]) -> bool {
    remaining: any = iter(haystack);
    return all([needle in remaining for needle in needles]);
}

class TestResetCoversEveryDocumentsSubfolder(unittest.TestCase) {
    def setUp {
        self.text = command("reset");
        self.folders = tracked_document_subfolders();
        self.assertGreaterEqual(len(self.folders), 5, self.folders);
    }

    def test_preview_lists_every_subfolder {
        check(self, self.text, [f"documents/{folder}/" for folder in sorted(self.folders)]);
    }

    @unittest.skipUnless(BASH, "requires Bash to replay the documented /reset command")
    def test_delete_block_removes_every_subfolder {
        with TemporaryDirectory() as directory {
            paths: list[Path] = [Path(directory) / "documents" / folder for folder in self.folders];
            for path in paths {
                path.mkdir(parents=True);
                (path / ".gitkeep").write_text("Keep scaffold.\n");
                (path / "user.txt").write_text("Remove document.\n");
            }
            result = capture(
                [BASH, "-c", bash_block(self.text, "### Documents reset")], cwd=directory
            );
            self.assertEqual(result.returncode, 0, result.stderr);
            for path in paths {
                self.assertEqual([item.name for item in path.iterdir()], [".gitkeep"]);
                self.assertEqual((path / ".gitkeep").read_text(), "Keep scaffold.\n");
            }
        }
    }
}

class TestResetCoversWhatSetupWrites(unittest.TestCase) {
    def setUp {
        self.text = command("reset");
        self.rules = setup_path_a_inference_rules();
        self.path_a = {name for (name, _) in self.rules};
        self.step3 = setup_step3_skill_files();
    }

    def test_setup_targets_are_found {
        self.assertGreaterEqual(len(self.path_a), 6, self.rules);
        self.assertIn("03-writing-style.md", self.path_a);
        self.assertGreaterEqual(len(self.step3), 6, self.step3);
        self.assertLessEqual({"04-job-evaluation.md", "search-queries.md"}, self.step3);
    }

    def test_every_setup_target_is_read_previewed_and_cleared {
        preview: str = between(self.text, *PROFILE_PREVIEW);
        preserved: str = between(self.text, *PRESERVED);
        cases: list[tuple[str, set[str], str, bool]] = [
            (
                "Step 1 reads every Path A file",
                self.path_a,
                between(self.text, "Read the current state of these files", "Present as:"),
                True,
            ),
            (
                "the preview lists every Path A file",
                self.path_a,
                between(preview, "## Profile reset will clear:", PRESERVED[0]),
                True,
            ),
            ("no Path A file is called framework-only", self.path_a, preserved, False),
            ("the preview lists every Step 3 file", self.step3, preview, True),
            (
                "the execution clears every Step 3 file",
                self.step3,
                between(self.text, *EXECUTION),
                True,
            ),
            ("no Step 3 file is called framework-only", self.step3, preserved, False),
        ];
        for (label, files, region, listed) in cases {
            with self.subTest(label) {
                self.assertEqual(
                    [name for name in sorted(files) if (name in region) != listed], []
                );
            }
        }
    }

    def test_execution_removes_every_section_path_a_adds {
        blocks: dict[str, str] = {};
        for found in re.finditer(
            "^\\*\\*For `(?:[^`]*/)?([^`/]+)`\\*\\*(.*?)(?=^\\*\\*For `|\\Z)",
            between(self.text, *EXECUTION),
            re.S | re.M,
        ) {
            blocks[found.group(1)] = blocks.get(found.group(1), "") + found.group(2);
        }
        missing: list[str] = [
            f"{name}: {heading}"
            for (name, headings) in self.rules
            for heading in headings
            if heading not in blocks.get(name, "")
        ];
        self.assertEqual(missing, [], "Path A adds these sections but /reset never removes them");
    }
}

class TestResetTargetsTheHeadingsTheShippedFilesHave(unittest.TestCase) {
    def setUp {
        self.reset = command("reset");
    }

    def test_full_file_skeletons_keep_the_shipped_headings {
        for filename in FULL_FILES {
            with self.subTest(file=filename) {
                shipped: list[str] = h2(skill(filename));
                skeleton: list[str] = h2(skeleton_step(self.reset, filename)[1]);
                if is_upstream_checkout() {
                    self.assertEqual(skeleton, shipped);
                } else {
                    self.assertTrue(appear_in_order(skeleton, shipped), skeleton);
                }
            }
        }
    }

    def test_fork_heading_check_rejects_a_renamed_dropped_or_reordered_heading {
        cases: list[tuple[list[str], bool]] = [
            (["Identity", "Education", "Certifications", "Awards"], True),
            (["Identity", "Schooling", "Awards"], False),
            (["Identity", "Awards"], False),
            (["Education", "Identity", "Awards"], False),
        ];
        for (haystack, expected) in cases {
            with self.subTest(haystack=haystack) {
                self.assertEqual(
                    appear_in_order(["Identity", "Education", "Awards"], haystack), expected
                );
            }
        }
    }

    def test_full_file_skeletons_keep_the_framework_version_frontmatter {
        for filename in FULL_FILES {
            with self.subTest(file=filename) {
                shipped: str = skill(filename);
                head: str = frontmatter(shipped);
                self.assertTrue(head, f"{filename} must ship with a frontmatter block");
                (instruction, block) = skeleton_step(self.reset, filename);
                self.assertIn("frontmatter", instruction);
                self.assertNotIn("framework_version", block);
                self.assertEqual(
                    get_framework_version_from_text(head + block.lstrip("\n")),
                    get_framework_version_from_text(shipped),
                );
            }
        }
    }

    def test_candidate_skeleton_keeps_the_languages_table_under_identity {
        shipped: str = skill("01-candidate-profile.md");
        header_rows: list[str] = [
            line
            for line in shipped[shipped.index("### Languages"):].splitlines()[1:]
            if line.startswith("|")
        ][:2];
        self.assertEqual(
            len(header_rows), 2, "the shipped Languages table needs a header and separator"
        );
        block: str = skeleton_step(self.reset, "01-candidate-profile.md")[1];
        check(self, between(block, "## Identity", "## Education"), ["### Languages", *header_rows]);
        self.assertNotIn(
            "[LANGUAGE]", block, "a reset must not reintroduce a placeholder data row"
        );
    }

    def test_partial_anchors_exist_in_the_files_they_target {
        cases: list[tuple[str, str]] = [
            ("locate the section that begins with the line `([^`]+)`", "05-cv-templates.md"),
            ("The entire `([^`]+)` section", "07-interview-prep.md"),
        ];
        for (pattern, filename) in cases {
            with self.subTest(file=filename) {
                found = re.search(pattern, self.reset);
                self.assertIsNotNone(found, f"reset.md no longer states its anchor for {filename}");
                self.assertIn(found.group(1), skill(filename));
                replacement: str = self.reset[found.start():].split("```markdown", 1)[1];
                self.assertIn(found.group(1), replacement[:replacement.index("```")]);
            }
        }
    }
}
