"""Eval results viewer — generates self-contained HTML for reviewing eval results."""

import base64
import glob
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any, Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

RESULTS_GLOB_PATTERN = os.path.join("evals", "*", "trial-*", "grading.json")
BENCHMARK_ABSENT_MESSAGE = "Run aggregation first"
DEFAULT_PORT = 3117
PORT_RETRY_LIMIT = 10
TEXT_EXTENSIONS = {
    ".txt", ".md", ".json", ".yaml", ".yml", ".toml", ".ini", ".cfg",
    ".py", ".js", ".ts", ".sh", ".html", ".css", ".xml", ".log", ".csv",
}


# ---------------------------------------------------------------------------
# File embedding helpers
# ---------------------------------------------------------------------------

def _is_text_file(path: str) -> bool:
    """Return True when the file extension is a known text type."""
    _, ext = os.path.splitext(path)
    return ext.lower() in TEXT_EXTENSIONS


def _embed_file(path: str) -> dict[str, Any]:
    """Read a file and return an embedding dict with name, type, and content.

    Text files are embedded as strings. Binary files are base64-encoded.
    Returns an error dict when the file cannot be read.
    """
    filename = os.path.basename(path)
    if _is_text_file(path):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read()
            return {"name": filename, "type": "text", "content": content}
        except OSError as exc:
            return {"name": filename, "type": "error", "content": str(exc)}
    else:
        try:
            with open(path, "rb") as fh:
                raw = fh.read()
            encoded = base64.b64encode(raw).decode("ascii")
            return {"name": filename, "type": "base64", "content": encoded}
        except OSError as exc:
            return {"name": filename, "type": "error", "content": str(exc)}


# ---------------------------------------------------------------------------
# Results data collection
# ---------------------------------------------------------------------------

def _collect_eval_results(results_dir: str) -> list[dict[str, Any]]:
    """Scan results_dir for grading.json files and build per-eval result list.

    Layout scanned: {results_dir}/evals/{eval-id}/trial-{n}/grading.json
    Returns a list of eval dicts, each with eval_id, trials, and snapshot_files.
    """
    pattern = os.path.join(results_dir, RESULTS_GLOB_PATTERN)
    grading_files = sorted(glob.glob(pattern))

    by_eval: dict[str, list[dict[str, Any]]] = {}

    for grading_path in grading_files:
        try:
            with open(grading_path) as fh:
                grading = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            grading = {"error": str(exc), "expectations": [], "summary": {}}

        eval_id = _extract_eval_id(grading_path)
        trial_num = _extract_trial_num(grading_path)
        trial_dir = os.path.dirname(grading_path)
        snapshot_files = _collect_snapshot_files(trial_dir)

        trial_entry = {
            "trial": trial_num,
            "grading": grading,
            "snapshot_files": snapshot_files,
        }
        by_eval.setdefault(eval_id, []).append(trial_entry)

    return [
        {"eval_id": eval_id, "trials": trials}
        for eval_id, trials in by_eval.items()
    ]


def _collect_snapshot_files(trial_dir: str) -> list[dict[str, Any]]:
    """Collect and embed all non-grading files from a trial directory."""
    embedded = []
    try:
        entries = sorted(os.listdir(trial_dir))
    except OSError:
        return embedded

    for entry in entries:
        if entry == "grading.json":
            continue
        full_path = os.path.join(trial_dir, entry)
        if os.path.isfile(full_path):
            embedded.append(_embed_file(full_path))

    return embedded


def _extract_eval_id(grading_path: str) -> str:
    """Extract eval ID from path like .../evals/{eval-id}/trial-{n}/grading.json."""
    parts = grading_path.replace("\\", "/").split("/")
    evals_index = next((i for i, p in enumerate(parts) if p == "evals"), None)
    if evals_index is not None and evals_index + 1 < len(parts):
        return parts[evals_index + 1]
    return "unknown"


def _extract_trial_num(grading_path: str) -> int:
    """Extract trial number from path like .../trial-{n}/grading.json."""
    parts = grading_path.replace("\\", "/").split("/")
    for part in parts:
        if part.startswith("trial-"):
            try:
                return int(part.split("-", 1)[1])
            except ValueError:
                pass
    return 0


# ---------------------------------------------------------------------------
# Benchmark data loading
# ---------------------------------------------------------------------------

def _load_benchmark(benchmark_path: str) -> Optional[dict[str, Any]]:
    """Load benchmark.json from benchmark_path.

    Returns the parsed dict, or None if the file is absent or unreadable.
    """
    if not os.path.isfile(benchmark_path):
        return None
    try:
        with open(benchmark_path) as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None


# ---------------------------------------------------------------------------
# HTML generation
# ---------------------------------------------------------------------------

_HTML_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Eval Results</title>
<style>
{css}
</style>
</head>
<body>
<h1>Eval Results</h1>
<div class="tabs">
  <button class="tab-btn active" onclick="showTab('results')">Results</button>
  <button class="tab-btn" onclick="showTab('benchmark')">Benchmark</button>
</div>
<div id="tab-results" class="tab-content active"></div>
<div id="tab-benchmark" class="tab-content"></div>
<script>
const DATA = {data_json};
</script>
<script>
{js}
</script>
</body>
</html>
"""

_CSS = """\
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, sans-serif; padding: 1rem 2rem; color: #222; }
h1 { margin-bottom: 1rem; font-size: 1.5rem; }
h2 { font-size: 1.2rem; margin: 1rem 0 0.5rem; }
h3 { font-size: 1rem; margin: 0.75rem 0 0.25rem; color: #444; }

.tabs { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.tab-btn {
  padding: 0.4rem 1rem; border: 1px solid #ccc; background: #f5f5f5;
  cursor: pointer; border-radius: 4px; font-size: 0.9rem;
}
.tab-btn.active { background: #333; color: #fff; border-color: #333; }
.tab-content { display: none; }
.tab-content.active { display: block; }

.eval-block { border: 1px solid #ddd; border-radius: 6px; margin-bottom: 1rem; overflow: hidden; }
.eval-header {
  padding: 0.5rem 0.75rem; background: #f0f0f0;
  display: flex; justify-content: space-between; align-items: center;
}
.eval-body { padding: 0.75rem; }

.trial-block { border: 1px solid #e8e8e8; border-radius: 4px; margin-bottom: 0.75rem; }
.trial-header { padding: 0.35rem 0.6rem; background: #fafafa; font-weight: 600; font-size: 0.9rem; }
.trial-body { padding: 0.6rem; }

table { width: 100%; border-collapse: collapse; font-size: 0.85rem; margin-top: 0.5rem; }
th { text-align: left; padding: 0.3rem 0.5rem; background: #f5f5f5; border-bottom: 2px solid #ddd; }
td { padding: 0.3rem 0.5rem; border-bottom: 1px solid #eee; vertical-align: top; }
tr:last-child td { border-bottom: none; }

.pass { color: #2a7a2a; font-weight: 600; }
.fail { color: #c0392b; font-weight: 600; }
.skip { color: #888; font-style: italic; }

.badge {
  display: inline-block; padding: 0.15rem 0.5rem; border-radius: 3px;
  font-size: 0.8rem; font-weight: 600;
}
.badge-pass { background: #d4edda; color: #155724; }
.badge-fail { background: #f8d7da; color: #721c24; }

.evidence { font-family: monospace; font-size: 0.78rem; color: #555; white-space: pre-wrap; word-break: break-all; }

.snapshot-files { margin-top: 0.6rem; }
.snapshot-file { margin-bottom: 0.5rem; }
.file-name { font-weight: 600; font-size: 0.85rem; color: #333; }
.file-content {
  background: #f8f8f8; border: 1px solid #e0e0e0; border-radius: 3px;
  padding: 0.5rem; font-family: monospace; font-size: 0.78rem;
  white-space: pre-wrap; word-break: break-all; max-height: 300px; overflow-y: auto;
  margin-top: 0.2rem;
}

.stats-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 0.75rem; }
.stat-card { border: 1px solid #ddd; border-radius: 6px; padding: 0.75rem; }
.stat-card h3 { margin-bottom: 0.4rem; }
.stat-row { display: flex; justify-content: space-between; font-size: 0.85rem; padding: 0.15rem 0; }
.stat-label { color: #666; }
.stat-value { font-weight: 600; }

.flaky-list { margin: 0.5rem 0; }
.flaky-item { background: #fff3cd; border: 1px solid #ffc107; border-radius: 3px; padding: 0.3rem 0.6rem; margin-bottom: 0.3rem; font-size: 0.85rem; }

.analysis-list { margin: 0.5rem 0; }
.analysis-item { background: #e8f4fd; border-left: 3px solid #3498db; padding: 0.4rem 0.75rem; margin-bottom: 0.4rem; font-size: 0.875rem; }

.placeholder { color: #888; font-style: italic; padding: 1rem 0; }
"""

_JS = """\
function showTab(name) {
  document.querySelectorAll('.tab-content').forEach(function(el) {
    el.classList.remove('active');
  });
  document.querySelectorAll('.tab-btn').forEach(function(btn) {
    btn.classList.remove('active');
  });
  document.getElementById('tab-' + name).classList.add('active');
  var btns = document.querySelectorAll('.tab-btn');
  btns.forEach(function(btn) {
    if (btn.getAttribute('onclick') === "showTab('" + name + "')") {
      btn.classList.add('active');
    }
  });
}

function passLabel(passed) {
  if (passed === null || passed === undefined) return '<span class="skip">skipped</span>';
  return passed
    ? '<span class="pass">PASS</span>'
    : '<span class="fail">FAIL</span>';
}

function badgeFor(passed) {
  if (passed === null || passed === undefined) return '<span class="badge">skipped</span>';
  return passed
    ? '<span class="badge badge-pass">PASS</span>'
    : '<span class="badge badge-fail">FAIL</span>';
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderExpectationsTable(expectations) {
  if (!expectations || expectations.length === 0) {
    return '<p class="placeholder">No expectations recorded.</p>';
  }
  var rows = expectations.map(function(exp) {
    return '<tr>'
      + '<td>' + passLabel(exp.passed) + '</td>'
      + '<td>' + escHtml(exp.description || exp.type || '') + '</td>'
      + '<td class="evidence">' + escHtml(exp.evidence || '') + '</td>'
      + '</tr>';
  });
  return '<table>'
    + '<thead><tr><th>Result</th><th>Description</th><th>Evidence</th></tr></thead>'
    + '<tbody>' + rows.join('') + '</tbody>'
    + '</table>';
}

function renderSnapshotFiles(files) {
  if (!files || files.length === 0) return '';
  var html = '<div class="snapshot-files"><h3>Snapshot files</h3>';
  files.forEach(function(f) {
    html += '<div class="snapshot-file">';
    html += '<div class="file-name">' + escHtml(f.name) + '</div>';
    if (f.type === 'text') {
      html += '<div class="file-content">' + escHtml(f.content) + '</div>';
    } else if (f.type === 'base64') {
      html += '<div class="file-content">[binary file, base64-encoded, ' + f.content.length + ' chars]</div>';
    } else {
      html += '<div class="file-content">' + escHtml(f.content) + '</div>';
    }
    html += '</div>';
  });
  html += '</div>';
  return html;
}

function renderResultsTab() {
  var container = document.getElementById('tab-results');
  var evals = DATA.evals;
  if (!evals || evals.length === 0) {
    container.innerHTML = '<p class="placeholder">No eval results found.</p>';
    return;
  }
  var html = '';
  evals.forEach(function(ev) {
    var allPassed = ev.trials.every(function(t) {
      var s = t.grading.summary || {};
      return s.failed === 0 && (s.total || 0) > 0;
    });
    var badge = badgeFor(allPassed);
    html += '<div class="eval-block">';
    html += '<div class="eval-header"><span><strong>' + escHtml(ev.eval_id) + '</strong></span>' + badge + '</div>';
    html += '<div class="eval-body">';
    ev.trials.forEach(function(trial) {
      var s = trial.grading.summary || {};
      var trialPassed = s.failed === 0 && (s.total || 0) > 0;
      html += '<div class="trial-block">';
      html += '<div class="trial-header">Trial ' + escHtml(String(trial.trial))
        + ' &mdash; ' + (s.passed || 0) + '/' + (s.total || 0) + ' passed '
        + badgeFor(trialPassed) + '</div>';
      html += '<div class="trial-body">';
      html += renderExpectationsTable(trial.grading.expectations);
      html += renderSnapshotFiles(trial.snapshot_files);
      html += '</div></div>';
    });
    html += '</div></div>';
  });
  container.innerHTML = html;
}

function renderBenchmarkTab() {
  var container = document.getElementById('tab-benchmark');
  var bm = DATA.benchmark;
  if (!bm) {
    container.innerHTML = '<p class="placeholder">' + escHtml(DATA.benchmark_absent_message) + '</p>';
    return;
  }
  var html = '';

  var summary = bm.run_summary || {};
  if (Object.keys(summary).length > 0) {
    html += '<h2>Run Summary</h2>';
    html += '<div class="stats-grid">';
    Object.keys(summary).forEach(function(evalId) {
      var st = summary[evalId];
      var pr = st.pass_rate || {};
      var passK = bm.pass_at_k ? bm.pass_at_k[evalId] : undefined;
      var powerK = bm.pass_power_k ? bm.pass_power_k[evalId] : undefined;
      var isFlaky = bm.flaky && bm.flaky.indexOf(evalId) !== -1;
      html += '<div class="stat-card">';
      html += '<h3>' + escHtml(evalId) + (isFlaky ? ' <span class="badge badge-fail">flaky</span>' : '') + '</h3>';
      html += '<div class="stat-row"><span class="stat-label">Pass rate (mean)</span><span class="stat-value">' + (typeof pr.mean === 'number' ? (pr.mean * 100).toFixed(1) + '%' : '—') + '</span></div>';
      html += '<div class="stat-row"><span class="stat-label">Pass rate (stddev)</span><span class="stat-value">' + (typeof pr.stddev === 'number' ? pr.stddev.toFixed(4) : '—') + '</span></div>';
      html += '<div class="stat-row"><span class="stat-label">Trials</span><span class="stat-value">' + (st.trial_count || '—') + '</span></div>';
      if (passK !== undefined) {
        html += '<div class="stat-row"><span class="stat-label">pass@k</span><span class="stat-value">' + passK.toFixed(4) + '</span></div>';
      }
      if (powerK !== undefined) {
        html += '<div class="stat-row"><span class="stat-label">pass^k</span><span class="stat-value">' + powerK.toFixed(4) + '</span></div>';
      }
      html += '</div>';
    });
    html += '</div>';
  }

  var flaky = bm.flaky || [];
  if (flaky.length > 0) {
    html += '<h2>Flaky Evals</h2><div class="flaky-list">';
    flaky.forEach(function(f) {
      html += '<div class="flaky-item">' + escHtml(f) + '</div>';
    });
    html += '</div>';
  }

  var notes = bm.notes || [];
  if (notes.length > 0) {
    html += '<h2>Analysis</h2><div class="analysis-list">';
    notes.forEach(function(note) {
      html += '<div class="analysis-item">' + escHtml(String(note)) + '</div>';
    });
    html += '</div>';
  }

  if (html === '') {
    html = '<p class="placeholder">No benchmark data available.</p>';
  }
  container.innerHTML = html;
}

renderResultsTab();
renderBenchmarkTab();
"""


def generate_html(
    results_dir: str, benchmark_path: Optional[str] = None
) -> str:
    """Generate a self-contained HTML string for reviewing eval results.

    Scans results_dir for grading.json files. Embeds all data as a JavaScript
    object. No external network requests are made.

    Args:
        results_dir: Directory containing evals/{eval-id}/trial-{n}/grading.json
        benchmark_path: Optional path to benchmark.json from aggregation.

    Returns:
        A self-contained HTML string.
    """
    eval_results = _collect_eval_results(results_dir)

    benchmark_data: Optional[dict[str, Any]] = None
    if benchmark_path is not None:
        benchmark_data = _load_benchmark(benchmark_path)

    data = {
        "evals": eval_results,
        "benchmark": benchmark_data,
        "benchmark_absent_message": BENCHMARK_ABSENT_MESSAGE,
    }

    data_json = json.dumps(data, ensure_ascii=False, indent=None)

    return _HTML_TEMPLATE.format(
        css=_CSS,
        js=_JS,
        data_json=data_json,
    )


# ---------------------------------------------------------------------------
# HTTP server
# ---------------------------------------------------------------------------

def _find_available_port(start_port: int, retry_limit: int) -> int:
    """Return the first available port in [start_port, start_port + retry_limit].

    Raises OSError when no port in the range is available.
    """
    for offset in range(retry_limit + 1):
        port = start_port + offset
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            try:
                sock.bind(("localhost", port))
                return port
            except OSError:
                continue
    raise OSError(
        f"No available port found in range {start_port}–{start_port + retry_limit}"
    )


def serve(results_dir: str, port: int = DEFAULT_PORT) -> None:
    """Start an HTTP server on localhost that serves the eval results viewer.

    On each GET request, regenerates the HTML from the current results_dir.
    If the requested port is in use, tries port+1 through port+PORT_RETRY_LIMIT.

    Args:
        results_dir: Directory containing eval results.
        port: Starting port to attempt binding on.

    Raises:
        OSError: When no port in the retry range is available.
    """
    bound_port = _find_available_port(port, PORT_RETRY_LIMIT)

    class ReviewHandler(BaseHTTPRequestHandler):
        """Serves the self-contained HTML viewer, regenerated per request."""

        def do_GET(self) -> None:
            html = generate_html(results_dir)
            body = html.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: Any) -> None:
            pass  # suppress default access log output

    server = HTTPServer(("localhost", bound_port), ReviewHandler)
    print(f"Eval viewer running at http://localhost:{bound_port}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
