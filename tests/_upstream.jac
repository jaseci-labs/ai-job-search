import os;
import subprocess;
import from pathlib { Path }

glob UPSTREAM: str = "ai-job-search-dev/ai-job-search",
     REPO: Path = Path(__file__).resolve().parent.parent,
     GITHUB_PREFIXES: tuple[str, ...] = (
         "https://github.com/",
         "git@github.com:",
         "ssh://git@github.com/",
     );

def _is_upstream_url(url: str) -> bool;

"""Whether this checkout is the template repository itself; True when that cannot be told."""
def is_upstream_checkout -> bool;
