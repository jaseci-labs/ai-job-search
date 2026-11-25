import re;

import unittest;

import from pathlib { Path }

glob ROOT: any;

glob SPECS: any;

glob BARE: any;

with entry {
    ROOT = Path(__file__).resolve().parent.parent;
    SPECS = [
        ROOT / ".claude" / "skills" / "job-scraper" / "SKILL.md",
        ROOT / ".claude" / "commands" / "rank.md",
        ROOT / ".claude" / "commands" / "notion-sync.md",
        ROOT / ".claude" / "skills" / "upskill" / "SKILL.md",
    ];
    BARE = re.compile("(?<!job_scraper/)(?<![\\w/.-])seen_jobs\\.json");
}

class ScrapeSeenJobsPathSpec(unittest.TestCase) {
    def test_no_bare_seen_jobs_reference -> any;
}

with entry:__main__ {
    unittest.main();
}
