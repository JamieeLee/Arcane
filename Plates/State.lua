-- Native nameplate discovery and reversible state management.
local C = Arcane
C.Plates = C.Plates or {}
local P = C.Plates
P.State = {}

local function NormalizeName(text)
	if not text then return nil end
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = string.gsub(text, "|r", "")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then return nil end
	return text
end

local function IsOwnObject(frame, object)
	return object == frame.arcanePlatesOverlay
		or object == frame.arcanePlatesDebuffRow
		or object == frame.arcanePlatesShrunkLabelHolder
		or object == frame.arcanePlatesBossGuardianLabelHolder
		or object == frame.arcanePlatesBossGuardianLabel
end

-- Searches descendants because replacement UIs may put the name in a child frame.
local function GetPlateName(frame, root)
	local originalRoot = root == nil
	root = root or frame
	if originalRoot then frame.arcanePlatesNameRegion = nil end
	local regions = { root:GetRegions() }
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region ~= frame.arcanePlatesBossGuardianLabel
				and region:GetObjectType() == "FontString" then
			local name = NormalizeName(region:GetText())
			-- Purely numeric text is a level indicator, not a name.
			if name and not string.find(name, "^%d+$") then
				if originalRoot then frame.arcanePlatesNameRegion = region end
				return name
			end
		end
	end
	local children = { root:GetChildren() }
	for i = 1, table.getn(children) do
		if not IsOwnObject(frame, children[i]) then
			local name = GetPlateName(frame, children[i])
			if name then return name end
		end
	end
	return nil
end

local function FindNameFontString(frame, name)
	local fallback
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region:GetObjectType() == "FontString" then
			local text = region:GetText()
			if text == name then return region end
			if not fallback and text and text ~= "" then fallback = region end
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		if not IsOwnObject(frame, children[i]) then
			local found = FindNameFontString(children[i], name)
			if found and found:GetText() == name then return found end
			if not fallback and found then fallback = found end
		end
	end
	return fallback
end

local function CapturePoints(frame)
	local points = {}
	local count = 0
	if type(frame.GetNumPoints) == "function" then
		count = frame:GetNumPoints() or 0
	end
	if count > 0 then
		for i = 1, count do
			local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
			if point then
				table.insert(points, {
					point = point, relativeTo = relativeTo, relativePoint = relativePoint,
					x = x or 0, y = y or 0,
				})
			end
		end
	else
		local point, relativeTo, relativePoint, x, y = frame:GetPoint()
		if point then
			table.insert(points, {
				point = point, relativeTo = relativeTo, relativePoint = relativePoint,
				x = x or 0, y = y or 0,
			})
		end
	end
	return points
end

local function RestorePoints(frame, points)
	if type(points) ~= "table" or table.getn(points) == 0 then return end
	frame:ClearAllPoints()
	for i = 1, table.getn(points) do
		local p = points[i]
		frame:SetPoint(p.point, p.relativeTo or frame:GetParent(),
			p.relativePoint or p.point, p.x, p.y)
	end
end

local function SaveObjectState(object, states, plate)
	plate = plate or object
	-- The root plate's visibility belongs to the game. Never restore it from our snapshot:
	-- a pooled plate may have been hidden by the game since it was first discovered.
	if object ~= plate then
		-- Arcane-owned overlays have independent lifetimes and are not native state.
		if IsOwnObject(plate, object) then return end
		local state = { object = object, shown = object:IsShown() }
		if object.GetAlpha then state.alpha = object:GetAlpha() end
		table.insert(states, state)
	end
	local kind = object:GetObjectType()
	if kind ~= "Texture" and kind ~= "FontString" then
		local regions = { object:GetRegions() }
		for i = 1, table.getn(regions) do SaveObjectState(regions[i], states, plate) end
		local children = { object:GetChildren() }
		for i = 1, table.getn(children) do SaveObjectState(children[i], states, plate) end
	end
end

local function CaptureNativeState(frame)
	if frame.arcanePlatesNativeCaptured then return end
	local previouslyStyled = frame.arcanePlatesStyledVisual or frame.arcanePlatesOverlay
	frame.arcanePlatesNativeWidth = frame.arcanePlatesStackOriginalWidth or frame:GetWidth()
	frame.arcanePlatesNativeHeight = frame.arcanePlatesStackOriginalHeight or frame:GetHeight()
	frame.arcanePlatesNativeScale = frame.arcanePlatesStackOriginalScale
		or frame.arcanePlatesOriginalScale or frame:GetScale()
	frame.arcanePlatesNativePoints = CapturePoints(frame)

	-- Preserve the explicit native anchor kept by the old stacking integration when present.
	if frame.arcanePlatesStackNativePoint then
		frame.arcanePlatesNativePoints = {{
			point = frame.arcanePlatesStackNativePoint,
			relativeTo = frame.arcanePlatesStackNativeRelativeTo or frame:GetParent(),
			relativePoint = frame.arcanePlatesStackNativeRelativePoint or frame.arcanePlatesStackNativePoint,
			x = frame.arcanePlatesStackNativeX or 0,
			y = frame.arcanePlatesStackNativeY or 0,
		}}
	elseif frame.arcanePlatesStackPoint then
		frame.arcanePlatesNativePoints = {{
			point = frame.arcanePlatesStackPoint,
			relativeTo = frame.arcanePlatesStackRelativeTo or frame:GetParent(),
			relativePoint = frame.arcanePlatesStackRelativePoint or frame.arcanePlatesStackPoint,
			x = frame.arcanePlatesStackX or 0,
			y = frame.arcanePlatesStackY or 0,
		}}
	end

	local states = {}
	SaveObjectState(frame, states)
	-- If an older version already modified this frame, an accurate child snapshot no longer
	-- exists. Keep any snapshot already saved on the frame; do not invent a blanket "show all"
	-- restoration policy for another addon or the game's UI.
	if not previouslyStyled then
		frame.arcanePlatesNativeState = states
	elseif type(frame.arcanePlatesNativeState) ~= "table" then
		frame.arcanePlatesNativeState = nil
	end
	frame.arcanePlatesNativeCaptured = true
end

local function RestoreNativeState(frame)
	if frame.arcanePlatesOverlay then frame.arcanePlatesOverlay:Hide() end
	if type(frame.arcanePlatesNativeState) == "table" then
		for i = 1, table.getn(frame.arcanePlatesNativeState) do
			local state = frame.arcanePlatesNativeState[i]
			local object = state.object
			if object and not IsOwnObject(frame, object) then
				if object.SetAlpha and state.alpha ~= nil then object:SetAlpha(state.alpha) end
				if state.shown then object:Show() else object:Hide() end
			end
		end
	end

	-- Only restore geometry that Tiny Plates owns. Replacement visual children are never
	-- recentered or rescaled here; their original anchors/scales are not ours to rewrite.
	if frame.arcanePlatesNativeWidth then frame:SetWidth(frame.arcanePlatesNativeWidth) end
	if frame.arcanePlatesNativeHeight then frame:SetHeight(frame.arcanePlatesNativeHeight) end
	if frame.arcanePlatesNativeScale then frame:SetScale(frame.arcanePlatesNativeScale) end
	if type(frame.arcanePlatesNativePoints) == "table" then
		RestorePoints(frame, frame.arcanePlatesNativePoints)
	elseif frame.arcanePlatesNativePoint then
		frame:ClearAllPoints()
		frame:SetPoint(frame.arcanePlatesNativePoint,
			frame.arcanePlatesNativeRelativeTo or frame:GetParent(),
			frame.arcanePlatesNativeRelativePoint or frame.arcanePlatesNativePoint,
			frame.arcanePlatesNativeX or 0, frame.arcanePlatesNativeY or 0)
	end
	if frame.arcanePlatesBossGuardianLabel then frame.arcanePlatesBossGuardianLabel:Hide() end
	if frame.arcanePlatesBossGuardianLabelHolder then frame.arcanePlatesBossGuardianLabelHolder:Hide() end
	if frame.arcanePlatesShrunkLabelHolder then frame.arcanePlatesShrunkLabelHolder:Hide() end
	if frame.arcanePlatesDebuffRow then frame.arcanePlatesDebuffRow:Hide() end
	frame.arcanePlatesNativeRestored = true
end

local function ContainsStatusBar(frame)
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		if children[i]:GetObjectType() == "StatusBar" or ContainsStatusBar(children[i]) then
			return true
		end
	end
	return false
end

local function IdentifyNameplate(frame)
	local regions = { frame:GetRegions() }
	local hasBorder = false
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region:GetObjectType() == "Texture"
				and region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" then
			hasBorder = true
			break
		end
	end
	local hasName = GetPlateName(frame) ~= nil
	return hasName and (hasBorder or ContainsStatusBar(frame))
end

local function HideNameText(frame)
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region ~= frame.arcanePlatesBossGuardianLabel
				and region:GetObjectType() == "FontString" then
			region:SetAlpha(0)
			region:Hide()
		end
	end
end

local function HideMatchingNameText(frame, name, keep)
	if not name or name == "" or frame == keep then return end
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region ~= keep and region:GetObjectType() == "FontString"
				and region:GetText() == name then
			region:SetAlpha(0)
			region:Hide()
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		if not IsOwnObject(frame, children[i]) then
			HideMatchingNameText(children[i], name, keep)
		end
	end
end

local function HideNativePlate(frame, keep)
	local regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region:GetObjectType() == "Texture" then region:Hide() end
	end
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		if children[i] ~= keep and children[i] ~= frame.arcanePlatesOverlay
				and children[i] ~= frame.arcanePlatesShrunkLabelHolder then
			children[i]:Hide()
		end
	end
end

local function CollectStatusBars(frame, list)
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		if children[i]:GetObjectType() == "StatusBar" then table.insert(list, children[i]) end
		CollectStatusBars(children[i], list)
	end
	return list
end

local function RegisterPlate(frame, knownPlates, orderedPlates)
	if not frame or not frame.IsVisible or not frame:IsVisible()
			or not frame.GetWidth or frame:GetWidth() <= 0
			or not frame.GetHeight or frame:GetHeight() <= 0 then return false end
	local known = knownPlates[frame] and true or false
	if not known and not IdentifyNameplate(frame) then return false end

	local currentName = GetPlateName(frame)
	local oldName = frame.arcanePlatesPlateName
	-- A briefly blank name is common while a pooled plate is being reused. Do not treat
	-- that transient state as a new unit or throw away the last valid identity.
	local nameChanged = currentName and currentName ~= oldName
	if known and nameChanged and oldName ~= nil then
		RestoreNativeState(frame)
	end

	if not known then
		knownPlates[frame] = true
		table.insert(orderedPlates, frame)
		CaptureNativeState(frame)
		frame.arcanePlatesOriginalScale = frame:GetScale() or 1
	elseif nameChanged then
		-- A recycled frame may contain new native regions/children. Capture those after
		-- restoring the previous unit, while retaining the original objects' snapshots.
		if type(frame.arcanePlatesNativeState) == "table" then
			local states = frame.arcanePlatesNativeState
			local seen, fresh = {}, {}
			for i = 1, table.getn(states) do seen[states[i].object] = true end
			SaveObjectState(frame, fresh)
			for i = 1, table.getn(fresh) do
				if not seen[fresh[i].object] then table.insert(states, fresh[i]) end
			end
		end
	end

	if nameChanged then
		frame.arcanePlatesPlateName = currentName
		-- A pooled frame may receive a different native visual tree. Drop cached references so
		-- the replacement bar is rebound to the new unit's actual StatusBar and name container.
		frame.arcanePlatesSourceBar = nil
		frame.arcanePlatesStyledVisual = nil
		frame.arcanePlatesStyledOriginalScale = nil
		frame.arcanePlatesSourceOriginalWidth = nil
		frame.arcanePlatesSourceOriginalHeight = nil
		frame.arcanePlatesDebuffUnitID = nil
		frame.arcanePlatesDebuffSignature = nil
		frame.arcanePlatesAppliedCategory = nil
		frame.arcanePlatesStyleRevision = -1
		frame.arcanePlatesNativeRestored = false
		if frame.arcanePlatesHealthBar then frame.arcanePlatesHealthBar.snap = true end
	end
	return true
end

P.State.NormalizeName = NormalizeName
P.State.GetPlateName = GetPlateName
P.State.FindNameFontString = FindNameFontString
P.State.IsOwnObject = IsOwnObject
P.State.CaptureNativeState = CaptureNativeState
P.State.RestoreNativeState = RestoreNativeState
P.State.ContainsStatusBar = ContainsStatusBar
P.State.IdentifyNameplate = IdentifyNameplate
P.State.HideNameText = HideNameText
P.State.HideMatchingNameText = HideMatchingNameText
P.State.HideNativePlate = HideNativePlate
P.State.CollectStatusBars = CollectStatusBars
P.State.RegisterPlate = RegisterPlate
