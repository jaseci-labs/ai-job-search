import unittest;

import from pathlib { Path }

glob REPO: any;

glob ADD_TEMPLATE: any;

glob LATEX_COMMAND: any;

with entry {
    REPO = Path(__file__).resolve().parent.parent;
    ADD_TEMPLATE = REPO / ".claude" / "commands" / "add-template.md";

    LATEX_COMMAND = "rm -f <file>.pdf && mkdir -p build && lualatex -interaction=nonstopmode -output-directory=build <file>.tex && mv build/<file>.pdf ./";
}

class AddTemplateKeepsIntermediatesInBuild(unittest.TestCase) {
    def test_latex_command_redirects_to_build_and_returns_a_fresh_pdf -> any;
}

with entry:__main__ {
    unittest.main();
}
