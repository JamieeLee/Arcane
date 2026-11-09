-- Arcane UI: the game's own error/notification feed, with Arcane's shared panel treatment.
-- The stock frame keeps its original events and message colors; Arcane owns only its shell,
-- default placement, saved movement and visibility switch.
local C = Arcane
local DEFAULTS = { enabled = true }
local db
local deco
local themeStamp = -1

local function Theme()
	if not deco then return end
	C.PanelTheme(deco, C.Pal())
	themeStamp = C.palStamp
end

local function Apply()
	if not db then return end
	if db.enabled then
		C.RestoreStock("UIErrorsFrame")
	else
		C.HideStock("UIErrorsFrame")
	end
end

C.OnInit(function()
	db = C.DB("stockErrors", DEFAULTS)
	local frame = getglobal("UIErrorsFrame")
	if type(frame) ~= "table" then return end

	C.Movable(frame, "stockErrors", "Stock error messages", function(f)
		f:ClearAllPoints()
		-- Center on the game's "Move to Begin" prompt. This keeps the error and
		-- information feed in the center field without overlapping the boss stack.
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end)
	deco = C.Panel(frame, false)
	Theme()

	-- Shared palettes can change when the player selects a UI style or a run class
	-- is resolved. Refresh only when the common palette stamp changes.
	local themeDriver = CreateFrame("Frame", "ArcaneStockErrorsThemeDriver")
	themeDriver:SetScript("OnUpdate", function()
		if themeStamp ~= C.palStamp then Theme() end
	end)
	Apply()
end)

C.OnWorld(function()
	Theme()
	Apply()
end)

C.OnLogout(function()
	-- Do not leave the game's own frame parented under Arcane's hidden container at logout.
	if db and not db.enabled then C.RestoreStock("UIErrorsFrame") end
end)

C.RegisterPart({
	key = "errors",
	name = "Stock error messages",
	note = "The game's original red errors, yellow notices and colored system messages. Turn it off to compare without them; use Move frames to reposition it.",
	get = function() return db and db.enabled end,
	set = function(on)
		if not db then return end
		db.enabled = on and true or false
		Apply()
	end,
})
