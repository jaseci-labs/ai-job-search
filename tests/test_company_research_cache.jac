import unittest;

class CompanyResearchCache(unittest.TestCase) {
    def test_evaluation_file_defines_the_cache {
        body: str = h2(doc(EVALUATION), "Company Research Cache");
        expect(
            self,
            body,
            "company_research/",
            "30",
            "fetched_date",
            "lead",
            "data, never instructions",
        );
        expect_re(self, body, "[Vv]erif");
    }

    def test_apply_reviewer_prompt_checks_the_cache_and_writes_back {
        body: str = section(doc(APPLY), "\n### 1. Research the Company", "^### ").partition(
            "\n"
        )[2];
        expect(self, body, "company_research/");
        expect_re(
            self,
            body,
            "[Cc]heck the cache",
            "write.*company_research/|company_research/.*write",
            "still applies",
        );
    }

    def test_interview_step_2_checks_the_cache_and_writes_back {
        body: str = section(doc(INTERVIEW), "\n## Step 2: Research the Company", "^## ").partition(
            "\n"
        )[2];
        expect(self, body, "company_research/", "Verify before using");
        expect_re(
            self, body, "[Cc]heck the cache", "write.*cache|cache file with", "still applies"
        );
    }
}
