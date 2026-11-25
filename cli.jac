"""The jobsearch command line: `jobsearch <tool> [<argument>...]` runs one of the tools;
`jobsearch test [<test module>...]` runs the test suite, which is the app `tests`."""
import os, shutil, subprocess, sys;
import from pathlib { Path }

glob ROOT: Path = Path(Path(__file__).resolve().parent);

glob TOOLS: list[str] = [
    "check_framework_version",
    "check_upstream_updates",
    "convert_salary_excel",
    "fetch_page",
    "html_report",
    "install_portal_clis",
    "job_key",
    "lint_skills",
    "page_decode",
    "posting_guard",
    "rank_state",
    "report_data",
    "robots_check",
    "salary_lookup",
    "scrape_state",
    "security_guards",
    "upstream_triage",
    "verify_layout",
    "verify_pdf",
];

def usage -> str {
    return "usage: jobsearch <tool> [<argument>...]\n       jobsearch test [<test module>...]\ntools: "
        + ", ".join(TOOLS);
}

"""Run the tool `name` as its module's `with entry:__main__` would, and give its exit status.
Each tool's module is imported where its case runs, so a run starts only the tool it runs: the
others' globals are never made. The tools of PYTOOLS run as the app pytools instead.
page_decode and report_data are libraries, with no run of their own: their module code only
defines names, so running them does nothing."""
def run_tool(name: str) -> int | None {
    match name {
        case "check_framework_version":
            import tools.check_framework_version as check_framework_version;
            return check_framework_version.main();
        case "check_upstream_updates":
            import tools.check_upstream_updates as check_upstream_updates;
            return check_upstream_updates.main();
        case "fetch_page":
            import tools.fetch_page as fetch_page;
            return fetch_page.main();
        case "html_report":
            import tools.html_report as html_report;
            html_report.main();
        case "install_portal_clis":
            import tools.install_portal_clis as install_portal_clis;
            return install_portal_clis.main();
        case "job_key":
            import tools.job_key as job_key;
            return job_key.main();
        case "posting_guard":
            import tools.posting_guard as posting_guard;
            return posting_guard.main();
        case "rank_state":
            import tools.rank_state as rank_state;
            return rank_state.main();
        case "robots_check":
            import tools.robots_check as robots_check;
            return robots_check.main();
        case "salary_lookup":
            import salary_lookup;
            salary_lookup.main();
        case "scrape_state":
            import tools.scrape_state as scrape_state;
            return scrape_state.main();
        case "security_guards":
            import tools.security_guards as security_guards;
            return security_guards.main();
        case "upstream_triage":
            import tools.upstream_triage as upstream_triage;
            return upstream_triage.main();
        case "verify_layout":
            import tools.verify_layout as verify_layout;
            return verify_layout.main();
    }
    return None;
}

glob PYTOOLS: set[str] = {"convert_salary_excel", "lint_skills", "verify_pdf"},
     PYTOOLS_SOURCES: list[str] = [
         "pycli.jac",
         "tools/convert_salary_excel.jac",
         "tools/lint_skills.jac",
         "tools/verify_pdf.jac",
         "archwire.jac",
         "jac.toml",
     ];

"""Run a tool of PYTOOLS as the app `pytools`, in place of this program: its launcher, which a
build rewrites, is built again first when one of its sources is newer than it, or missing."""
def run_pytool(argv: list[str]) -> int {
    launcher: Path = ROOT / "dist" / "pytools" / "pytools";
    built: float = launcher.stat().st_mtime if launcher.exists() else -1.0;
    stale: bool = any([
        (ROOT / s).stat().st_mtime > built
        for s in PYTOOLS_SOURCES
        if (ROOT / s).exists()
    ]);
    if stale {
        neojac: str | None = shutil.which("neojac");
        if neojac is not None {
            subprocess.run([neojac, "build", "pytools"], cwd=str(ROOT), stdout=subprocess.DEVNULL);
        }
    }
    if not launcher.exists() {
        print(
            f"jobsearch: {argv[0]} runs as the app pytools, which is not built: run `neojac build pytools`",
            file=sys.stderr,
        );
        return 2;
    }
    os.execv(str(launcher), [str(launcher), *argv]);
    return 2;
}

def main -> int | None {
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help") {
        print(usage());
        return 0 if len(sys.argv) > 1 else 2;
    }
    if sys.argv[1] == "test" {
        neojac: str | None = shutil.which("neojac");
        if neojac is None {
            print(
                "jobsearch: `jobsearch test` runs `neojac run tests`, and neojac is not on PATH",
                file=sys.stderr,
            );
            return 2;
        }
        os.chdir(ROOT);
        os.execv(neojac, ["neojac", "run", "tests", "--", *sys.argv[2:]]);
    }
    name: str = sys.argv[1].removesuffix(".py").removesuffix(".jac").removeprefix("tools/");
    if name not in TOOLS {
        print(f"jobsearch: no tool named '{sys.argv[1]}'\n{usage()}", file=sys.stderr);
        return 2;
    }
    if name in PYTOOLS {
        return run_pytool([name, *sys.argv[2:]]);
    }
    sys.argv = [name] + sys.argv[2:];
    return run_tool(name);
}

with entry {
    sys.exit(main());
}
