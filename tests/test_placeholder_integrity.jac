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
    def test_ci_checks_the_data_lines;
    def test_pristine_files_carry_the_sentinels;
    def test_setup_edit_destroys_the_cv_sentinels;
}
