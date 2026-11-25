"""Data layer for /html-report: tracker rows, status buckets, outcome.md stages, counts,
funnel and rates, gathered by load() for tools/html_report.jac to render unchanged."""

import collections;
import csv;
import datetime;
import from glob { glob as list_paths }
import os;
import re;
import sys;
import unicodedata;

glob BUCKET: dict[str, str] = {
         "drafted": "Drafted",
         "applied": "Active",
         "interview": "Interview",
         "offer": "Offer",
         "hired": "Hired",
     },
     CLOSED: set[str] = {
         "rejected",
         "no_response",
         "no response",
         "offer_declined",
         "offer declined",
         "withdrawn",
     },
     FIELDS: list[str] = "date company sector role role_type channel status contact_person fit_rating notes cv_file cover_letter_file source deadline".split(),
     STAGES: list[str] = [
         "Application screen",
         "Recruiter screen",
         "Technical round",
         "Case or presentation",
         "Final round",
         "Offer",
         "Hired",
     ],
     STATUS_STAGE: dict[str, int] = {
         "interview": 1,
         "offer": 5,
         "offer_declined": 5,
         "offer declined": 5,
         "hired": 6,
     },
     TICK_STAGE: list[tuple[int, str]] = [
         (5, "offer"),
         (4, "final"),
         (3, "case|assessment|presentation"),
         (2, "technical"),
         (1, "phone|screen|recruiter|interview"),
     ],
     INTERVIEW: int = 1,
     OFFER: int = 5,
     HIRED: int = 6,
     STATUS_ORDER: list[str] = [
         "Drafted",
         "Active",
         "Interview",
         "Offer",
         "Hired",
         "Rejected/Closed",
     ];

"""documents/README.md's folder rule: NFC, lowercase, spaces to underscores, only letters,
digits and underscores, runs collapsed, ends trimmed."""
def folder_name(company: str, role: str) -> str;

"""(start of period, precision) for YYYY, YYYY-MM or YYYY-MM-DD (- or /); None if unparseable,
before 1970 or over a year ahead."""
def when(s: str | None, today: any = None) -> any;

"""The '## Interview stages reached' checklist of an outcome.md, or the whole text without one."""
def stages_section(txt: str) -> str;

"""Applications per week (full dates within 12 weeks), else per month, else per year."""
def timeline(sent: list[any], today: any) -> any;

def load(path_root: str = ".") -> dict[str, any];
