impl TestAddPortalCommand.test_allowed_tools_specifies_agents_skills_path -> any {
    content: any = COMMAND.read_text(encoding="utf-8");
    self.assertIn("allowed-tools: Bash(bun run .agents/skills/<name>/cli/src/cli.ts *)", content);
    self.assertNotIn("allowed-tools: Bash(bun run skills/<name>/cli/src/cli.ts *)", content);
}
