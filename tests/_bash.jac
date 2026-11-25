import operator;

import os;

import from pathlib { Path }

import shutil;

import subprocess;

glob WINDOWS: any;

with entry {
    WINDOWS = operator.eq(os.name, "nt");
}

def find_bash -> any;
