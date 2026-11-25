impl AddTemplateKeepsIntermediatesInBuild.test_latex_command_redirects_to_build_and_returns_a_fresh_pdf {
    self.assertIn(
        "rm -f <file>.pdf && mkdir -p build && lualatex -interaction=nonstopmode -output-directory=build <file>.tex && mv build/<file>.pdf ./",
        command("add-template"),
    );
}
