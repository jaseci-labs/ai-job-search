import unittest;

glob CV_SENTINELS: list[str] = ["\\name{[First]}{[Last]}", "\\email{[your.email@example.com]}"],
     PERSONALIZED: dict[str, str] = {
         "\\name{[First]}{[Last]}": "\\name{Jane}{Doe}",
         "[Your Address, City, Country]": "Some Street 1, Aarhus, Denmark",
         "[+XX XXXXXXXXXX]": "+45 12345678",
         "[your.email@example.com]": "jane.doe@example.org",
     };

@unittest.skipIf(
    not is_upstream_checkout(),
    "placeholder-integrity guards the pristine upstream template; forks personalize these files via /setup",
)
class TestSentinelsAreDataLocated(unittest.TestCase) {
    def test_ci_checks_the_data_lines {
        check(
            self,
            doc(".github/workflows/ci.yml"),
            [
                "check cv/main_example.tex '\\\\name{\\[First\\]}{\\[Last\\]}'",
                "check cv/main_example.tex '\\\\email{\\[your\\.email@example\\.com\\]}'",
                "check .claude/skills/job-application-assistant/01-candidate-profile.md '\\[YOUR_EMAIL\\]'",
            ],
        );
    }

    def test_pristine_files_carry_the_sentinels {
        check(self, doc("cv/main_example.tex"), CV_SENTINELS);
        self.assertIn("[YOUR_EMAIL]", skill("01-candidate-profile.md"));
    }

    def test_setup_edit_destroys_the_cv_sentinels {
        pristine: str = doc("cv/main_example.tex");
        personalized: str = pristine;
        for (placeholder, value) in PERSONALIZED.items() {
            personalized = personalized.replace(placeholder, value);
        }
        self.assertNotEqual(
            personalized, pristine, "the simulated /setup edit must change the file"
        );
        self.assertEqual([s for s in CV_SENTINELS if s in personalized], []);
    }
}
