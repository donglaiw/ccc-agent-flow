#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ccc-validate.sh <ccc-run-folder>" >&2
  exit 2
fi

python3 - "$1" <<'PY'
import os
import re
import sys
from pathlib import Path

RUN = Path(sys.argv[1])
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
VERDICT_RE = re.compile(r"^VERDICT: (APPROVE|APPROVE_WITH_MINOR_COMMENTS|NEEDS_CHANGES|BLOCKER)$")
STAGE_RE = re.compile(r"^(plan_v(0|[1-9][0-9]*)|plan_v(0|[1-9][0-9]*)_review|code_v(0|[1-9][0-9]*)|review_v(0|[1-9][0-9]*))$")

CONTRACTS = {
    "plan": [
        "Summary",
        "Scope",
        "Proposed Changes",
        "Files and Areas",
        "Verification Plan",
        "Risks and Questions",
        "Changes Since Previous Plan Version",
    ],
    "plan_review": ["Summary", "Findings", "Questions", "Verdict"],
    "code": [
        "Overview",
        "What Changed",
        "Implementation Details",
        "Files Changed",
        "Git Baseline",
        "Verification",
        "Review Focus",
        "Risks and Unknowns",
        "Changes Since Previous Code Version",
    ],
    "review": ["Summary", "Diff Baseline", "Findings", "Tests to Add", "Questions", "Verdict"],
}

STATUS_VALUES = {"active", "waiting", "complete", "blocked", "max-rounds-reached", "canceled"}
TERMINAL_STATUS = {"complete", "blocked", "max-rounds-reached", "canceled"}
VERDICT_VALUES = {"APPROVE", "APPROVE_WITH_MINOR_COMMENTS", "NEEDS_CHANGES", "BLOCKER", "none"}

errors = []


def err(message: str) -> None:
    errors.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        err(f"missing file: {path}")
        return ""


def section(text: str, name: str) -> str:
    pattern = re.compile(rf"^## {re.escape(name)}\n(?P<body>.*?)(?=^## |\Z)", re.M | re.S)
    match = pattern.search(text)
    return match.group("body").strip() if match else ""


def require_sections(path: Path, text: str, names) -> None:
    for name in names:
        if not re.search(rf"^## {re.escape(name)}$", text, re.M):
            err(f"{path}: missing section ## {name}")


def key_values(body: str) -> dict:
    values = {}
    for line in body.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values


def non_empty_section(path: Path, text: str, name: str) -> str:
    body = section(text, name)
    if not body:
        err(f"{path}: section ## {name} is empty")
    return body


def parse_run_md() -> tuple[str, str]:
    run_md = RUN / "run.md"
    text = read(run_md)
    if not text:
        return "", ""

    if text.count("# CCC Run") != 1:
        err("run.md: expected exactly one '# CCC Run' heading")

    require_sections(
        run_md,
        text,
        ["Metadata", "Description", "Roles", "Rounds", "Task Summary", "Git Baseline", "Workflow State", "Status"],
    )

    metadata = key_values(section(text, "Metadata"))
    if metadata.get("protocol_version") != "1":
        err("run.md: Metadata must contain protocol_version: 1")

    rounds = key_values(section(text, "Rounds"))
    for key in ("plan_rounds", "revision_rounds"):
        value = rounds.get(key)
        if not value or not re.fullmatch(r"0|[1-9][0-9]*", value):
            err(f"run.md: Rounds must contain {key}: <non-negative integer without leading zero>")

    baseline = key_values(section(text, "Git Baseline"))
    run_start_ref = baseline.get("run_start_ref", "")
    if not SHA_RE.fullmatch(run_start_ref):
        err("run.md: Git Baseline run_start_ref must be a 40-char lowercase hex SHA")

    if baseline.get("run_start_ref_kind") not in {"head", "empty_tree"}:
        err("run.md: Git Baseline run_start_ref_kind must be head or empty_tree")

    if baseline.get("run_start_ref_kind") == "empty_tree" and run_start_ref != EMPTY_TREE:
        err("run.md: empty_tree baseline must use the Git empty-tree SHA")

    for key in ("run_start_status_file", "run_start_unstaged_diff", "run_start_staged_diff"):
        rel = baseline.get(key)
        if not rel:
            err(f"run.md: Git Baseline missing {key}")
        elif not (RUN / rel).exists():
            err(f"run.md: Git Baseline {key} points to missing file {rel}")

    workflow = key_values(section(text, "Workflow State"))
    current_stage = workflow.get("current_stage")
    if current_stage != "none" and not (current_stage and STAGE_RE.fullmatch(current_stage)):
        err("run.md: Workflow State current_stage must be none or a valid stage")

    expected_role = workflow.get("expected_role")
    if expected_role not in {"a1", "a2", "none"}:
        err("run.md: Workflow State expected_role must be a1, a2, or none")

    latest_verdict = workflow.get("latest_verdict")
    if latest_verdict not in VERDICT_VALUES:
        err("run.md: Workflow State latest_verdict has invalid value")

    latest_artifact = workflow.get("latest_artifact")
    if latest_artifact and latest_artifact != "none" and not (RUN / latest_artifact).exists():
        err(f"run.md: latest_artifact points to missing file {latest_artifact}")

    next_waiting_for = workflow.get("next_waiting_for", "")
    if next_waiting_for.startswith("state/") and not next_waiting_for.endswith(".done"):
        err("run.md: next_waiting_for state path must end in .done")
    elif next_waiting_for not in {"complete", "blocked", "max-rounds-reached", "canceled"} and not next_waiting_for.startswith("state/"):
        err("run.md: next_waiting_for has invalid value")

    status_lines = [line.strip() for line in section(text, "Status").splitlines() if line.strip()]
    if len(status_lines) != 1 or status_lines[0] not in STATUS_VALUES:
        err("run.md: Status must contain exactly one valid status value")
        status = ""
    else:
        status = status_lines[0]

    if expected_role == "none" and status and status not in TERMINAL_STATUS:
        err("run.md: expected_role none is only valid for terminal statuses")

    return run_start_ref, status


def artifact_kind(path: Path):
    name = path.name
    patterns = [
        (r"^plan_v(0|[1-9][0-9]*)\.md$", "plan", "# Plan v{}"),
        (r"^plan_v(0|[1-9][0-9]*)_review\.md$", "plan_review", "# Plan v{} Review"),
        (r"^code_v(0|[1-9][0-9]*)\.md$", "code", "# Code v{}"),
        (r"^review_v(0|[1-9][0-9]*)\.md$", "review", "# Review v{}"),
    ]
    for pattern, kind, heading_template in patterns:
        match = re.fullmatch(pattern, name)
        if match:
            version = match.group(1)
            return kind, int(version), heading_template.format(version)
    return None, None, None


def validate_artifact(path: Path, run_start_ref: str) -> None:
    kind, version, heading = artifact_kind(path)
    if kind is None:
        err(f"{path}: invalid artifact filename")
        return

    text = read(path)
    if not text.strip():
        err(f"{path}: artifact is empty")
        return

    if len(re.findall(rf"^{re.escape(heading)}$", text, re.M)) != 1:
        err(f"{path}: expected exactly one heading '{heading}'")

    require_sections(path, text, CONTRACTS[kind])

    if kind in {"plan_review", "review"}:
        verdicts = [line for line in text.splitlines() if line.startswith("VERDICT:")]
        if len(verdicts) != 1 or not VERDICT_RE.fullmatch(verdicts[0]):
            err(f"{path}: expected exactly one valid whole-line VERDICT")

    if kind == "plan":
        body = non_empty_section(path, text, "Changes Since Previous Plan Version")
        if version == 0 and body.strip() != "Initial plan.":
            err(f"{path}: plan_v0 Changes Since must be exactly 'Initial plan.'")

    if kind == "code":
        body = non_empty_section(path, text, "Changes Since Previous Code Version")
        if version == 0 and body.strip() != "Initial implementation.":
            err(f"{path}: code_v0 Changes Since must be exactly 'Initial implementation.'")
        baseline = key_values(section(text, "Git Baseline"))
        if baseline.get("run_start_ref") != run_start_ref:
            err(f"{path}: Git Baseline run_start_ref must match run.md")
        current_head = baseline.get("current_head")
        if not current_head or (current_head != "none" and not SHA_RE.fullmatch(current_head)):
            err(f"{path}: Git Baseline current_head must be a SHA or none")

    if kind == "review":
        baseline = key_values(section(text, "Diff Baseline"))
        if baseline.get("run_start_ref") != run_start_ref:
            err(f"{path}: Diff Baseline run_start_ref must match run.md")


def validate_done_file(path: Path) -> None:
    text = read(path)
    values = key_values(text)
    stage = values.get("stage")
    artifact = values.get("artifact")
    if not stage:
        err(f"{path}: missing stage")
    elif path.stem != stage:
        err(f"{path}: done filename must match stage")

    if values.get("status") != "complete":
        err(f"{path}: status must be complete")

    if artifact:
        if not (RUN / artifact).exists():
            err(f"{path}: artifact path missing: {artifact}")
    else:
        err(f"{path}: missing artifact")


def main() -> int:
    if not RUN.exists() or not RUN.is_dir():
        err(f"run folder does not exist: {RUN}")
    run_start_ref, _ = parse_run_md()

    artifacts = RUN / "artifacts"
    if not artifacts.is_dir():
        err(f"missing artifacts directory: {artifacts}")
    else:
        for path in sorted(artifacts.glob("*.md")):
            validate_artifact(path, run_start_ref)

    state = RUN / "state"
    if not state.is_dir():
        err(f"missing state directory: {state}")
    else:
        for path in sorted(state.glob("*.done")):
            validate_done_file(path)

    if errors:
        for message in errors:
            print(f"ccc-validate: {message}", file=sys.stderr)
        return 1

    print(f"CCC run valid: {RUN}")
    return 0


sys.exit(main())
PY
