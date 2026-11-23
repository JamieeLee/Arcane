-- Arcane UI: universal DEV treatment; legacy styles are retained in this module.
-- Slot logic stays in Bar.lua; this module owns class selection, palette resolution and panel art.
local C = Arcane
local THEMES = C.BarStyleData
local CLASSIC, HYBRID, FULL_CLASS, CONTROLLER, UNIVERSAL = 1, 2, 3, 4, 5
local EMBLEM_U = 76 / 110 * 0.85
local EMBLEM_W, EMBLEM_H = 512 * EMBLEM_U, 256 * EMBLEM_U
local EMBLEM_L, EMBLEM_R, EMBLEM_IN = 220, 292, 24
local RAIL_H, BASE_RAIL_H = 16 * 76 / 110, C.PANEL_RAIL or 8
local PANEL_CORNER = C.PANEL_CORNER or 16
local BASE_SIGIL = C.PANEL_SIGIL or 122
-- The approved reference medallion is a 400px cutout in a 512px power-of-two TGA.
-- Center the visible crest on the panel edge; do not scale the old bottom-left offset.
local HYBRID_SIGIL = BASE_SIGIL * 1.40
local HYBRID_CENTER_X = HYBRID_SIGIL * 0.10
local HYBRID_CENTER_Y = HYBRID_SIGIL * 18 / 400
local DEFAULT_SIGIL = C.PANEL_MEDALLION or HYBRID_SIGIL
local DEFAULT_CENTER_X = C.PANEL_MEDALLION_X or HYBRID_CENTER_X
local DEFAULT_CENTER_Y = C.PANEL_MEDALLION_Y or HYBRID_CENTER_Y
local state = {
	db = nil, class = nil, runId = nil, readClock = 0, stamp = 0,
	palette = {}, paletteBase = nil, palettePalStamp = -1,
	paletteStyleStamp = -1, paletteMode = 0, paletteClass = nil,
}

local M = {}
C.BarStyles = M
M.CLASSIC, M.HYBRID, M.FULL_CLASS, M.CONTROLLER, M.UNIVERSAL = CLASSIC, HYBRID, FULL_CLASS, CONTROLLER, UNIVERSAL
C.UniversalUX = true -- DEV presentation; do not erase the previous saved style

local function DB()
	if not state.db then state.db = C.DB("bar") end
	if state.db.style == nil then state.db.style = CLASSIC end
	return state.db
end

local function Mode()
	if C.UniversalUX then return UNIVERSAL end
	local mode = tonumber(DB().style) or CLASSIC
	if mode < CLASSIC or mode > CONTROLLER then
		mode = CLASSIC
		DB().style = mode
	end
	return mode
end

local function ClassKey(value)
	if type(value) ~= "string" then return nil end
	local _, _, key = string.find(string.lower(value), "(%a+)$")
	if key and THEMES[key] then return key end
	return nil
end

local function CurrentTheme()
	-- Prefer this character's actual class over the last class saved by another character.
	-- A live run's loadout remains authoritative when it has supplied one.
	local key = state.class
	if not key and type(UnitClass) == "function" then
		local _, class = UnitClass("player")
		key = ClassKey(class)
	end
	key = key or ClassKey(DB().heroClass) or "warrior"
	return THEMES[key], key
end

local function ReadRunClass()
	if type(AZS_GetMeterContext) ~= "function" or type(AZS_GetMeterLoadout) ~= "function" then return end
	local context = C.Call(AZS_GetMeterContext)
	if type(context) ~= "table" or not context.runId or context.runId == state.runId then return end
	local loadout = C.Call(AZS_GetMeterLoadout, { apiVersion = 1, runId = context.runId })
	local actors = type(loadout) == "table" and type(loadout.actors) == "table" and loadout.actors
	local me = actors and actors[context.localOwnerId or loadout.ownerId or ""]
	local key = type(me) == "table" and ClassKey(me.classKey)
	if not key then return end -- the loadout may not be ready yet; try again next second
	state.runId = context.runId
	if state.class ~= key then
		state.class = key
		DB().heroClass = key
		state.stamp = state.stamp + 1
		if Mode() == FULL_CLASS or Mode() == UNIVERSAL then C.palStamp = C.palStamp + 1 end
	end
end

-- One saved position for every class in this DEV phase; per-class later.
-- OFF restores both Full Class ornaments without changing the rest of the UX.
function M.MedallionSide()
	local side = DB().medallionSide
	if side == "RIGHT" or side == "OFF" then return side end
	return "LEFT"
end

function M.SetMedallionSide(side)
	if side ~= "LEFT" and side ~= "RIGHT" and side ~= "OFF" then return false end
	local db = DB()
	if M.MedallionSide() == side then return false end
	db.medallionSide = side
	state.stamp = state.stamp + 1
	C.palStamp = C.palStamp + 1
	return true
end

function M.Mode()
	return Mode()
end

function M.SetMode(mode)
	if C.UniversalUX then return false end
	mode = tonumber(mode)
	if mode ~= CLASSIC and mode ~= HYBRID and mode ~= FULL_CLASS and mode ~= CONTROLLER then return false end
	local db = DB()
	if db.style == mode then return false end
	local previous = Mode()
	local controller = C.ControllerUX
	if controller and controller.BeforeStyleChange then controller.BeforeStyleChange(previous, mode) end
	db.style = mode
	state.stamp = state.stamp + 1
	state.paletteBase = nil
	state.readClock = 0
	C.palStamp = C.palStamp + 1 -- every palette consumer must repaint when the UI style changes
	if mode ~= CLASSIC then M.Update(0, true) end
	if controller and controller.AfterStyleChange then controller.AfterStyleChange(previous, mode) end
	return true
end

function M.Stamp()
	return state.stamp
end

function M.Update(dt, force)
	if Mode() == CLASSIC then return end
	state.readClock = state.readClock - (dt or 0)
	if force or state.readClock <= 0 then
		state.readClock = 1
		ReadRunClass()
	end
end

function M.Palette()
	-- Use the underlying zone/bronze palette: C.Pal() may call back into this in Full Class mode.
	local base = C.BasePal()
	local mode = Mode()
	if mode == CLASSIC then return base end
	local theme, key = CurrentTheme()
	if state.paletteBase ~= base or state.palettePalStamp ~= C.palStamp
			or state.paletteStyleStamp ~= state.stamp or state.paletteMode ~= mode
			or state.paletteClass ~= key then
		for k, v in pairs(base) do state.palette[k] = v end
		state.palette.title = theme.title
		state.palette.rim = theme.rim
		state.palette.gem = theme.gem
		state.palette.glow = theme.glow
		state.palette.trough = theme.trough
		state.palette.mc = theme.mc
		state.palette.fillA = { theme.fill[1] * 0.55, theme.fill[2] * 0.55, theme.fill[3] * 0.55 }
		state.palette.fillM = theme.fill
		state.palette.fillB = theme.gem
		state.paletteBase = base
		state.palettePalStamp = C.palStamp
		state.paletteStyleStamp = state.stamp
		state.paletteMode = mode
		state.paletteClass = key
	end
	return state.palette
end

function M.PanelMetal(pal)
	if Mode() == CLASSIC or Mode() == HYBRID or Mode() == CONTROLLER or Mode() == UNIVERSAL then return C.PanelMetal(pal) end
	local theme = CurrentTheme()
	return theme.metal[1], theme.metal[2], theme.metal[3]
end

local function PlaceEmblem(texture, frame, side, emblem)
	local left = side == "LEFT"
	local middle = left and EMBLEM_L or EMBLEM_R
	local x = left and (EMBLEM_IN - middle * EMBLEM_U) or (-EMBLEM_IN - middle * EMBLEM_U)
	texture:SetTexture(C.ART .. "PanelEmblem" .. emblem .. (left and "L" or "R"))
	texture:SetWidth(EMBLEM_W)
	texture:SetHeight(EMBLEM_H)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", frame, side, x, EMBLEM_H / 2)
	C.Vis(texture, true)
end

local function EnsureClassEmblems(panel)
	if panel.classEmblems then return end
	panel.classEmblems = {
		C.Tex(panel.frame, "OVERLAY", C.ART .. "Glow"),
		C.Tex(panel.frame, "OVERLAY", C.ART .. "Glow"),
	}
	C.Vis(panel.classEmblems[1], false)
	C.Vis(panel.classEmblems[2], false)
end

local function EnsureHybridArcane(panel)
	if panel.hybridArcane then return end
	local frame = panel.frame
	-- Canonical high-resolution medallion; class variants alter only the inner enamel.
	panel.hybridArcane = C.Tex(frame, "OVERLAY", C.ART .. "PanelHybridArcane")
	-- Separate gemstone layer remains independently tinted from the class gem palette.
	panel.hybridGem = C.Tex(frame, "OVERLAY", C.ART .. "PanelHybridArcaneGem")
	for _, texture in ipairs({ panel.hybridArcane, panel.hybridGem }) do
		texture:SetWidth(HYBRID_SIGIL)
		texture:SetHeight(HYBRID_SIGIL)
		texture:SetPoint("CENTER", frame, "LEFT", HYBRID_CENTER_X, HYBRID_CENTER_Y)
		C.Vis(texture, false)
	end
end

local function HybridArcaneTexture(key)
	if key == "warrior" then return C.ART .. "PanelHybridArcaneWarrior" end
	if key == "paladin" then return C.ART .. "PanelHybridArcanePaladin" end
	if key == "rogue" then return C.ART .. "PanelHybridArcaneRogue" end
	if key == "priest" then return C.ART .. "PanelHybridArcanePriest" end
	if key == "shaman" then return C.ART .. "PanelHybridArcaneShaman" end
	if key == "mage" then return C.ART .. "PanelHybridArcaneMage" end
	if key == "warlock" then return C.ART .. "PanelHybridArcaneWarlock" end
	-- Hunter and Druid keep the approved original green Arcane medallion.
	return C.ART .. "PanelHybridArcane"
end
local function RestoreBasePanel(panel)
	local frame = panel.frame
	panel.railT:SetTexture(C.ART .. "PanelRailT")
	panel.railB:SetTexture(C.ART .. "PanelRailB")
	panel.railT:SetHeight(BASE_RAIL_H)
	panel.railB:SetHeight(BASE_RAIL_H)
	panel.railT:ClearAllPoints()
	panel.railT:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_CORNER, 0)
	panel.railT:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PANEL_CORNER, 0)
	panel.railB:ClearAllPoints()
	panel.railB:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PANEL_CORNER, 0)
	panel.railB:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PANEL_CORNER, 0)
	panel.fill:SetTexture(panel.baseFill or (C.ART .. "PanelFill"))
	for i = 1, table.getn(panel.ends) do C.Vis(panel.ends[i], true) end
	if panel.sigils then
		for i, side in ipairs({ "LEFT", "RIGHT" }) do
			local right = side == "RIGHT"
			local x = right and -DEFAULT_CENTER_X or DEFAULT_CENTER_X
			local texture = panel.sigils[i]
			if texture then
				texture:SetTexture(C.ART .. "PanelDefaultMedallion")
				texture:SetWidth(DEFAULT_SIGIL)
				texture:SetHeight(DEFAULT_SIGIL)
				texture:ClearAllPoints()
				texture:SetPoint("CENTER", frame, side, x, DEFAULT_CENTER_Y)
				if right then
					texture:SetTexCoord(1, 0, 0, 1)
				else
					texture:SetTexCoord(0, 1, 0, 1)
				end
				C.Vis(texture, true)
			end
		end
	end
	if panel.classEmblems then
		C.Vis(panel.classEmblems[1], false)
		C.Vis(panel.classEmblems[2], false)
	end
	if panel.hybridArcane then C.Vis(panel.hybridArcane, false) end
	if panel.hybridGem then C.Vis(panel.hybridGem, false) end

end

function M.Apply(panel)
	if not panel or not panel.sigils or not panel.railT or not panel.railB then return end
	local mode = Mode()
	local theme, key = CurrentTheme()
	local medalSide = mode == UNIVERSAL and M.MedallionSide() or "LEFT"
	if panel.barStyleMode == mode and panel.barStyleClass == key
			and panel.barStyleMedallionSide == medalSide then return end
	panel.barStyleMode, panel.barStyleClass, panel.barStyleMedallionSide = mode, key, medalSide
	RestoreBasePanel(panel)
	if mode == CLASSIC or mode == CONTROLLER then return end
	EnsureClassEmblems(panel)
	if mode == HYBRID or mode == UNIVERSAL then
		EnsureHybridArcane(panel)
		panel.hybridArcane:SetTexture(HybridArcaneTexture(key))
		C.Vis(panel.sigils[1], false)
		C.Vis(panel.sigils[2], false)
		if mode == UNIVERSAL and medalSide == "OFF" then
			-- No Arcane A: use the two existing Full Class class emblems.
			-- Keep Universal's Hybrid bronze palette and engraved rails.
			C.Vis(panel.hybridArcane, false)
			C.Vis(panel.hybridGem, false)
			for i = 1, table.getn(panel.ends) do C.Vis(panel.ends[i], false) end
			PlaceEmblem(panel.classEmblems[1], panel.frame, "LEFT", theme.emblem)
			PlaceEmblem(panel.classEmblems[2], panel.frame, "RIGHT", theme.emblem)
		else
			C.Vis(panel.hybridArcane, true)
			C.Vis(panel.hybridGem, true)
			if mode == UNIVERSAL then
				-- One A and one class emblem; swap sides without mirroring the A.
				local classSide = medalSide == "LEFT" and "RIGHT" or "LEFT"
				local anchorX = medalSide == "LEFT" and HYBRID_CENTER_X or -HYBRID_CENTER_X
				for _, texture in ipairs({ panel.hybridArcane, panel.hybridGem }) do
					texture:ClearAllPoints()
					texture:SetPoint("CENTER", panel.frame, medalSide, anchorX, HYBRID_CENTER_Y)
					texture:SetTexCoord(0, 1, 0, 1)
				end
				local ends = medalSide == "LEFT" and panel.endLeft or panel.endRight
				for i = 1, table.getn(ends or {}) do C.Vis(ends[i], false) end
				PlaceEmblem(panel.classEmblems[classSide == "LEFT" and 1 or 2],
					panel.frame, classSide, theme.emblem)
			else
				-- Retain the original Hybrid left-A/right-class composition.
				for i = 1, table.getn(panel.endLeft or {}) do C.Vis(panel.endLeft[i], false) end
				PlaceEmblem(panel.classEmblems[2], panel.frame, "RIGHT", theme.emblem)
			end
		end
		if mode == UNIVERSAL then
			-- Full Class engraved rails with Hybrid bronze and whichever end ornaments are selected.
			local y = RAIL_H / 2 - BASE_RAIL_H / 2
			panel.railT:SetTexture(C.ART .. "PanelRail" .. theme.emblem .. "T")
			panel.railB:SetTexture(C.ART .. "PanelRail" .. theme.emblem .. "B")
			panel.railT:SetHeight(RAIL_H)
			panel.railB:SetHeight(RAIL_H)
			panel.railT:ClearAllPoints()
			panel.railT:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, y)
			panel.railT:SetPoint("TOPRIGHT", panel.frame, "TOPRIGHT", 0, y)
			panel.railB:ClearAllPoints()
			panel.railB:SetPoint("BOTTOMLEFT", panel.frame, "BOTTOMLEFT", 0, -y)
			panel.railB:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", 0, -y)
		end
		return
	end
	for i = 1, table.getn(panel.ends) do C.Vis(panel.ends[i], false) end
	C.Vis(panel.sigils[1], false)
	C.Vis(panel.sigils[2], false)
	PlaceEmblem(panel.classEmblems[1], panel.frame, "LEFT", theme.emblem)
	PlaceEmblem(panel.classEmblems[2], panel.frame, "RIGHT", theme.emblem)
	local y = RAIL_H / 2 - BASE_RAIL_H / 2
	panel.railT:SetTexture(C.ART .. "PanelRail" .. theme.emblem .. "T")
	panel.railT:SetHeight(RAIL_H)
	panel.railT:ClearAllPoints()
	panel.railT:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, y)
	panel.railT:SetPoint("TOPRIGHT", panel.frame, "TOPRIGHT", 0, y)
	panel.railB:SetTexture(C.ART .. "PanelRail" .. theme.emblem .. "B")
	panel.railB:SetHeight(RAIL_H)
	panel.railB:ClearAllPoints()
	panel.railB:SetPoint("BOTTOMLEFT", panel.frame, "BOTTOMLEFT", 0, -y)
	panel.railB:SetPoint("BOTTOMRIGHT", panel.frame, "BOTTOMRIGHT", 0, -y)
	panel.fill:SetTexture(C.ART .. "PanelGlass")
end

function M.Theme(panel, pal)
	if not panel then return end
	M.Apply(panel)
	local mode = Mode()
	if mode == CLASSIC or mode == CONTROLLER then
		C.PanelTheme(panel, pal)
		return
	end
	local theme = CurrentTheme()
	local mr, mg, mb
	if mode == HYBRID or mode == UNIVERSAL then
		mr, mg, mb = C.PanelMetal(pal)
	else
		mr, mg, mb = theme.metal[1], theme.metal[2], theme.metal[3]
	end
	for i = 1, table.getn(panel.metal) do
		panel.metal[i]:SetVertexColor(mr, mg, mb, 1)
	end
	if mode == HYBRID or mode == UNIVERSAL then
		local fill = theme.fill
		panel.fill:SetVertexColor(fill[1] * 0.48, fill[2] * 0.48, fill[3] * 0.48, 0.97)
		if mode == UNIVERSAL then
			panel.railT:SetVertexColor(1, 1, 1, 1)
			panel.railB:SetVertexColor(1, 1, 1, 1)
		end
		panel.hybridArcane:SetVertexColor(1, 1, 1, 1)
		panel.hybridGem:SetVertexColor(theme.gem[1], theme.gem[2], theme.gem[3], 1)
		panel.classEmblems[2]:SetVertexColor(1, 1, 1, 1)
		if mode == UNIVERSAL then panel.classEmblems[1]:SetVertexColor(1, 1, 1, 1) end
		if panel.classGems then
			for i = 1, table.getn(panel.classGems) do
				panel.classGems[i]:SetVertexColor(theme.gem[1], theme.gem[2], theme.gem[3], 1)
			end
		end
	else
		local fill = theme.fill
		panel.fill:SetVertexColor(fill[1], fill[2], fill[3], 0.97)
		panel.railT:SetVertexColor(1, 1, 1, 1)
		panel.railB:SetVertexColor(1, 1, 1, 1)
		panel.classEmblems[1]:SetVertexColor(1, 1, 1, 1)
		panel.classEmblems[2]:SetVertexColor(1, 1, 1, 1)
	end
end

C.OnInit(function()
	DB()
end)
