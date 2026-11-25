impl TestAddPortalCommand.test_allowed_tools_specifies_agents_skills_path {
    check(
        self,
        command("add-portal"),
        ["allowed-tools: Bash(bun run .agents/skills/<name>/cli/src/cli.ts *)"],
        ["allowed-tools: Bash(bun run skills/<name>/cli/src/cli.ts *)"],
    );
}
