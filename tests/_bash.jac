import os;
import shutil;
import subprocess;
import from pathlib { Path }

glob WINDOWS: bool = os.name == "nt";

"""A bash that expands shell variables: the one on PATH, else Git for Windows' own."""
def find_bash -> str | None;
