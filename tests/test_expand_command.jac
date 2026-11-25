import unittest;

class ExpandCommandTests(unittest.TestCase) {
    def test_expand_command_states_its_sources_mappings_and_principles {
        self.assertTrue((REPO / ".claude/commands/expand.md").exists());
        text: str = command("expand");
        self.assertTrue(text.lstrip().startswith("# /expand"), text[:80]);
        check(
            self,
            text,
            [
                "documents/cv/",
                "documents/linkedin/",
                "documents/diplomas/",
                "documents/references/",
                "GitHub Profile",
                "## Independent Projects",
                "Independent Projects & Portfolio",
                "GitHub — repo-name",
                "Portfolio & projects grounded in code",
                "Additive only",
                "User confirms before writing",
                "`all`",
                "`review`",
                "`skip`",
            ],
            ["documents/projects/"],
        );
    }

    def test_behavioral_additions_name_sections_the_shipped_file_has {
        names: list[str] = quoted(
            between(command("expand"), "### Additions to `02-behavioral-profile.md`", "---")
        );
        self.assertTrue(names, "the 02-behavioral-profile step must name its target sections");
        for name in names {
            with self.subTest(section=name) {
                self.assertIn(name, h2(skill("02-behavioral-profile.md")));
            }
        }
    }
}
