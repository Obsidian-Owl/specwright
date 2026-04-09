"""Eval baseline schema, loader, validator, and comparison logic.

Unit 02b-1 of the legibility recovery. Pure Python; no CI integration.

Token shape mirrors evals.framework.runner.RunResult.tokens VERBATIM:
{input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens}.
NOT a normalized {input, output, total} shape.
"""

import json
import os
from dataclasses import dataclass, field
from typing import Any, Dict, List


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

class BaselineFileError(Exception):
    """Raised when a baseline file cannot be loaded or is structurally invalid."""


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------

@dataclass
class BaselineFile:
    """In-memory representation of an eval baseline file."""

    suite: str
    generated_at: str
    generated_from_commit: str
    tolerances: Dict[str, float]
    evals: Dict[str, Dict[str, Any]]
    provider: str = "claude"


@dataclass
class Regression:
    """A single metric that regressed against the baseline."""

    eval_id: str
    metric: str  # "pass_rate" | "duration_ms" | "tokens.<key>"
    baseline_value: float
    actual_value: float
    delta: float  # actual - baseline; positive for duration/tokens, negative for pass_rate
    verdict: str  # human-readable summary


@dataclass
class Improvement:
    """A single metric that strictly improved against the baseline."""

    eval_id: str
    metric: str
    baseline_value: float
    actual_value: float
    delta: float


@dataclass
class ComparisonResult:
    """Aggregate result of comparing a run against a baseline."""

    regressions: List[Regression] = field(default_factory=list)
    improvements: List[Improvement] = field(default_factory=list)
    missing_from_baseline: List[str] = field(default_factory=list)
    missing_from_run: List[str] = field(default_factory=list)
    table_markdown: str = ""
    exit_code: int = 0


# ---------------------------------------------------------------------------
# Schema validation
# ---------------------------------------------------------------------------

_REQUIRED_TOP_FIELDS = ("suite", "generated_at", "generated_from_commit", "tolerances", "evals")
_REQUIRED_TOLERANCE_FIELDS = ("pass_rate_delta", "duration_multiplier", "tokens_multiplier")
_REQUIRED_EVAL_FIELDS = ("pass_rate", "duration_ms")
_OPTIONAL_FIELD_PREFIX = "__"  # `__comment` and similar are ignored


def _validate_dict(data: Dict[str, Any]) -> List[str]:
    """Structural validation of a parsed baseline dict. Returns error list."""
    errors: List[str] = []

    if not isinstance(data, dict):
        return ["baseline file root must be a JSON object"]

    for fld in _REQUIRED_TOP_FIELDS:
        if fld not in data:
            errors.append(f"missing required top-level field: {fld!r}")

    if "provider" in data and not isinstance(data["provider"], str):
        errors.append("provider must be a string")

    if "tolerances" in data:
        tols = data["tolerances"]
        if not isinstance(tols, dict):
            errors.append("tolerances must be an object")
        else:
            for fld in _REQUIRED_TOLERANCE_FIELDS:
                if fld not in tols:
                    errors.append(f"tolerances missing required field: {fld!r}")
                elif not isinstance(tols[fld], (int, float)) or isinstance(tols[fld], bool):
                    errors.append(
                        f"tolerances.{fld} must be a number, got {type(tols[fld]).__name__}"
                    )

    if "evals" in data and isinstance(data["evals"], dict):
        for eval_id, entry in data["evals"].items():
            if not isinstance(entry, dict):
                errors.append(f"evals.{eval_id} must be an object")
                continue
            for fld in _REQUIRED_EVAL_FIELDS:
                if fld not in entry:
                    errors.append(f"evals.{eval_id} missing required field: {fld!r}")

            if "pass_rate" in entry:
                pr = entry["pass_rate"]
                if not isinstance(pr, (int, float)) or isinstance(pr, bool):
                    errors.append(
                        f"evals.{eval_id}.pass_rate must be a number, got {type(pr).__name__}"
                    )
                elif not (0.0 <= pr <= 1.0):
                    errors.append(
                        f"evals.{eval_id}.pass_rate out of range [0, 1]: {pr}"
                    )

            if "duration_ms" in entry:
                dur = entry["duration_ms"]
                if not isinstance(dur, (int, float)) or isinstance(dur, bool):
                    errors.append(
                        f"evals.{eval_id}.duration_ms must be a number, got {type(dur).__name__}"
                    )
                elif dur < 0:
                    errors.append(
                        f"evals.{eval_id}.duration_ms must be non-negative: {dur}"
                    )

            if "tokens" in entry and not isinstance(entry["tokens"], dict):
                errors.append(f"evals.{eval_id}.tokens must be an object")

    return errors


def validate_baseline_file(path: str) -> List[str]:
    """Validate a baseline file at `path`. Returns list of error strings (empty = valid)."""
    if not os.path.isfile(path):
        return [f"baseline file not found: {path}"]
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        return [f"baseline file is not valid JSON: {exc}"]
    except OSError as exc:
        return [f"could not read baseline file: {exc}"]
    return _validate_dict(data)


# ---------------------------------------------------------------------------
# Loader / writer
# ---------------------------------------------------------------------------

def baseline_filename(suite: str, provider: str) -> str:
    """Return the provider-specific filename for a suite baseline."""
    return f"{suite}.{provider}.json"


def resolve_baseline_path(
    suite: str,
    provider: str = "claude",
    baselines_dir: str = "evals/baselines",
) -> str:
    """Resolve the on-disk path for a suite baseline.

    Claude keeps a compatibility fallback to the legacy `{suite}.json`.
    """
    provider_path = os.path.join(baselines_dir, baseline_filename(suite, provider))
    if os.path.isfile(provider_path):
        return provider_path
    if provider == "claude":
        legacy_path = os.path.join(baselines_dir, f"{suite}.json")
        if os.path.isfile(legacy_path):
            return legacy_path
    return provider_path


def load_baseline(
    suite: str,
    baselines_dir: str = "evals/baselines",
    provider: str = "claude",
) -> BaselineFile:
    """Load a baseline file by suite name. Raises BaselineFileError on failure."""
    path = resolve_baseline_path(suite, provider=provider, baselines_dir=baselines_dir)
    if not os.path.isfile(path):
        raise BaselineFileError(f"baseline file not found: {path}")

    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise BaselineFileError(f"failed to parse baseline file {path}: {exc}") from exc
    except OSError as exc:
        raise BaselineFileError(f"could not read baseline file {path}: {exc}") from exc

    errors = _validate_dict(data)
    if errors:
        raise BaselineFileError(
            f"baseline file {path} is invalid: " + "; ".join(errors)
        )

    # Strip __comment-style ignored fields before constructing the dataclass
    stripped = {k: v for k, v in data.items() if not k.startswith(_OPTIONAL_FIELD_PREFIX)}

    file_provider = stripped.get("provider", provider)
    if file_provider != provider:
        raise BaselineFileError(
            f"baseline file {path} has provider {file_provider!r}, "
            f"expected {provider!r}"
        )

    return BaselineFile(
        suite=stripped["suite"],
        provider=file_provider,
        generated_at=stripped["generated_at"],
        generated_from_commit=stripped["generated_from_commit"],
        tolerances=dict(stripped["tolerances"]),
        evals=dict(stripped["evals"]),
    )


def write_baseline(baseline: BaselineFile, path: str) -> None:
    """Write a BaselineFile to disk as JSON."""
    out = {
        "suite": baseline.suite,
        "provider": baseline.provider,
        "generated_at": baseline.generated_at,
        "generated_from_commit": baseline.generated_from_commit,
        "tolerances": baseline.tolerances,
        "evals": baseline.evals,
    }
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        json.dump(out, f, indent=2)


# ---------------------------------------------------------------------------
# Comparison logic
# ---------------------------------------------------------------------------

def _compare_eval_metrics(
    eval_id: str,
    run_entry: Dict[str, Any],
    baseline_entry: Dict[str, Any],
    tolerances: Dict[str, float],
) -> tuple[List[Regression], List[Improvement]]:
    """Compare one eval's run metrics against its baseline. Returns (regressions, improvements)."""
    regressions: List[Regression] = []
    improvements: List[Improvement] = []

    # ----- pass_rate (zero-tolerance regression) -----
    base_pr = float(baseline_entry.get("pass_rate", 0.0))
    run_pr = float(run_entry.get("pass_rate", 0.0))
    pass_rate_delta_tol = float(tolerances.get("pass_rate_delta", 0.0))
    if run_pr < base_pr - pass_rate_delta_tol:
        regressions.append(
            Regression(
                eval_id=eval_id,
                metric="pass_rate",
                baseline_value=base_pr,
                actual_value=run_pr,
                delta=run_pr - base_pr,
                verdict=f"pass_rate dropped from {base_pr:.3f} to {run_pr:.3f}",
            )
        )
    elif run_pr > base_pr:
        improvements.append(
            Improvement(
                eval_id=eval_id,
                metric="pass_rate",
                baseline_value=base_pr,
                actual_value=run_pr,
                delta=run_pr - base_pr,
            )
        )

    # ----- duration_ms (over multiplier → regression) -----
    base_dur = float(baseline_entry.get("duration_ms", 0))
    run_dur = float(run_entry.get("duration_ms", 0))
    dur_mult = float(tolerances.get("duration_multiplier", 1.0))
    if base_dur > 0 and run_dur > base_dur * dur_mult:
        regressions.append(
            Regression(
                eval_id=eval_id,
                metric="duration_ms",
                baseline_value=base_dur,
                actual_value=run_dur,
                delta=run_dur - base_dur,
                verdict=f"duration {run_dur:.0f}ms > {base_dur:.0f}ms × {dur_mult:.2f}",
            )
        )
    elif base_dur > 0 and run_dur < base_dur:
        improvements.append(
            Improvement(
                eval_id=eval_id,
                metric="duration_ms",
                baseline_value=base_dur,
                actual_value=run_dur,
                delta=run_dur - base_dur,
            )
        )

    # ----- tokens (per-key, only keys present in baseline) -----
    base_tokens = baseline_entry.get("tokens") or {}
    run_tokens = run_entry.get("tokens") or {}
    tok_mult = float(tolerances.get("tokens_multiplier", 1.0))
    for tok_key, base_val in base_tokens.items():
        if not isinstance(base_val, (int, float)) or isinstance(base_val, bool):
            continue
        run_val = run_tokens.get(tok_key, 0)
        if not isinstance(run_val, (int, float)) or isinstance(run_val, bool):
            run_val = 0
        if base_val > 0 and run_val > base_val * tok_mult:
            regressions.append(
                Regression(
                    eval_id=eval_id,
                    metric=f"tokens.{tok_key}",
                    baseline_value=float(base_val),
                    actual_value=float(run_val),
                    delta=float(run_val - base_val),
                    verdict=f"tokens.{tok_key} {run_val} > {base_val} × {tok_mult:.2f}",
                )
            )
        elif base_val > 0 and run_val < base_val:
            improvements.append(
                Improvement(
                    eval_id=eval_id,
                    metric=f"tokens.{tok_key}",
                    baseline_value=float(base_val),
                    actual_value=float(run_val),
                    delta=float(run_val - base_val),
                )
            )

    return regressions, improvements


def _render_table(
    run_results: Dict[str, Dict[str, Any]],
    baseline: BaselineFile,
    new_evals: List[str],
) -> str:
    """Render a delta table in markdown format."""
    lines = [
        "| Eval | Pass Rate | Duration | Tokens (input+output) | Verdict |",
        "|---|---|---|---|---|",
    ]
    all_ids = sorted(set(list(run_results.keys()) + list(baseline.evals.keys())))
    for eval_id in all_ids:
        run_entry = run_results.get(eval_id) or {}
        base_entry = baseline.evals.get(eval_id) or {}
        is_new = eval_id in new_evals
        is_missing = not run_entry

        if is_missing:
            lines.append(f"| {eval_id} | — | — | — | (skipped — in baseline only) |")
            continue

        run_pr = run_entry.get("pass_rate", 0.0)
        run_dur = run_entry.get("duration_ms", 0)
        run_tokens = run_entry.get("tokens") or {}
        run_io = (run_tokens.get("input_tokens", 0) or 0) + (run_tokens.get("output_tokens", 0) or 0)

        if is_new:
            verdict = "(new — no baseline)"
            pr_cell = f"{run_pr:.2f}"
            dur_cell = f"{run_dur:.0f}ms"
            tok_cell = f"{run_io:.0f}"
        else:
            base_pr = base_entry.get("pass_rate", 0.0)
            base_dur = base_entry.get("duration_ms", 0)
            base_tokens = base_entry.get("tokens") or {}
            base_io = (base_tokens.get("input_tokens", 0) or 0) + (base_tokens.get("output_tokens", 0) or 0)
            pr_delta = run_pr - base_pr
            pr_cell = f"{run_pr:.2f} ({pr_delta:+.2f})"
            # Use :+.0f (not :+d) so the formatter handles both ints and
            # floats. Aggregator returns float means; baseline JSON stores
            # ints; comparator may receive either.
            dur_cell = f"{run_dur:.0f}ms ({run_dur - base_dur:+.0f}ms)"
            tok_cell = f"{run_io:.0f} ({run_io - base_io:+.0f})"
            verdict = "ok"
        lines.append(f"| {eval_id} | {pr_cell} | {dur_cell} | {tok_cell} | {verdict} |")

    return "\n".join(lines) + "\n"


def compare_run_to_baseline(
    run_results: Dict[str, Dict[str, Any]],
    baseline: BaselineFile,
) -> ComparisonResult:
    """Compare a run's per-eval metrics against a baseline.

    Args:
        run_results: dict of {eval_id: {pass_rate, duration_ms, tokens}}
        baseline: BaselineFile loaded from disk

    Returns ComparisonResult with regressions, improvements, missing entries,
    a rendered markdown table, and an exit code (0 = clean, 1 = regressions).
    """
    result = ComparisonResult()

    run_ids = set(run_results.keys())
    baseline_ids = set(baseline.evals.keys())

    new_evals = sorted(run_ids - baseline_ids)
    skipped_evals = sorted(baseline_ids - run_ids)

    result.missing_from_baseline = new_evals
    result.missing_from_run = skipped_evals

    for eval_id in sorted(run_ids & baseline_ids):
        run_entry = run_results[eval_id]
        baseline_entry = baseline.evals[eval_id]
        regs, imps = _compare_eval_metrics(
            eval_id, run_entry, baseline_entry, baseline.tolerances
        )
        result.regressions.extend(regs)
        result.improvements.extend(imps)

    result.table_markdown = _render_table(run_results, baseline, new_evals)
    result.exit_code = 1 if result.regressions else 0
    return result


# ---------------------------------------------------------------------------
# Bulk validation (used by --validate-baselines CLI flag)
# ---------------------------------------------------------------------------

def validate_baselines_dir(baselines_dir: str = "evals/baselines") -> Dict[str, List[str]]:
    """Validate every *.json file in baselines_dir. Returns {filename: errors}."""
    if not os.path.isdir(baselines_dir):
        return {}
    findings: Dict[str, List[str]] = {}
    for name in sorted(os.listdir(baselines_dir)):
        if not name.endswith(".json"):
            continue
        if name == "schema.json":
            continue
        path = os.path.join(baselines_dir, name)
        findings[name] = validate_baseline_file(path)
    return findings


__all__ = [
    "BaselineFile",
    "BaselineFileError",
    "Regression",
    "Improvement",
    "ComparisonResult",
    "baseline_filename",
    "resolve_baseline_path",
    "load_baseline",
    "validate_baseline_file",
    "validate_baselines_dir",
    "write_baseline",
    "compare_run_to_baseline",
]
