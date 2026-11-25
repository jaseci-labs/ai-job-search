import json;
import shutil;
import subprocess;
import tempfile;
import unittest;
import from pathlib { Path }

glob SETTINGS: str = ".claude/settings.json",
     SKILL: str = ".claude/skills/example/SKILL.md",
     COMMAND: str = ".claude/commands/setup.md",
     CLI: str = ".claude/skills/example/cli.ts",
     FRONTMATTER: str = "---\nname: example\ndescription: Example skill\n",
     VALID: dict[str, str] = {
         SETTINGS: json.dumps({"permissions": {"allow": []}}),
         SKILL: FRONTMATTER + "---\n",
         COMMAND: "# /setup - Test setup command\n",
     };

def settings_cases -> list[tuple[str, str]];

class LintSkillsTests(unittest.TestCase) {
    def setUp;
    def lint(files: dict[str, str]) -> subprocess.CompletedProcess;
    def test_valid_tree_passes;
    def test_malformed_settings_fail_cleanly;
    def test_skill_and_command_checks;
}

with entry:__main__ {
    unittest.main();
}
