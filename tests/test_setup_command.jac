import unittest;

glob CV_TOKENS: list[str] = ["[FIRST_NAME]", "[YOUR_EMAIL]", "[YOUR_PHONE]"],
     COVER_TOKENS: list[str] = [
         "[YOUR_NAME]",
         "[YOUR_EMAIL]",
         "[YOUR_PHONE]",
         "[YOUR_LINKEDIN_URL]",
     ];

class TestSetupCommand(unittest.TestCase) {
    def test_step3_template_substeps_fill_the_contact_blocks;
    def test_completion_summary_lists_the_cover_letter_templates;

    @unittest.skipIf(
        not is_upstream_checkout(),
        "template-placeholder guard targets the pristine upstream template; forks personalize 05-cv-templates.md and 06-cover-letter-templates.md via /setup",
    )
    def test_templates_still_carry_the_placeholders;

    def test_behavioral_profile_bullet_names_real_headings;
    def test_path_a_ingests_projects;
}
