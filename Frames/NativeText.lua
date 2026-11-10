-- Arcane UI: tint the outline around native zone text and theme floating status text.
-- The native zone labels themselves remain untouched: same font, size, fill color, anchors and fades.
local C = Arcane

local AURA_TYPES = { "SPELL_CAST", "AURA_START", "AURA_END" }
local HEAL_TYPES = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL" }
local STROKE_OFFSETS = {
	{ -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 },
	{ -1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, -1.5 }, { 1.5, 1.5 },
}

local zoneStroke, subZoneStroke
local themedCombatFonts = false
local combatColorsApplied = false
local lastPalette = {}
local poll = 0

-- The timer publishes its interpolated zone palette on Arcane.pal. C.Pal() is the
-- broader bronze/class palette, so it must not be used for zone-following text accents.
local function LivePalette()
	local pal = C.pal
	if type(pal) == "table" and type(pal.rim) == "table" then return pal end
	return C.DEFAULT_PAL or C.Pal()
end

local function NewTextStroke(parent, source)
	if not parent or not source or type(parent.CreateFontString) ~= "function" then return nil end
	local stroke = { source = source, copies = {}, shown = false }
	for i = 1, table.getn(STROKE_OFFSETS) do
		local offset = STROKE_OFFSETS[i]
		local fs = parent:CreateFontString(nil, "BACKGROUND")
		fs:SetText("")
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
		fs:Hide()
		stroke.copies[i] = { fs = fs, x = offset[1], y = offset[2] }
	end
	return stroke
end

local function HideTextStroke(stroke)
	if not stroke or not stroke.shown then return end
	stroke.shown = false
	for i = 1, table.getn(stroke.copies) do
		local copy = stroke.copies[i]
		copy.fs:Hide()
		copy.shown = false
	end
end

local function SyncTextStroke(stroke, rim)
	if not stroke then return end
	local source = stroke.source
	local value = source:GetText()
	if not value or value == "" then
		stroke.value = value
		HideTextStroke(stroke)
		return
	end

	local face, size = source:GetFont()
	if type(face) ~= "string" or type(size) ~= "number" or size <= 0 then return end
	local width = source:GetWidth()
	local height = source:GetHeight() or 0
	if type(source.GetStringHeight) == "function" then
		local stringHeight = source:GetStringHeight() or 0
		if stringHeight > height then height = stringHeight end
	end
	-- The native XML sets the text region's height to zero (auto-sized). A copied
	-- FontString needs an explicit height or the client may clip the whole outline away.
	if height < size then height = size * 1.5 end
	height = height + 4
	local justifyH = type(source.GetJustifyH) == "function" and source:GetJustifyH() or "CENTER"
	local justifyV = type(source.GetJustifyV) == "function" and source:GetJustifyV() or nil

	for i = 1, table.getn(stroke.copies) do
		local copy = stroke.copies[i]
		local fs = copy.fs
		if copy.face ~= face or copy.size ~= size then
			-- Use the exact native face and point size, but no native dark outline on the
			-- copy: its colored edge is the part that should show around the untouched text.
			fs:SetFont(face, size)
			copy.face, copy.size = face, size
		end
		if copy.value ~= value then
			fs:SetText(value)
			copy.value = value
		end
		if type(width) == "number" and width > 0 and copy.width ~= width then
			fs:SetWidth(width)
			copy.width = width
		end
		if copy.height ~= height then
			fs:SetHeight(height)
			copy.height = height
		end
		if copy.justifyH ~= justifyH then
			fs:SetJustifyH(justifyH)
			copy.justifyH = justifyH
		end
		if justifyV and type(fs.SetJustifyV) == "function" and copy.justifyV ~= justifyV then
			fs:SetJustifyV(justifyV)
			copy.justifyV = justifyV
		end
		if not copy.anchored then
			fs:SetPoint("CENTER", source, "CENTER", copy.x, copy.y)
			copy.anchored = true
		end
		if copy.red ~= rim[1] or copy.green ~= rim[2] or copy.blue ~= rim[3] then
			fs:SetTextColor(rim[1], rim[2], rim[3])
			copy.red, copy.green, copy.blue = rim[1], rim[2], rim[3]
		end
		if not copy.shown then
			fs:Show()
			copy.shown = true
		end
	end
	stroke.shown = true
end

local function SetCombatColor(info, name, color)
	local entry = info[name]
	if type(entry) == "table" then
		entry.r, entry.g, entry.b = color[1], color[2], color[3]
	end
end

local function ApplyCombatText(pal)
	local info = COMBAT_TEXT_TYPE_INFO
	if type(info) ~= "table" then return false end

	-- Preserve Blizzard's message types, visibility flags and animation. Only positive
	-- aura/cast and healing colors follow the live zone palette; harmful colors remain native.
	for i = 1, table.getn(AURA_TYPES) do
		SetCombatColor(info, AURA_TYPES[i], pal.title)
	end
	for i = 1, table.getn(HEAL_TYPES) do
		SetCombatColor(info, HEAL_TYPES[i], pal.mc)
	end
	combatColorsApplied = true

	if not themedCombatFonts then
		local found = 0
		for i = 1, 20 do
			local fs = getglobal("CombatText" .. i)
			if fs then
				local _, size, flags = fs:GetFont()
				if type(size) == "number" and size > 0 then
					fs:SetFont(C.Face(C.FONT), size, flags)
				end
				found = found + 1
			end
		end
		themedCombatFonts = found == 20
	end
	return true
end

local function ApplyTheme()
	local pal = LivePalette()
	local rim = pal.rim
	local changed = pal.title[1] ~= lastPalette.titleR
		or pal.title[2] ~= lastPalette.titleG
		or pal.title[3] ~= lastPalette.titleB
		or pal.mc[1] ~= lastPalette.mcR
		or pal.mc[2] ~= lastPalette.mcG
		or pal.mc[3] ~= lastPalette.mcB
		or rim[1] ~= lastPalette.rimR
		or rim[2] ~= lastPalette.rimG
		or rim[3] ~= lastPalette.rimB

	if changed then
		lastPalette.titleR, lastPalette.titleG, lastPalette.titleB = pal.title[1], pal.title[2], pal.title[3]
		lastPalette.mcR, lastPalette.mcG, lastPalette.mcB = pal.mc[1], pal.mc[2], pal.mc[3]
		lastPalette.rimR, lastPalette.rimG, lastPalette.rimB = rim[1], rim[2], rim[3]
		SyncTextStroke(zoneStroke, rim)
		SyncTextStroke(subZoneStroke, rim)
	end

	-- Retry until Blizzard_CombatText has created its table and all 20 font strings.
	-- Reapply on palette transitions so the floating text follows each zone's colors.
	if changed or not combatColorsApplied or not themedCombatFonts then
		ApplyCombatText(pal)
	end
end

local function RefreshZone()
	local rim = LivePalette().rim
	SyncTextStroke(zoneStroke, rim)
	SyncTextStroke(subZoneStroke, rim)
end

C.OnInit(function()
	local zoneFrame = getglobal("ZoneTextFrame")
	local subFrame = getglobal("SubZoneTextFrame")
	zoneStroke = NewTextStroke(zoneFrame, getglobal("ZoneTextString"))
	subZoneStroke = NewTextStroke(subFrame, getglobal("SubZoneTextString"))

	local watch = CreateFrame("Frame", "ArcaneNativeTextTheme")
	watch:RegisterEvent("ADDON_LOADED")
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("ZONE_CHANGED")
	watch:RegisterEvent("ZONE_CHANGED_INDOORS")
	watch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	watch:SetScript("OnEvent", function()
		ApplyTheme()
		RefreshZone()
	end)
	watch:SetScript("OnUpdate", function()
		poll = poll + (arg1 or 0)
		if poll < 0.1 then return end
		poll = 0
		ApplyTheme()
		RefreshZone()
	end)

	ApplyTheme()
	RefreshZone()
end)
