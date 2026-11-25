impl ExactRankRoundingCLI.test_half_points_round_up_into_the_right_verdict_band {
    with TemporaryDirectory() as directory {
        state: Path = Path(directory) / "seen_jobs.json";
        results: Path = Path(directory) / "scores.json";
        state.write_text(
            json.dumps({
                "seen": {
                    key: {
                        "title": "SOC Analyst",
                        "company": "Acme",
                        "status": "new",
                        "url": f"https://example.com/jobs/{key}",
                        "deadline": None,
                    }
                    for key in CASES
                },
            }),
            encoding="utf-8",
        );
        results.write_text(
            json.dumps([
                {
                    "key": key,
                    "status": "scored",
                    "scores": dict(zip(DIMENSIONS, values)),
                    "location_verdict": "PASS",
                    "language_gate": "PASS",
                    "deadline": None,
                }
                for (key, (values, _, _)) in CASES.items()
            ]),
            encoding="utf-8",
        );
        proc: any = subprocess.run(
            [
                *TOOL,
                "apply",
                "--state",
                str(state),
                "--results",
                str(results),
                "--today",
                "2026-10-16",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
        );
        self.assertEqual(proc.returncode, 0, proc.stderr);
        output: dict[str, any] = json.loads(proc.stdout);
        stored: dict[str, any] = json.loads(state.read_text(encoding="utf-8"))["seen"];
        expected: dict[str, tuple[int, str]] = {
            key: (score, verdict)
            for (key, (_, score, verdict)) in CASES.items()
        };
        self.assertEqual(output["errors"], []);
        self.assertEqual(
            {row["key"]: (row["score"], row["verdict"]) for row in output["ranked"]}, expected
        );
        self.assertEqual(
            {key: (job["rank_score"], job["rank_verdict"]) for (key, job) in stored.items()},
            expected,
        );
    }
}
