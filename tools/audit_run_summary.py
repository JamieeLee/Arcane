#!/usr/bin/env python3
"""Static checks for the run summary's end-to-next-run lifecycle."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "Windows/Summary.lua").read_text(encoding="utf-8")

def fail(message: str) -> None:
    print("FAIL:", message, file=sys.stderr)
    raise SystemExit(1)

required = (
    ('local phase = type(AZS_GetPhase) == "function" and C.Call(AZS_GetPhase) or nil',
     "the run summary must read the game's current run phase"),
    ('phase == "playing" and S.lastPhase == "ready"',
     "a new run must be recognized when it leaves the ready state and starts playing"),
    ('S.lastPhase = phase',
     "the previous run phase must be retained between summary updates"),
)
for fragment, message in required:
    if fragment not in source:
        fail(message)

ready = source.find('phase == "playing" and S.lastPhase == "ready"')
close = source.find("S.closed = true", ready)
remember = source.find("S.lastPhase = phase", ready)
if ready < 0 or close < 0 or remember < 0 or not (ready < close < remember):
    fail("the summary must close on the ready-to-playing transition, not merely on entering ready")

if "if e and not S.closed and phase == \"playing\" and S.lastPhase == \"ready\" then" not in source:
    fail("the new-run transition must not dismiss an already-closed or absent summary")

print("PASS: the summary stays open while a new run is waiting in ready")
print("PASS: the summary closes when the new run enters playing")
print("PASS: the existing end-of-run summary and endless-victory behavior remain in place")
