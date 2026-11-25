"""Companion commands must inspect the same selected upstream ref."""

import re;

import shlex;

import shutil;

import subprocess;

import sys;

import unittest;

import from pathlib { Path }

class CompanionRefTests(UpstreamCheckerRepoFixture) {
    static has branch_name: any = "release/next";

    def setUp -> any;

    def git(*args_) -> any;

    def follow(command) -> any;

    def test_version_checker_companion_uses_selected_remote_and_branch -> any;

    def test_triage_companion_uses_selected_remote_and_branch -> any;
}

class QuotedCompanionRefTests(CompanionRefTests) {
    static has branch_name: any = "release'next";
}
