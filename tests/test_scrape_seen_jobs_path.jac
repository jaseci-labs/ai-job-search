"""Every seen_jobs.json reference in the scrape/rank/notion-sync/upskill specs names the full path.

Step 0 reads `job_scraper/seen_jobs.json`, but later steps (notably Step 4,
where the file is written) used the bare filename. An agent following Step 4
literally can create `seen_jobs.json` in the repo root. The ignore rules only
cover `**/job_scraper/seen_jobs.json`, so a root-level copy is untracked-by-rule
only by accident: it shows up in `git status`, gets swept into a commit, and
publishes the user's scrape history. Pinning the full path in the spec keeps
the read path, the write path and the ignore rule pointing at the same file.
"""

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
