"""The tools that load a PyPI package (PyYAML, openpyxl, pypdf), which the native jobsearch program
runs as this CPython app, `pytools`: a native program that loads a Python module starts CPython
as it starts, so these three live apart and the other tools start without it."""
import sys;

with entry {
    name: str = sys.argv[1];
    sys.argv = [name] + sys.argv[2:];
    if name == "lint_skills" {
        sys.exit(lint_skills.main());
    } elif name == "convert_salary_excel" {
        convert_salary_excel.main();
    } elif name == "verify_pdf" {
        sys.exit(verify_pdf.main());
    } else {
        sys.exit(f"pytools: no tool named '{name}'");
    }
}
