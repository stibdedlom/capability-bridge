#!/usr/bin/env bash
set -euo pipefail

# Worker + Reviewer visible session pair prototype demo.
# This is a textual simulation of the Phase 2 Capability Bridge flow.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/prototypes/worker-reviewer/fixtures"

echo "=== Capability Bridge: Worker + Reviewer Session Pair Demo ==="
echo "Target repo: $REPO_ROOT"
echo ""

# 1. User creates a TaskFrame in COG via text.
echo "[COG] User creates TaskFrame: 'Add a validation test for the trace event schema.'"
cat "$FIXTURES/task-frame.json"
echo ""

# 2. Bridge asks SDL for routing.
echo "[Bridge] Asking SDL for routing..."
echo "[SDL] Selected Worker=tech/code-generation, Reviewer=meta/review-packet (confidence=0.85)"
echo ""

# 3. Bridge spawns two visible sessions.
echo "[Bridge] Spawning Worker session on pane 1..."
echo "[Bridge] Spawning Reviewer session on pane 2..."
echo ""

# 4. Worker bounded loop: plan -> execute -> verify -> checkpoint.
echo "[Worker] plan: read spec/trace-event.schema.json, design test, write test."
echo "[Worker] execute: create Tests/CapabilityBridgeTests/TraceEventSchemaTests.swift"
echo "[Worker] verify: run swift test"
echo "[Worker] checkpoint: reached unapproved file mutation boundary"
echo ""

# 5. Reviewer critiques and emits ApprovalRequest.
echo "[Reviewer] Detected file mutation; emitting ApprovalRequest."
cat "$FIXTURES/approval-request.json"
echo ""

# 6. Bridge sends ApprovalRequest to mobile surface.
echo "[Bridge] Sending ApprovalRequest to Mac notification / iPhone / Watch..."
echo "[Mobile] Present options: approve / reject / redirect / stop"
echo ""

# 7. User approves; bridge updates state and emits TraceEvent.
echo "[Mobile] User selected: approve"
echo "[Bridge] Worker state -> running; emitting TraceEvent."
cat "$FIXTURES/trace-event.json"
echo ""

# 8. Worker completes and Reviewer signs off.
echo "[Worker] complete: test added and passing."
echo "[Reviewer] signs off: no further risks."
echo ""

echo "=== Demo complete ==="
echo "This was a simulation. Real pane spawning and mobile delivery require #1, #2, #9."
