"""Canonical dedup key for a job posting, and an audit for existing state.

A seen_jobs.json key is a pure function of the posting: "<company slug>_<title slug>", each
half ASCII, length-capped, and disambiguated by a hash of the full slug when it is cut. A
half whose ASCII fold drops letters (a non-Latin script) keeps the surviving fragment as a
readable prefix and takes its identity from the portal's numeric id in the URL, or a hash.

Usage:
  neojac run jobsearch -- job_key --company "Acme Corp" --title "SOC Analyst (L2)"
  neojac run jobsearch -- job_key --audit job_scraper/seen_jobs.json
  neojac run jobsearch -- job_key --audit --migrate

`--audit --migrate` rewrites keys that no longer match the current rule, in place: backup
first, old->new reported, a new key that already exists is reported and left alone, and a
second run changes nothing.

Exit 0 when a key is produced, or when an audit finds nothing. Exit 1 when an audit finds
violations.
"""

import argparse;
import hashlib;
import json;
import os;
import re;
import shutil;
import sys;
import unicodedata;
import from datetime { datetime }
import from pathlib { Path }

glob ROOT: Path = Path(os.environ.get("JOBSEARCH_ROOT") or Path(__file__).resolve().parent.parent),
     STATE: Path = ROOT / "job_scraper" / "seen_jobs.json",
     COMPANY_MAX: int = 40,
     TITLE_MAX: int = 60,
     HASH_LEN: int = 6,
     _NON_SLUG: any = re.compile("[^a-z0-9]+"),
     _JOB_ID: any = re.compile("(\\d{6,})"),
     _SLUG: str = "[a-z0-9][a-z0-9-]*",
     _CANONICAL: any = re.compile(f"^{_SLUG}_{_SLUG}$"),
     _LATIN_FOLD: dict[str, str] = {
         pair[0]: pair[1:]
         for pair in "øo ØO æae ÆAE œoe ŒOE ßss ẞSS þth ÞTH ðd ÐD đd ĐD łl ŁL ıi ħh ĦH ĸk ŋng ŊNG ŧt ŦT".split()
     },
     _LATIN_FOLD_TABLE: dict[int, any] = str.maketrans(_LATIN_FOLD);

"""Lowercase ASCII slug. Non-Latin scripts legitimately reduce to ''."""
def slugify(text: str) -> str {
    folded: str = unicodedata.normalize("NFKD", str(text or "")).translate(_LATIN_FOLD_TABLE);
    ascii_only: str = folded.encode("ascii", "ignore").decode("ascii");
    return _NON_SLUG.sub("-", ascii_only.replace("+", "plus").replace("#", "sharp").lower()).strip(
        "-"
    );
}

"""True when the ASCII fold dropped non-Latin letters, so the slug under-identifies."""
def _lost_letters(text: str) -> bool {
    return any([
        ord(ch) >= 128 and ch.isalpha() and not unicodedata.name(ch, "LATIN").startswith("LATIN")
        for ch in unicodedata.normalize("NFKD", str(text or ""))
    ]);
}

def _digest(text: str) -> str {
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:HASH_LEN];
}

"""Cap the length, appending a hash of the full slug so truncation stays deterministic."""
def _cap(slug: str, limit: int) -> str {
    return slug if len(slug) <= limit else f"{slug[:limit].rstrip('-')}-{_digest(slug)}";
}

"""The canonical seen_jobs.json key for one posting."""
def make_key(company: str, title: str, url: str = "") -> str {
    company_slug: str = _cap(slugify(company), COMPANY_MAX);
    if not company_slug or _lost_letters(company) {
        name: str = unicodedata.normalize("NFC", str(company or "").strip().casefold());
        company_slug = f"{company_slug or 'company'}-{_digest(name)}"
            if name
            else "unknown-company";
    }
    title_slug: str = _cap(slugify(title), TITLE_MAX);
    if not title_slug or _lost_letters(title) {
        job_id: any = _JOB_ID.search(url or "");
        ident: str = job_id.group(1) if job_id else _digest(str(url or title));
        if title_slug {
            title_slug = f"{title_slug}-{ident}";
        } else {
            title_slug = ident if job_id else slugify(title or url) or f"untitled-{ident}";
        }
    }
    return f"{company_slug}_{title_slug}";
}

"""Structurally safe as a dedup key and as an archive folder name."""
def is_canonical(key: str) -> bool {
    return bool(key and _CANONICAL.match(key));
}

"""Old three-part "company_title_location" keys: harmless, but not what make_key produces."""
def is_legacy_shape(key: str) -> bool {
    return bool(key)
        and key.count("_") > 1
        and all([re.fullmatch(_SLUG, part) for part in key.split("_") if part]);
}

"""Why a decoded state file cannot be audited, or None."""
def _flaw(seen: any) -> str | None {
    if not isinstance(seen, dict) {
        return "expected an object of job entries";
    }
    not_objects: list[str] = [k for (k, v) in seen.items() if not isinstance(v, dict)];
    if not_objects {
        return f"entry is not an object: {not_objects[0]}";
    }
    bad_url: list[str] = [
        k
        for (k, v) in seen.items()
        if v.get("url") is not None and not isinstance(v["url"], str)
    ];
    return f"entry url is not a string: {bad_url[0]}" if bad_url else None;
}

"""Return (document, seen) or print the reason and return None."""
def _load_seen(path: Path) -> tuple[any, dict[str, any]] | None {
    try {
        doc: any = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) as exc {
        print(f"cannot read {path}: {exc}", file=sys.stderr);
        return None;
    }
    seen: any = doc.get("seen", doc) if isinstance(doc, dict) else doc;
    flaw: str | None = _flaw(seen);
    if flaw {
        print(f"{path}: {flaw}", file=sys.stderr);
        return None;
    }
    return (doc, seen);
}

"""Canonical keys that differ from what make_key produces today, with their new key."""
def _drifted(seen: dict[str, any]) -> dict[str, str] {
    current: dict[str, str] = {
        k: make_key(v.get("company", ""), v.get("title", ""), v.get("url", ""))
        for (k, v) in seen.items()
        if is_canonical(k)
    };
    return {k: new for (k, new) in current.items() if new != k};
}

"""One pass: the drifted keys that can move, and those blocked by a key that stays put."""
def _rename_pass(seen: dict[str, any]) -> tuple[dict[str, str], list[dict[str, str]]] {
    movers: dict[str, str] = _drifted(seen);
    blocked: dict[str, str] = {};
    changed: bool = True;
    while changed {
        changed = False;
        claimed: set[str] = set();
        for (old, new) in list(movers.items()) {
            if new in seen and new not in movers or new in claimed {
                blocked[old] = new;
                del movers[old];
                changed = True;
            } else {
                claimed.add(new);
            }
        }
    }
    return (movers, [{"old": o, "new": n} for (o, n) in blocked.items()]);
}

"""Rewrite drifted keys in place, never overwriting an existing key; return the report."""
def migrate(path: Path, doc: any, seen: dict[str, any]) -> dict[str, any] {
    current: dict[str, any] = dict(seen);
    migrated: list[dict[str, str]] = [];
    collisions: list[dict[str, str]] = [];
    for _ in range(len(seen) + 1) {
        (renames, collisions) = _rename_pass(current);
        if not renames {
            break;
        }
        migrated.extend([{"old": o, "new": n} for (o, n) in renames.items()]);
        current = {renames.get(k, k): v for (k, v) in current.items()};
    }
    outcome: dict[str, any] = {
        "migrated": migrated,
        "migrate_collisions": collisions,
        "backup": None,
    };
    if migrated {
        backup: Path = path.with_name(f"{path.name}.bak-{datetime.now():%Y%m%d-%H%M%S}");
        shutil.copy2(path, backup);
        outcome["backup"] = str(backup);
        save_state(
            path, dict(doc, seen=current) if isinstance(doc, dict) and "seen" in doc else current
        );
    }
    return outcome;
}

def audit(path: Path, do_migrate: bool = False) -> int {
    loaded: tuple[any, dict[str, any]] | None = _load_seen(path);
    migration: dict[str, any] = {};
    if loaded and do_migrate {
        migration = migrate(path, loaded[0], loaded[1]);
        if migration["migrated"] {
            loaded = _load_seen(path);
        }
    }
    if loaded is None {
        return 1;
    }
    seen: dict[str, any] = loaded[1];
    legacy: list[str] = [k for k in seen if is_legacy_shape(k)];
    malformed: list[str] = [k for k in seen if not is_canonical(k) and k not in legacy];
    by_url: dict[str, list[str]] = {};
    for (key, job) in seen.items() {
        url: str = (job.get("url") or "").rstrip("/");
        if url {
            by_url.setdefault(url, []).append(key);
        }
    }
    duplicates: dict[str, list[str]] = {u: ks for (u, ks) in by_url.items() if len(ks) > 1};
    found: dict[str, any] = {
        "entries": len(seen),
        "malformed_keys": malformed,
        "legacy_three_part_keys": legacy,
        "duplicate_urls": duplicates,
        "keys_not_matching_current_rule": len(_drifted(seen)),
        **migration,
    };
    print(json.dumps(found, indent=2, ensure_ascii=False));
    return 1 if malformed or duplicates else 0;
}

def main -> int {
    _force_utf8_output();
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__.splitlines()[0]);
    ap.add_argument("--company");
    ap.add_argument("--title");
    ap.add_argument("--url", default="");
    ap.add_argument("--audit", nargs="?", const=str(STATE), metavar="STATE_JSON");
    ap.add_argument(
        "--migrate",
        action="store_true",
        help="with --audit: rewrite drifted keys in place (backup first)",
    );
    args: any = ap.parse_args();
    if args.migrate and not args.audit {
        ap.error("--migrate needs --audit");
    }
    if args.audit {
        return audit(Path(args.audit), args.migrate);
    }
    if args.company is None or args.title is None {
        ap.error("give --company and --title, or --audit");
    }
    print(make_key(args.company, args.title, args.url));
    return 0;
}

with entry:__main__ {
    sys.exit(main());
}
