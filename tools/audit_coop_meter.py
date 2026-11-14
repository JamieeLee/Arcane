#!/usr/bin/env python3
"""Party meter regression checks: source ownership, identity, lifecycle and Reset."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "Windows/Meter.lua").read_text(encoding="utf-8")


def fail(message):
    raise SystemExit("FAIL: " + message)


def section(start, end):
    a = source.find(start)
    if a < 0:
        fail("missing " + start)
    b = source.find(end, a + len(start))
    if b < 0:
        fail("missing end marker after " + start)
    return source[a:b].strip() + "\n"


# Guardrails against a second renderer or broken lifecycle integration.
for fragment in (
    'e.key, e.amount, e.ownerId = "o" .. tostring(row.ownerId)',
    'S.partyOwners, S.partyPortraits = owners, portraits',
    'if not owners[e.name] or owners[e.name] == false then e.ownerId = nil end',
    'query.scope, query.ownerId = "owner", f.ownerId',
    'FromSnapshot(snap, "player")',
    'if tab == "damage" then',
    'if tab == "party" and S.partyBaseOnly then',
    'if checkpointMade then',
    'if S.focus then LeavePlayer(); return end',
    'if button ~= "LeftButton" or drag.moving',
    'SetPartyRun(nil) -- expire focus',
    'if not db or db.tab ~= "party" or S.focus then return end',
    'S.partyAt = tonumber(AZS_PARTY_UPDATED) or 0',
):
    if fragment not in source:
        fail("required meter contract missing: " + fragment)

for path in ("Locales/Locale_ja.lua", "Locales/Locale_ko.lua", "Locales/Locale_pl.lua",
             "Locales/Locale_ru.lua", "Locales/Locale_tr.lua", "Locales/Locale_zh.lua"):
    if '["Click for their skills."]' not in (ROOT / path).read_text(encoding="utf-8"):
        fail("missing translation " + path)
if '{ "Click for their skills.",' not in (ROOT / "Locales/Locale.lua").read_text(encoding="utf-8"):
    fail("missing core translation")

lua = shutil.which("lua5.1")
if not lua:
    fail("Lua 5.1 interpreter needed for behavior tests")

setup = r'''
C = { Vis = function() end, NoteSources = function() end }
db = { tab = "party" }
S = { list = {}, partyRun = "r1", partyAt = 10, partyOwners = {}, partyPortraits = {},
      readClock = 0, n = 0, usedLines = false, partyBaseOnly = false }
CLASS_COLORS = { MAGE = {0.1,0.7,1} }
HARD_ERRORS = { INVALID_ARGUMENT = true }
EMPTY_BY_CODE = { NO_PARTY = "No party" }
QUERIES = { party = { metric = "damage", scope = "party", period = "run",
                     groupBy = "owner", windowSeconds = 0 } }
byKey = {}
function GetTime() return 30 end
function Call(f, args)
  if type(f) == "function" then return f(args) end
end
function RateValue(t) return type(t) == "table" and t.value or nil end
function Line(n)
  local e = S.list[n] or {}
  S.list[n] = e
  return e
end
function ClearRows() S.n = 0; S.list = {}; S.cleared = (S.cleared or 0) + 1 end
function LeavePlayer() S.focus = nil; ClearRows() end
function SetPartyRun(id) S.partyRun = id; S.partyOwners = {}; S.partyAt = nil; ClearRows() end
function FromSnapshot(snap, tab) S.fromTab = tab end
function BestSkills() end
function FillPartyBestSkills() end
function SortLines() end
function ReadLines() S.nativeCalls = (S.nativeCalls or 0) + 1; return true end
AZS_PARTY = { { name = "Mage", dmg = 90, top = "Fireball" } }
AZS_PARTY_UPDATED = 10
'''

behavior = r'''
local function check(ok, message)
  if not ok then error(message) end
end

-- The native update stamp is in its own domain, not wall-clock time.
check(GameParty() == nil, "old party update must not override ledger")
AZS_PARTY_UPDATED = 11
check(GameParty() and GameParty().Mage.name == "Mage", "fresh party update missing")

-- Owner IDs remain the canonical key. The name cache must be per snapshot.
local row = { rows = {{ownerId="a",displayAmount=100}}, actors={a={name="Mage",classKey="MAGE"}} }
check(OwnerLines(row) == 1, "ledger owner line missing")
check(S.list[1].key == "oa" and S.partyOwners.Mage == "a", "owner ID changed")
local changed = { rows={{ownerId="b",displayAmount=80}}, actors={b={name="Rogue"}} }
OwnerLines(changed)
check(S.partyOwners.Mage == nil and S.partyOwners.Rogue == "b", "departed owner cached")
local ambiguous = { rows={{ownerId="a",displayAmount=80},{ownerId="b",displayAmount=60}},
                   actors={a={name="Mage"},b={name="Mage"}} }
OwnerLines(ambiguous)
check(S.partyOwners.Mage == false, "duplicate names must not resolve to an owner")
check(S.list[1].ownerId == nil and S.list[2].ownerId == nil, "duplicate name remains clickable")

-- A co-op ledger that is temporarily NOT_READY may use only newer party lines.
S.partyRun, S.partyAt, S.checkpoint, S.partyBaseOnly = "r1", 10, nil, false
AZS_GetMeterContext = function() return {runId="r1",localOwnerId="self"} end
AZS_GetMeterSnapshot = function() return nil, {code="NOT_READY"} end
check(ReadSnapshot("party") == "game", "fresh party fallback blocked")
S.checkpoint, S.checkpointRun = "cp1", "r1"
check(ReadSnapshot("party") == true, "checkpoint must disable whole-run fallback")
S.checkpoint, S.checkpointRun = nil, nil
S.partyAt = 11
check(ReadSnapshot("party") == true, "stale party feed should not override ledger")

-- Focusing an owner must never query other owners, nor rewrite the pet bar.
S.focus = {ownerId="a",name="Mage",runId="r1"}
S.checkpoint = nil
local requested
AZS_GetMeterSnapshot = function(q) requested=q; return {rows={},totals={}} end
ReadPlayer()
check(requested and requested.scope=="owner" and requested.ownerId=="a", "owner drilldown scope wrong")
check(requested.groupBy=="actor_source" and S.fromTab=="player", "detail did not reuse skill reader")
S.focus = {ownerId="self",name="Me",runId="r1"}
ReadPlayer()
check(requested.scope=="self" and requested.ownerId==nil, "self detail must use self scope")
S.focus = {ownerId="a",name="Mage",runId="old-run"}
ReadPlayer()
check(S.focus==nil, "old-run focus must close")

-- Reset during native fallback should create a ledger checkpoint if available,
-- clear whole-run rows, and not retain stale visible totals.
S.focus=nil; S.usedLines=true; S.partyRun="r1"; S.partyBaseOnly=false
S.list={{key="oa",amount=100}}; S.n=1; S.cleared=0
AZS_CreateMeterCheckpoint=function() return {checkpointId="cp1"} end
Reset()
check(S.checkpoint=="cp1" and S.cleared==1 and S.base==nil, "fallback Reset checkpoint broken")

-- If no checkpoint is available, keep the native baseline and do not mix it
-- with the ledger's whole-run totals.
S.checkpoint=nil; S.list={{key="oa",amount=100}}; S.n=1
S.usedLines=true; S.partyRun="r1"; S.partyBaseOnly=false
AZS_CreateMeterCheckpoint=function() return nil end
Reset()
check(S.partyBaseOnly==true and S.base.oa==100, "missing checkpoint lost native baseline")
local before=S.nativeCalls or 0
Read()
check((S.nativeCalls or 0)>before, "native baseline no longer read")

print("PASS: run-scoped identity, native freshness, owner skill queries and Reset lifecycle")
'''

chunks = [
    section("local function GameParty()", "------------------------------------------------------------------------ reading: the meter API"),
    section("local function OwnerLines(snap)", "local function BestSkills(snap)"),
    section("local function ReadPlayer()", "-- true when it read the API"),
    section("local function ReadSnapshot(tab)", "------------------------------------------------------------------------ reading: the older getters"),
    section("local function Read()", "------------------------------------------------------------------------ Reset: this window only"),
    section("local function Reset()", "------------------------------------------------------------------------ building"),
]
program = setup + "\n".join(chunks) + "\n" + behavior
result = subprocess.run([lua, "-"], input=program, text=True, capture_output=True)
if result.returncode:
    fail("meter behavior harness failed:\n" + result.stdout + result.stderr)
print(result.stdout.strip())
print("PASS: co-op meter integration guardrails and localization")
