"""The test suite's runner, the entry of the app `tests`: `neojac run tests -- [<test module>...]`,
or `neojac run jobsearch -- test [<test module>...]`, which runs this."""
import shutil, subprocess, sys, unittest;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parent.parent;

def run_tests(names: list[str]) -> int {
    modules: list[str] = names or sorted(p.stem for p in (REPO / "tests").glob("test_*.jac"));
    suite: unittest.TestSuite = unittest.defaultTestLoader.loadTestsFromNames([
        f"tests.{name.removeprefix('tests.')}"
        for name in modules
    ]);
    result: unittest.TestResult = unittest.TextTestRunner().run(suite);
    return 0 if result.wasSuccessful() else 1;
}

with entry {
    # The tests run the tools as the programs jobsearch and pytools: build them first, so they
    # are the programs of these sources (a build with nothing to do takes a moment).
    neojac: str | None = shutil.which("neojac");
    if neojac is not None {
        for app in ("jobsearch", "pytools") {
            subprocess.run([neojac, "build", app], cwd=REPO, check=True, stdout=subprocess.DEVNULL);
        }
    }
    sys.exit(run_tests(sys.argv[1:]));
}
