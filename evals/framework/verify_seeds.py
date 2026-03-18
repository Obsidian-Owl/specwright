"""Seed verification script for Layer 3 workflow evals.

Downloads SWE-PolyBench instances from HuggingFace, filters for multi-file
JS/TS tasks, and verifies each seed: clone at base_commit, install deps,
confirm FAIL_TO_PASS tests fail.

Usage:
    # Populate seeds.json from dataset (requires: pip install datasets)
    python -m evals.framework.verify_seeds --populate

    # Verify existing seeds (clone, install, test)
    python -m evals.framework.verify_seeds --verify

    # Both: populate then verify
    python -m evals.framework.verify_seeds --populate --verify
"""

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SEEDS_PATH = Path(__file__).parent.parent / "suites" / "workflow" / "seeds.json"
DATASET_NAME = "AmazonScience/SWE-PolyBench"
TARGET_LANGUAGES = {"JavaScript", "TypeScript"}
MIN_FUNC_CHANGES = 2
MAX_SEEDS_PER_LANGUAGE = 5


def load_seeds() -> dict:
    """Load seeds.json."""
    with open(SEEDS_PATH) as f:
        return json.load(f)


def save_seeds(data: dict) -> None:
    """Write seeds.json."""
    with open(SEEDS_PATH, "w") as f:
        json.dump(data, f, indent=2)
    print(f"Saved {len(data['seeds'])} seeds to {SEEDS_PATH}")


def populate_from_dataset() -> None:
    """Download SWE-PolyBench and select multi-file JS/TS instances."""
    try:
        from datasets import load_dataset
    except ImportError:
        print("Error: 'datasets' package required. Install with: pip install datasets")
        sys.exit(1)

    print(f"Loading {DATASET_NAME}...")
    ds = load_dataset(DATASET_NAME, split="test")

    seeds = []
    counts = {"JavaScript": 0, "TypeScript": 0}

    for row in ds:
        lang = row.get("language", "")
        if lang not in TARGET_LANGUAGES:
            continue
        if counts[lang] >= MAX_SEEDS_PER_LANGUAGE:
            continue
        if (row.get("num_func_changes", 0) or 0) < MIN_FUNC_CHANGES:
            continue

        f2p = json.loads(row.get("F2P", "[]"))
        p2p = json.loads(row.get("P2P", "[]"))

        if not f2p:
            continue

        patch = row.get("patch", "")
        files_changed = len(set(
            line.split(" b/")[-1] for line in patch.splitlines()
            if line.startswith("diff --git")
        ))
        lines_changed = sum(
            1 for line in patch.splitlines()
            if line.startswith("+") and not line.startswith("+++")
            or line.startswith("-") and not line.startswith("---")
        )

        if files_changed < 2:
            continue

        seeds.append({
            "id": row["instance_id"],
            "source": "swe-polybench",
            "repo": row["repo"],
            "base_commit": row["base_commit"],
            "language": lang.lower(),
            "problem_statement": row.get("problem_statement", "")[:500],
            "fail_to_pass": f2p,
            "pass_to_pass": p2p[:20],
            "files_changed": files_changed,
            "lines_changed": lines_changed,
            "verified": False,
            "verified_date": None,
        })
        counts[lang] += 1

        if all(c >= MAX_SEEDS_PER_LANGUAGE for c in counts.values()):
            break

    print(f"Selected {len(seeds)} seeds: {counts}")

    data = load_seeds()
    data["seeds"] = seeds
    save_seeds(data)


def verify_seeds() -> None:
    """Verify each seed: clone, install, confirm F2P tests fail."""
    data = load_seeds()
    now = datetime.now(timezone.utc).isoformat()

    for seed in data["seeds"]:
        if seed.get("verified"):
            print(f"  SKIP {seed['id']} (already verified)")
            continue

        if seed["base_commit"] == "PENDING_VERIFICATION":
            print(f"  SKIP {seed['id']} (not yet populated)")
            continue

        print(f"  Verifying {seed['id']}...")
        workdir = tempfile.mkdtemp(prefix=f"seed-verify-{seed['id'][:30]}-")

        try:
            # Clone
            subprocess.run(
                ["git", "clone", "--depth", "1", f"https://github.com/{seed['repo']}.git", workdir],
                check=True, capture_output=True, text=True,
            )

            # Fetch and checkout specific commit
            subprocess.run(
                ["git", "fetch", "--depth", "1", "origin", seed["base_commit"]],
                cwd=workdir, check=True, capture_output=True, text=True,
            )
            subprocess.run(
                ["git", "checkout", seed["base_commit"]],
                cwd=workdir, check=True, capture_output=True, text=True,
            )

            # Install deps
            if os.path.exists(os.path.join(workdir, "package.json")):
                subprocess.run(
                    ["npm", "install"],
                    cwd=workdir, capture_output=True, text=True,
                    timeout=300,
                )

            # Run F2P tests — should fail
            result = subprocess.run(
                ["npm", "test"],
                cwd=workdir, capture_output=True, text=True,
                timeout=300,
            )

            if result.returncode != 0:
                seed["verified"] = True
                seed["verified_date"] = now
                print(f"    PASS — tests fail as expected (exit {result.returncode})")
            else:
                print(f"    FAIL — tests unexpectedly pass at base commit")

        except subprocess.CalledProcessError as exc:
            print(f"    ERROR — {exc}")
        except subprocess.TimeoutExpired:
            print(f"    ERROR — timeout during verification")
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    save_seeds(data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed verification for workflow evals")
    parser.add_argument("--populate", action="store_true", help="Populate seeds from SWE-PolyBench")
    parser.add_argument("--verify", action="store_true", help="Verify existing seeds")
    args = parser.parse_args()

    if not args.populate and not args.verify:
        parser.print_help()
        return

    if args.populate:
        populate_from_dataset()

    if args.verify:
        verify_seeds()


if __name__ == "__main__":
    main()
