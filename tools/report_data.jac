"""Data layer for /html-report.

Tracker read, status buckets, outcome.md stage matching, counts, funnel and
rejection rate, wrapped in load() so the view (tools/html_report.jac) can
render it. The view must not recompute these figures differently.
"""

import operator;
import collections;

import csv;

import datetime;

import glob;

import os;

import re;

import sys;

import unicodedata;

glob BUCKET: any = {
    "drafted": "Drafted",
    "applied": "Active",
    "interview": "Interview",
    "offer": "Offer",
    "hired": "Hired",
};

glob CLOSED: any = {
    "rejected",
    "no_response",
    "no response",
    "offer_declined",
    "offer declined",
    "withdrawn",
};

glob FIELDS: any = [
    "date",
    "company",
    "sector",
    "role",
    "role_type",
    "channel",
    "status",
    "contact_person",
    "fit_rating",
    "notes",
    "cv_file",
    "cover_letter_file",
    "source",
    "deadline",
];

glob STAGES: any = [
    "Application screen",
    "Recruiter screen",
    "Technical round",
    "Case or presentation",
    "Final round",
    "Offer",
    "Hired",
];

glob STATUS_STAGE: any = {
    "interview": 1,
    "offer": 5,
    "offer_declined": 5,
    "offer declined": 5,
    "hired": 6,
};

glob TICK_STAGE: any = [
    (5, "offer"),
    (4, "final"),
    (3, "case|assessment|presentation"),
    (2, "technical"),
    (1, "phone|screen|recruiter|interview"),
];

glob INTERVIEW: any;

glob OFFER: any;

glob HIRED: any;

glob STATUS_ORDER: any;

with entry {
    (INTERVIEW, OFFER, HIRED) = (1, 5, 6);
    STATUS_ORDER = ["Drafted", "Active", "Interview", "Offer", "Hired", "Rejected/Closed"];
}

"""The Subfolder naming rule in documents/README.md: <company>_<role>, lowercase, spaces to
    underscores, every character but a letter, digit or underscore dropped, runs of underscores
    collapsed, ends trimmed. NFC first, so a name typed with combining accents matches its folder."""
def folder_name(company, role) -> any;

"""(start of the period, precision) for a YYYY, YYYY-MM or YYYY-MM-DD date (- or / between the
    parts); None if unparseable, before 1970 or over a year ahead, so a typo year cannot stretch
    the chart over centuries."""
def when(s, today=None) -> any;

"""The '## Interview stages reached' checklist of an outcome.md, so a checklist under Notes
    cannot advance a stage. A file without that heading (hand-written) is read whole."""
def stages_section(txt) -> any;

"""Sent applications per week while first application to today spans under 12 weeks of full dates, else per
    month, or per year when some rows record only the year. Months and years end at the last
    application, so a finished search is not a run of empty bars."""
def timeline(sent, today) -> any;

def load(`root=".") -> any;
