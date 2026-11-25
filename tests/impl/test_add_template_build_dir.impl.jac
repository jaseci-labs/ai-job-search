impl AddTemplateKeepsIntermediatesInBuild.test_latex_command_redirects_to_build_and_returns_a_fresh_pdf -> any {
    self.assertIn(LATEX_COMMAND, ADD_TEMPLATE.read_text(encoding="utf-8"));
}
