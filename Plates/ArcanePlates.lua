-- Tiny Plates controller: scanning, update cadence and lifecycle.
local C = Arcane
C.Plates = C.Plates or {}
local P = C.Plates

P.Option = function(key)
	if type(C.ArcanePlatesOption) == "function" then return C.ArcanePlatesOption(key) end
	return false
end

local knownPlates = {}
local orderedPlates = {}
local active = true
local scanClock = 0
local SCAN_INTERVAL = 0.50
local OVERLAY_INTERVAL = 0.10
local DEBUFF_INTERVAL = 0.25
local overlayClock = 0
local debuffClock = 0
local refreshPending = true
local styleRevision = 0
local scanFrame

local function RegisterPlate(frame)
	return P.State.RegisterPlate(frame, knownPlates, orderedPlates)
end

local function SyncOverlayValues()
	P.Visuals.SyncOverlayValues(orderedPlates)
end

local function ApplyKnownPlate(frame, updateDebuffs)
	if not frame or not frame.GetObjectType then return end
	local objectType = frame:GetObjectType()
	-- Azeroth Survivors creates anonymous Buttons under WorldFrame as well as Frames.
	if objectType ~= "Frame" and objectType ~= "Button" then return end
	if not frame.IsVisible or not frame:IsVisible() then return end

	local special = P.Special.IsBossOrGuardianPlate(frame)
	local category = special and "boss" or "regular"
	if frame.arcanePlatesAppliedCategory ~= category
			or frame.arcanePlatesStyleRevision ~= styleRevision then
		if P.Visuals.Apply(frame) then
			-- Record the revision only after a complete style pass. A plate that is still
			-- constructing its StatusBar must remain eligible for a later retry.
			frame.arcanePlatesAppliedCategory = category
			frame.arcanePlatesStyleRevision = styleRevision
		else
			P.State.RestoreNativeState(frame)
			frame.arcanePlatesAppliedCategory = nil
			frame.arcanePlatesStyleRevision = -1
		end
	end

	if special then
		if updateDebuffs then
			if P.Option("showDebuffs") then P.Special.UpdateDebuffs(frame)
			else P.Special.HideDebuffs(frame) end
		end
	elseif frame.arcanePlatesDebuffRow then
		P.Special.HideDebuffs(frame)
	end
end

local function StyleKnownPlates(updateDebuffs)
	P.Special.RefreshNames(false, orderedPlates)
	for i = 1, table.getn(orderedPlates) do
		ApplyKnownPlate(orderedPlates[i], updateDebuffs)
	end
end

local function ScanNameplates()
	if type(WorldFrame) ~= "table" or type(WorldFrame.GetChildren) ~= "function" then return end
	local children = { WorldFrame:GetChildren() }
	for i = 1, table.getn(children) do
		local frame = children[i]
		if frame and frame.IsVisible and frame:IsVisible()
				and frame.GetWidth and frame:GetWidth() > 0
				and frame.GetHeight and frame:GetHeight() > 0 then
			RegisterPlate(frame)
		end
	end
end

local function RefreshAll()
	refreshPending = true
	if scanFrame then scanClock = 0 end
end

local function RestoreAll()
	active = false
	for i = 1, table.getn(orderedPlates) do
		local frame = orderedPlates[i]
		if frame then
			P.State.RestoreNativeState(frame)
			if frame.arcanePlatesOverlay then frame.arcanePlatesOverlay:Hide() end
			P.Special.HideDebuffs(frame)
			if frame.arcanePlatesBossGuardianLabel then frame.arcanePlatesBossGuardianLabel:Hide() end
			if frame.arcanePlatesBossGuardianLabelHolder then frame.arcanePlatesBossGuardianLabelHolder:Hide() end
			if frame.arcanePlatesShrunkLabelHolder then frame.arcanePlatesShrunkLabelHolder:Hide() end
			frame.arcanePlatesNativeRestored = true
		end
	end
end

local function SetEnabled(on)
	on = on and true or false
	if active == on then
		if active then RefreshAll() end
		return
	end
	active = on
	styleRevision = styleRevision + 1
	for i = 1, table.getn(orderedPlates) do
		orderedPlates[i].arcanePlatesAppliedCategory = nil
		orderedPlates[i].arcanePlatesStyleRevision = -1
	end
	if active then
		scanClock = 0
		refreshPending = true
		if scanFrame then scanFrame:Show() end
	else
		RestoreAll()
		if scanFrame then scanFrame:Hide() end
	end
end

C.ArcanePlatesRefresh = function(force)
	styleRevision = styleRevision + 1
	if force then RefreshAll() else refreshPending = true end
end

C.OnInit(function()
	local d = C.DB("nameplates", {
		showDebuffs = true, hideShrunkPlates = false, hideBossName = false,
		showShrunkName = false, showHealthText = true, enabled = true,
	})
	active = d.enabled ~= false
	scanFrame = CreateFrame("Frame", "ArcanePlatesDriver")
	scanFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	scanFrame:RegisterEvent("CHAT_MSG_ADDON")
	scanFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	scanFrame:SetScript("OnEvent", function()
		if event == "CHAT_MSG_ADDON" and arg1 ~= "AZSUNITS" then return end
		RefreshAll()
	end)
	scanFrame:SetScript("OnUpdate", function()
		if not active then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		if dt < 0 then dt = 0 end

		scanClock = scanClock - dt
		if scanClock <= 0 then
			scanClock = SCAN_INTERVAL
			ScanNameplates()
			refreshPending = true
		end

		overlayClock = overlayClock - dt
		if overlayClock <= 0 then
			overlayClock = OVERLAY_INTERVAL
			SyncOverlayValues()
		end

		debuffClock = debuffClock - dt
		local updateDebuffs = false
		if debuffClock <= 0 then
			debuffClock = DEBUFF_INTERVAL
			updateDebuffs = true
		end
		if refreshPending then
			refreshPending = false
			local ok, err = pcall(StyleKnownPlates, updateDebuffs)
			if not ok then
				C.Print(C.L("Arcane nameplates stopped after an error: ") .. tostring(err))
				SetEnabled(false)
			end
		elseif updateDebuffs then
			local ok, err = pcall(function()
				P.Special.RefreshNames(false, orderedPlates)
				for i = 1, table.getn(orderedPlates) do
					local frame = orderedPlates[i]
					if frame.arcanePlatesBossGuardian and frame:IsVisible() and P.Option("showDebuffs") then
						P.Special.UpdateDebuffs(frame)
					end
				end
			end)
			if not ok then
				C.Print(C.L("Arcane nameplate debuff update stopped after an error: ") .. tostring(err))
				SetEnabled(false)
			end
		end
	end)
	if not active then scanFrame:Hide() end
end)

C.OnWorld(function()
	if active and scanFrame then RefreshAll(); scanFrame:Show() end
end)

C.OnLogout(function() RestoreAll() end)

C.RegisterPart({
	key = "nameplates", name = "Tiny Plates",
	note = "Half-size regular nameplates, with full-size boss and guardian plates.",
	get = function() return active end,
	set = function(on)
		local d = C.DB("nameplates")
		d.enabled = on and true or false
		SetEnabled(on)
	end,
})
