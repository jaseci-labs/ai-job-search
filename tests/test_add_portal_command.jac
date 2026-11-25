import unittest;

import from pathlib { Path }

glob REPO: any;

glob COMMAND: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    COMMAND = REPO / ".claude" / "commands" / "add-portal.md";
}

class TestAddPortalCommand(unittest.TestCase) {
    def test_allowed_tools_specifies_agents_skills_path -> any;
}

with entry:__main__ {
    unittest.main();
}
