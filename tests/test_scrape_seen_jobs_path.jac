import re;
import unittest;
import from pathlib { Path }

glob ROOT: Path = Path(__file__).resolve().parent.parent,
     SPECS: list[str] = [
         ".claude/skills/job-scraper/SKILL.md",
         ".claude/commands/rank.md",
         ".claude/commands/notion-sync.md",
         ".claude/skills/upskill/SKILL.md",
     ],
     BARE: any = re.compile("(?<!job_scraper/)(?<![\\w/.-])seen_jobs\\.json");

class ScrapeSeenJobsPathSpec(unittest.TestCase) {
    def test_no_bare_seen_jobs_reference {
        for spec in SPECS {
            with self.subTest(spec=spec) {
                lines: list[str] = (ROOT / spec).read_text(encoding="utf-8").splitlines();
                offenders: list[str] = [
                    f"line {i}: {line.strip()[:90]}"
                    for (i, line) in enumerate(lines, 1)
                    if BARE.search(line)
                ];
                self.assertEqual(
                    offenders, [], "use job_scraper/seen_jobs.json everywhere in the spec"
                );
            }
        }
    }
}
