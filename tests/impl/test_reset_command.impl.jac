impl tracked_document_subfolders -> any {
    out: any = subprocess.run(
        ["git", "ls-files", "documents/"], cwd=REPO, capture_output=True, text=True, check=True
    ).stdout;
    folders: any = set[any]();
    for line in out.splitlines() {
        parts: any = line.split("/");
        if len(parts) >= 3 {
            folders.add(parts[1]);
        }
    }
    return folders;
}

impl TestResetCoversEveryDocumentsSubfolder.setUp -> any {
    self.text = RESET.read_text(encoding="utf-8");
    self.folders = tracked_document_subfolders();
    self.assertGreaterEqual(len(self.folders), 5, self.folders);
}

impl TestResetCoversEveryDocumentsSubfolder.test_preview_lists_every_subfolder -> any {
    missing: any = [f for f in sorted(self.folders) if f"documents/{f}/" not in self.text];
    self.assertEqual(
        missing,
        [],
        f"reset.md's preview never mentions these documents/ subfolders, so the user confirms a deletion list that omits them: {missing}",
    );
}

impl TestResetCoversEveryDocumentsSubfolder.test_delete_block_removes_every_subfolder -> any {
    section: any;
    section = self.text.split("### Documents reset", 1)[1];
    script: any = re.search("```bash\\n(.*?)```", section, re.S).group(1);
    directory: any;
    with TemporaryDirectory() as directory {
        `root: any = Path(directory);
        folder: any;
        for folder in self.folders {
            path: any = `root / "documents" / folder;
            path.mkdir(parents=True);
            (path / ".gitkeep").write_text("Keep scaffold.\n");
            (path / "user.txt").write_text("Remove document.\n");
        }
        result: any = subprocess.run(
            [BASH, "-c", script], cwd=`root, capture_output=True, text=True
        );
        self.assertEqual(result.returncode, 0, result.stderr);
        for folder in self.folders {
            path = `root / "documents" / folder;
            self.assertEqual([`entry.name for `entry in path.iterdir()], [".gitkeep"]);
            self.assertEqual((path / ".gitkeep").read_text(), "Keep scaffold.\n");
        }
    }
}

impl section(text: builtins.str, start: builtins.str, end: builtins.str) -> builtins.str {
    begin: any = text.index(start);
    return text[begin:text.index(end, begin)];
}

impl setup_step3_skill_files -> any {
    step3: any = section(SETUP.read_text(encoding="utf-8"), "## Step 3:", "## Step 4:");
    files: any = set[any]();
    for target in re.findall("^###\\s+\\d+\\.\\s+\\w+\\s+`([^`]+)`", step3, re.MULTILINE) {
        if (REPO / target).exists() {
            if target.startswith(".claude/skills/") {
                files.add(Path(target).name);
            }
            continue;
        }
        matches: any = `list((REPO / ".claude" / "skills").glob(f"*/{target}"));
        if matches {
            files.add(Path(target).name);
        }
    }
    return files;
}

impl setup_path_a_inference_rules -> any {
    a5: any = section(SETUP.read_text(encoding="utf-8"), "### Step A5:", "### Step A6:");
    rules: any = [];
    for line in a5.splitlines() {
        `match: any = re.match("^- \\*\\*`([^`]+\\.md)`", line);
        if `match {
            rules.append((`match.group(1), re.findall("\"(## [^\"]+)\"", line)));
        }
    }
    return rules;
}

impl TestResetCoversPathAInferredContent.setUp -> any {
    self.text = RESET.read_text(encoding="utf-8");
    self.rules = setup_path_a_inference_rules();
    self.files = {name for (name, _) in self.rules};
    self.assertGreaterEqual(len(self.files), 6, self.rules);
    self.assertIn("03-writing-style.md", self.files);
}

impl TestResetCoversPathAInferredContent.test_step1_reads_every_path_a_file -> any {
    inventory: any;
    inventory = section(self.text, "Read the current state of these files", "Present as:");
    missing: any = sorted(f for f in self.files if f not in inventory);
    self.assertEqual(
        missing,
        [],
        f"Step 1 never reads these Path A targets, so their preview line is unchecked: {missing}",
    );
}

impl TestResetCoversPathAInferredContent.test_preview_lists_every_path_a_file -> any {
    listed: any;
    preview: any = section(
        self.text, "### If scope includes `profile`:", "### If scope includes `documents`:"
    );
    listed = section(
        preview, "## Profile reset will clear:", "The following files are NOT touched"
    );
    missing: any = sorted(f for f in self.files if f not in listed);
    self.assertEqual(
        missing,
        [],
        f"Path A writes into these, but the preview never offers to clear them: {missing}",
    );
}

impl TestResetCoversPathAInferredContent.test_preserved_list_claims_no_path_a_file_is_framework_only -> any {
    preserved: any;
    preserved = section(self.text, "The following files are NOT touched", "```");
    mislabeled: any = sorted(f for f in self.files if f in preserved);
    self.assertEqual(
        mislabeled,
        [],
        f"listed as framework-only, but Path A writes candidate data into: {mislabeled}",
    );
}

impl TestResetCoversPathAInferredContent.test_execution_removes_every_section_path_a_adds -> any {
    blocks: any;
    execution: any = section(self.text, "### Profile reset", "### Documents reset");
    blocks = {};
    for `match in re.finditer(
        "^\\*\\*For `(?:[^`]*/)?([^`/]+)`\\*\\*(.*?)(?=^\\*\\*For `|\\Z)", execution, re.S | re.M
    ) {
        blocks[`match.group(1)] = blocks.get(`match.group(1), "") + `match.group(2);
    }
    missing: any = sorted(
        f"{name}: {heading}"
        for (name, headings) in self.rules
        for heading in headings
        if heading not in blocks.get(name, ""),
    );
    self.assertEqual(
        missing,
        [],
        f"Path A adds these sections, but no Step 3 instruction for that file removes them: {missing}",
    );
}

impl TestResetCoversEveryPersonalizedSkillFile.setUp -> any {
    self.text = RESET.read_text(encoding="utf-8");
    self.files = setup_step3_skill_files();
    self.assertGreaterEqual(len(self.files), 6, self.files);
    self.assertIn("04-job-evaluation.md", self.files);
    self.assertIn("search-queries.md", self.files);
}

impl TestResetCoversEveryPersonalizedSkillFile.test_preview_lists_every_personalized_skill_file -> any {
    preview: any;
    preview = section(
        self.text, "### If scope includes `profile`:", "### If scope includes `documents`:"
    );
    missing: any = sorted(f for f in self.files if f not in preview);
    self.assertEqual(
        missing,
        [],
        f"reset.md's profile preview never mentions these files that /setup Step 3 writes candidate data into, so the user types RESET against a list that omits them: {missing}",
    );
}

impl TestResetCoversEveryPersonalizedSkillFile.test_execution_clears_every_personalized_skill_file -> any {
    execution: any;
    execution = section(self.text, "### Profile reset", "### Documents reset");
    missing: any = sorted(f for f in self.files if f not in execution);
    self.assertEqual(
        missing,
        [],
        f"reset.md's Step 3 profile pass has no instruction for these files, yet the command then reports the skill files are \"now blank\": {missing}",
    );
}

impl TestResetCoversEveryPersonalizedSkillFile.test_preserved_list_claims_no_personalized_file_is_framework_only -> any {
    preserved: any;
    preserved = section(self.text, "The following files are NOT touched", "```");
    mislabeled: any = sorted(f for f in self.files if f in preserved);
    self.assertEqual(
        mislabeled,
        [],
        f"reset.md tells the user these files contain 'framework rules, not candidate data', but /setup Step 3 writes candidate data into them: {mislabeled}",
    );
}

impl skeleton_step(reset_text, filename) -> any {
    marker: any = f"**For `{filename}`**";
    start: any = reset_text.index(marker);
    fence_open: any = reset_text.index("```markdown", start);
    fence_close: any = reset_text.index("```", fence_open + len("```markdown"));
    return (reset_text[start:fence_open], reset_text[fence_open + len("```markdown"):fence_close]);
}

impl skeleton_block(reset_text, filename) -> any {
    return skeleton_step(reset_text, filename)[1];
}

impl frontmatter(text) -> any {
    if not text.startswith("---\n") {
        return "";
    }
    end: any = text.index("\n---", 4);
    return text[:end + len("\n---") + 1];
}

impl h2_headings(text) -> any {
    return [line.strip() for line in text.splitlines() if line.startswith("## ")];
}

impl appear_in_order(needles, haystack) -> any {
    remaining: any;
    remaining = iter(haystack);
    return all(needle in remaining for needle in needles);
}

impl TestResetTargetsTheHeadingsTheShippedFilesHave.setUp -> any {
    self.reset = RESET.read_text(encoding="utf-8");
}

impl TestResetTargetsTheHeadingsTheShippedFilesHave.test_full_file_skeletons_keep_the_shipped_headings -> any {
    for filename in ("01-candidate-profile.md", "02-behavioral-profile.md") {
        with self.subTest(file=filename) {
            shipped: any = (SKILL_DIR / filename).read_text(encoding="utf-8");
            skeleton: any = h2_headings(skeleton_block(self.reset, filename));
            if not is_upstream_checkout() {
                self.assertTrue(
                    appear_in_order(skeleton, h2_headings(shipped)),
                    f"/reset's skeleton headings for {filename} must all appear, in order, in the personalized file: {skeleton}",
                );
                continue;
            }
            self.assertEqual(
                skeleton,
                h2_headings(shipped),
                f"/reset's skeleton for {filename} must carry exactly the shipped ## headings, in order - a reset must not rename or drop sections",
            );
        }
    }
}

impl TestResetTargetsTheHeadingsTheShippedFilesHave.test_fork_heading_check_rejects_a_renamed_dropped_or_reordered_heading -> any {
    skeleton: any = ["## Identity", "## Education", "## Awards"];
    self.assertTrue(
        appear_in_order(skeleton, ["## Identity", "## Education", "## Certifications", "## Awards"])
    );
    self.assertFalse(appear_in_order(skeleton, ["## Identity", "## Schooling", "## Awards"]));
    self.assertFalse(appear_in_order(skeleton, ["## Identity", "## Awards"]));
    self.assertFalse(appear_in_order(skeleton, ["## Education", "## Identity", "## Awards"]));
}

impl TestResetTargetsTheHeadingsTheShippedFilesHave.test_full_file_skeletons_keep_the_framework_version_frontmatter -> any {
    import sys;
    import from tools.check_upstream_updates { get_framework_version_from_text }

    for filename in ("01-candidate-profile.md", "02-behavioral-profile.md") {
        with self.subTest(file=filename) {
            shipped: any = (SKILL_DIR / filename).read_text(encoding="utf-8");
            head: any = frontmatter(shipped);
            self.assertTrue(head, f"{filename} must ship with a frontmatter block");
            instruction: any;
            block: any;
            (instruction, block) = skeleton_step(self.reset, filename) as any;
            self.assertIn(
                "frontmatter", instruction, f"the {filename} step must say to keep the frontmatter"
            );
            self.assertNotIn(
                "framework_version", block, "the skeleton must not hardcode a version"
            );
            after: any = head + block.lstrip("\n");
            self.assertEqual(
                get_framework_version_from_text(after),
                get_framework_version_from_text(shipped),
                f"a reset must leave {filename}'s framework_version readable and unchanged",
            );
        }
    }
}

impl TestResetTargetsTheHeadingsTheShippedFilesHave.test_candidate_skeleton_keeps_the_languages_table_under_identity -> any {
    shipped: any = (SKILL_DIR / "01-candidate-profile.md").read_text(encoding="utf-8");
    start: any = shipped.index("### Languages");
    header_rows: any = [
        line
        for line in shipped[start:].splitlines()[1:]
        if line.startswith("|")
    ][:2];
    self.assertEqual(
        len(header_rows), 2, "the shipped Languages table must have a header and a separator row"
    );
    block: any = skeleton_block(self.reset, "01-candidate-profile.md");
    identity: any = block[block.index("## Identity"):block.index("## Education")];
    self.assertIn(
        "### Languages", identity, "the Languages table must sit under Identity, as shipped"
    );
    for row in header_rows {
        with self.subTest(row=row) {
            self.assertIn(row, identity);
        }
    }
    self.assertNotIn("[LANGUAGE]", block, "a reset must not reintroduce a placeholder data row");
}

impl TestResetTargetsTheHeadingsTheShippedFilesHave.test_partial_anchors_exist_in_the_files_they_target -> any {
    cases: any = (
        ("locate the section that begins with the line `([^`]+)`", "05-cv-templates.md"),
        ("The entire `([^`]+)` section", "07-interview-prep.md"),
    );
    for (pattern, filename) in cases {
        with self.subTest(file=filename) {
            `match: any = re.search(pattern, self.reset);
            self.assertIsNotNone(`match, f"reset.md no longer states its anchor for {filename}");
            anchor: any = `match.group(1);
            shipped: any = (SKILL_DIR / filename).read_text(encoding="utf-8");
            self.assertIn(
                anchor,
                shipped,
                f"/reset anchors {filename} on {anchor!r}, which the shipped file does not contain - the wipe would silently find nothing",
            );
            step: any = self.reset[`match.start():];
            block_start: any = step.index("```markdown") + len("```markdown");
            block: any = step[block_start:step.index("```", block_start)];
            self.assertIn(
                anchor, block, f"the replacement for {filename} must keep the heading {anchor!r}"
            );
        }
    }
}
