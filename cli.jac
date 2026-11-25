import runpy, sys, unittest;
import from pathlib { Path }

glob ROOT: Path = Path(__file__).resolve().parent;

def tool_names -> list[str] {
    names: list[str] = [p.stem for p in (ROOT / "tools").glob("*.jac")];
    names.append("salary_lookup");
    return sorted(names);
}

def module_of(name: str) -> str {
    return name if name == "salary_lookup" else f"tools.{name}";
}

def usage -> str {
    return "usage: jobsearch <tool> [<argument>...]\n       jobsearch test [<test module>...]\ntools: "
        + ", ".join(tool_names());
}

def run_tests(names: list[str]) -> int {
    modules: list[str] = names or sorted(p.stem for p in (ROOT / "tests").glob("test_*.jac"));
    suite: unittest.TestSuite = unittest.defaultTestLoader.loadTestsFromNames([
        f"tests.{name.removeprefix('tests.')}"
        for name in modules
    ]);
    result: unittest.TestResult = unittest.TextTestRunner().run(suite);
    return 0 if result.wasSuccessful() else 1;
}

def main -> int {
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help") {
        print(usage());
        return 0 if len(sys.argv) > 1 else 2;
    }
    if sys.argv[1] == "test" {
        return run_tests(sys.argv[2:]);
    }
    name: str = sys.argv[1].removesuffix(".py").removesuffix(".jac").removeprefix("tools/");
    if name not in tool_names() {
        print(f"jobsearch: no tool named '{sys.argv[1]}'\n{usage()}", file=sys.stderr);
        return 2;
    }
    sys.argv = [name] + sys.argv[2:];
    runpy.run_module(module_of(name), run_name="__main__", alter_sys=True);
    return 0;
}

with entry {
    sys.exit(main());
}
