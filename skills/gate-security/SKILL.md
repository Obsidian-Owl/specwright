---
name: gate-security
description: >-
  Three-phase security review: automated pattern detection (block),
  architectural security review (warn), and sensitive domain review (info).
argument-hint: "[epic-id]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Specwright Gate: Security Review

Three-phase security review. Phase 1 (pattern detection) can block. Phase 2 (architectural) warns. Phase 3 (business logic) is informational.

## Step 1: Read Configuration and State

Read `.specwright/config.json` for:
- `gates.security.sensitiveFiles` — file patterns to protect
- `gates.security.secretPatterns` — patterns that indicate leaked secrets
- `gates.security.sastTool` — optional SAST tool command (if configured)
- `gates.security.vulnScanner` — optional vulnerability scanner command

Read `.specwright/state/workflow.json` for epic context.
If no epic active, STOP.

Create evidence directory:
```bash
mkdir -p {specDir}/evidence/
```

Determine scope:
```bash
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10
```

## Step 2: Phase 1 — Automated Detection (BLOCK severity)

Any Phase 1 finding sets gate status to FAIL.

### 2a: Secret Detection
Search changed files for patterns indicating leaked secrets:
- Use patterns from `config.json` `gates.security.secretPatterns`
- Default patterns: `API_KEY`, `SECRET`, `PASSWORD`, `TOKEN`, `PRIVATE_KEY`, `aws_access_key`, `ssh-rsa`
- Also search for: hardcoded connection strings, base64-encoded credentials, private keys

```
Grep pattern="{each secret pattern}" in changed files
```

Exclusions (do NOT flag):
- Test files with obvious dummy values
- Example/sample configuration files
- Environment variable references (reading from env is safe)

Each genuine secret leak = BLOCK.

### 2b: SQL Injection Patterns
Search for string concatenation in SQL contexts:
- Raw SQL with variable interpolation
- String concatenation in query building
- Use Grep to find patterns like string concat near SQL keywords (SELECT, INSERT, UPDATE, DELETE)

Exclusions:
- Parameterized queries (using placeholders like `$1`, `?`, `:param`)
- ORM query builders
- Constant string concatenation

Each genuine SQL injection pattern = BLOCK.

### 2c: Command Injection
Search for shell command construction with user input:
- `exec()`, `system()`, `spawn()`, `popen()` with variable arguments
- Template strings or concatenation in command construction

Each genuine command injection = BLOCK.

### 2d: Sensitive Data in Logs
Search for logging statements that might expose sensitive data:
- Log calls containing variable names like `password`, `token`, `secret`, `ssn`, `creditCard`
- Use Grep + LLM analysis to determine if actual sensitive data is logged

Each genuine PII/secret logging = BLOCK.

### 2e: SAST Tool (Optional)
If `gates.security.sastTool` is configured:
- Run the configured SAST tool
- Parse output for findings
- HIGH/CRITICAL = BLOCK, MEDIUM = WARN, LOW = INFO

If no SAST tool configured, note as INFO: "No SAST tool configured. Consider adding one for deeper analysis."

### 2f: Vulnerability Scanner (Optional)
If `gates.security.vulnScanner` is configured:
- Run the scanner
- Parse output for known vulnerabilities
- CRITICAL/HIGH CVEs = BLOCK, MEDIUM = WARN, LOW = INFO

If unavailable, note as INFO.

## Step 3: Phase 2 — Architectural Review (WARN severity)

Phase 2 findings do NOT block the gate.

### 3a: Authentication Coverage
Search for route/endpoint definitions in changed files:
- Check if authentication/authorization middleware is applied
- Public endpoints should be explicitly marked
- Endpoints in sensitive areas without auth = WARN

### 3b: Input Validation
Search for request handling code in changed files:
- Check for input validation before processing
- Request handlers without validation = WARN

### 3c: Error Information Leakage
Search for error handling in API/response code:
- Raw error messages returned to clients = WARN
- Stack traces in responses = WARN
- Internal details in error responses = WARN

### 3d: HTTPS/TLS
If configuration files are changed:
- Check for insecure protocol usage (http:// in production configs) = WARN
- Disabled TLS verification = WARN

### 3e: Dependency Security
If package manifest files changed (package.json, go.mod, Cargo.toml, requirements.txt):
- Note new dependencies as INFO
- Known insecure version ranges = WARN

## Step 4: Phase 3 — Sensitive Domain Review (INFO only)

Only run if changes touch files matching sensitive patterns from config.

### 4a: Authorization Context
Check that data access verifies requesting user owns the data.
- Data queries without user context filtering = INFO recommendation

### 4b: Audit Logging
Check that sensitive operations have audit logging.
- Create/update/delete operations without audit trail = INFO recommendation

### 4c: Data Encryption
Check that sensitive data at rest uses encryption.
- Plaintext storage of sensitive fields = INFO recommendation

## Step 5: Update Gate Status

Determine final status:
- Any Phase 1 BLOCK = FAIL
- Only WARN and INFO = PASS

Update `.specwright/state/workflow.json` `gates.security`:
```json
{"status": "PASS|FAIL", "lastRun": "<ISO>", "evidence": "{specDir}/evidence/security-report.md"}
```

## Step 6: Save Evidence

Write `{specDir}/evidence/security-report.md`:
```markdown
# Security Gate Report
Epic: {epicId}
Date: {timestamp}
Status: {PASS|FAIL}

## Phase 1: Automated Detection (BLOCK)
| Check | Result | Findings |
|-------|--------|----------|
| Secrets | PASS/FAIL | N patterns found |
| SQL Injection | PASS/FAIL | N patterns found |
| Command Injection | PASS/FAIL | N patterns found |
| Sensitive Logging | PASS/FAIL | N patterns found |
| SAST Tool | PASS/FAIL/SKIP | {results} |
| Vulnerability Scan | PASS/FAIL/SKIP | {results} |

## Phase 2: Architectural Review (WARN)
| Check | Result | Details |
|-------|--------|---------|
| Auth Coverage | PASS/WARN | {details} |
| Input Validation | PASS/WARN | {details} |
| Error Leakage | PASS/WARN | {details} |
| HTTPS/TLS | PASS/WARN | {details} |
| Dependencies | PASS/WARN | {details} |

## Phase 3: Sensitive Domain (INFO)
{recommendations or "Skipped — no sensitive domain changes"}

## Summary
BLOCK: {count}
WARN: {count}
INFO: {count}
```

## Step 7: Output Result
```
SECURITY GATE: {PASS|FAIL}
Phase 1 (Detection): {count} BLOCK findings
Phase 2 (Architecture): {count} warnings
Phase 3 (Business Logic): {count} recommendations
Evidence: {specDir}/evidence/security-report.md
```
