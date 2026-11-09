#!/usr/bin/env python3
"""Static regression checks for repeated run-summary lifecycles."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "Windows/Summary.lua").read_text(encoding="utf-8")

def fail(message: str) -> None:
    print("FAIL:", message, file=sys.stderr)
    raise SystemExit(1)

required = (
    ('runActive = false', "the summary must track whether a new run is active"),
    ('phase == "playing" and S.lastPhase == "ready"', "the new run must be detected when it starts"),
    ('S.runActive = true', "starting a new run must arm the next summary"),
    ('phase == nil or phase == "dead" or phase == "victory"', "the active run must wait for its own ending"),
    ('S.runActive = false', "the new end summary must finish the active-run wait"),
    ('S.endT = tonumber(e.t)', "the new summary's ending time must be stored"),
    ('local want = (S.stamp and not S.closed) and 1 or 0', "the displayed snapshot must remain visible independently of the live getter"),
)
for fragment, message in required:
    if fragment not in source:
        fail(message)

start = source.find('if phase == "playing" and S.lastPhase == "ready" then')
arm = source.find("S.runActive = true", start)
end_wait = source.find("if S.runActive then", arm)
show_new = source.find("Show(e, now)", end_wait)
stamp_only = source.find("elseif e and stamp ~= S.stamp then", end_wait)
if min(start, arm, end_wait, show_new, stamp_only) < 0 or not (start < arm < end_wait < show_new < stamp_only):
    fail("a new run must re-arm summary display before the result-label fallback")

if '(e and not S.closed)' in source:
    fail("the summary's visibility must not depend on a possibly stale or cleared getter result")

print("PASS: starting a new run dismisses the previous summary")
print("PASS: the next run's own end reopens the summary even with the same result label")
print("PASS: the stored summary remains visible after the live API clears its data")
print("PASS: the initial out-of-run summary fallback remains available")
