impl ScrapeSeenJobsPathSpec.test_no_bare_seen_jobs_reference -> any {
    for spec in SPECS {
        with self.subTest(spec=spec.relative_to(ROOT).as_posix()) {
            offenders: any = [
                f"line {i}: {line.strip()[:90]}"
                for (i, line) in enumerate(spec.read_text(encoding="utf-8").splitlines(), 1)
                if BARE.search(line)
            ];
            self.assertEqual(
                offenders, [], "use job_scraper/seen_jobs.json everywhere in the spec"
            );
        }
    }
}
