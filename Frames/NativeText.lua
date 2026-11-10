-- Arcane UI: tint the outline around native zone text and theme floating status text.
-- The native zone labels themselves remain untouched: same font, size, fill color, anchors and fades.
local C = Arcane

local AURA_TYPES = { "SPELL_CAST", "AURA_START", "AURA_END" }
local HEAL_TYPES = { "HEAL", "HEAL_CRIT", "PERIODIC_HEAL" }
local STROKE_OFFSETS = {
	{ -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 },
	{ -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 },
}

local zoneStroke, subZoneStroke
local themedCombatFonts = false
local lastPalette = {}
local poll = 0

-- The timer owns the zone palette and writes it to Arcane.pal every time its trim color
-- glides. Read that exact rim rather than the more general panel palette.
local function TimerRim()
	local p = C.pal
	if type(p) == "table" and type(p.rim) == "table" then return p.rim end
	return C.Pal().rim
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
		stroke.copies[i].fs:Hide()
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
	local width, height = source:GetWidth(), source:GetHeight()
	local justifyH = type(source.GetJustifyH) == "function" and source:GetJustifyH() or "CENTER"
	local justifyV = type(source.GetJustifyV) == "function" and source:GetJustifyV() or "MIDDLE"

	for i = 1, table.getn(stroke.copies) do
		local copy = stroke.copies[i]
		local fs = copy.fs
		if copy.face ~= face or copy.size ~= size then
			-- A plain colored glyph sits behind the game's original text. The native
			-- FontString on ARTWORK remains on top with all of its original styling.
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
		if type(height) == "number" and height > 0 and copy.height ~= height then
			fs:SetHeight(height)
			copy.height = height
		end
		if copy.justifyH ~= justifyH then
			fs:SetJustifyH(justifyH)
			copy.justifyH = justifyH
		end
		if copy.justifyV ~= justifyV then
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

	-- Change only the colors of the native positive aura/cast and heal categories.
	-- All show flags, harmful categories and client message behavior remain untouched.
	for i = 1, table.getn(AURA_TYPES) do
		SetCombatColor(info, AURA_TYPES[i], pal.title)
	end
	for i = 1, table.getn(HEAL_TYPES) do
		SetCombatColor(info, HEAL_TYPES[i], pal.mc)
	end

	if not themedCombatFonts then
		local found = 0
		for i = 1, 20 do
			local fs = getglobal("CombatText" .. i)
			if fs then
				local face, size = fs:GetFont()
				if type(face) == "string" and type(size) == "number" then
					fs:SetFont(C.Face(C.FONT), size, "OUTLINE")
				end
				found = found + 1
			end
		end
		themedCombatFonts = found == 20
	end
	return true
end

local function ApplyTheme()
	local pal = C.Pal()
	local rim = TimerRim()
	local changed = pal.title[1] ~= lastPalette.titleR
		or pal.title[2] ~= lastPalette.titleG
		or pal.title[3] ~= lastPalette.titleB
		or pal.mc[1] ~= lastPalette.mcR
		or pal.mc[2] ~= lastPalette.mcG
		or pal.mc[3] ~= lastPalette.mcB
		or rim[1] ~= lastPalette.rimR
		or rim[2] ~= lastPalette.rimG
		or rim[3] ~= lastPalette.rimB
	if not changed then return end

	lastPalette.titleR, lastPalette.titleG, lastPalette.titleB = pal.title[1], pal.title[2], pal.title[3]
	lastPalette.mcR, lastPalette.mcG, lastPalette.mcB = pal.mc[1], pal.mc[2], pal.mc[3]
	lastPalette.rimR, lastPalette.rimG, lastPalette.rimB = rim[1], rim[2], rim[3]

	SyncTextStroke(zoneStroke, rim)
	SyncTextStroke(subZoneStroke, rim)
	ApplyCombatText(pal)
end

local function RefreshZone()
	local rim = TimerRim()
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
		if not themedCombatFonts then ApplyCombatText(C.Pal()) end
		RefreshZone()
	end)
	watch:SetScript("OnUpdate", function()
		poll = poll + (arg1 or 0)
		if poll < 0.1 then return end
		poll = 0
		ApplyTheme()
		if not themedCombatFonts then ApplyCombatText(C.Pal()) end
		RefreshZone()
	end)

	ApplyTheme()
	ApplyCombatText(C.Pal())
	RefreshZone()
end)
