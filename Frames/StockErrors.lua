-- Arcane UI: the game's own error/notification feed, with Arcane's shared panel treatment.
-- The stock frame keeps its original events and message text; Arcane owns only its shell,
-- default placement, saved movement, visibility switch and theme color.
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
		-- Center on the game's "Move to Begin" prompt.
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end)
	deco = C.Panel(frame, false)
	Theme()

	-- In 1.12, gameplay notices of every kind reach this MessageFrame through AddMessage:
	-- UI_ERROR_MESSAGE, UI_INFO_MESSAGE, SYSMSG and direct FrameXML AddMessage calls.
	-- The red/yellow event colors are not Lua-error classification; actual Lua errors
	-- use the separate script-error window. Recolor only the line, keeping its text and
	-- native display duration/queue behavior unchanged.
	local nativeAddMessage = frame.AddMessage
	if type(nativeAddMessage) == "function" then
		frame.AddMessage = function(self, message, red, green, blue, alpha)
			local title = C.Pal().title
			return nativeAddMessage(self, message, title[1], title[2], title[3], alpha or 1)
		end
	end

	-- Refresh the panel shell when the shared Arcane palette changes.
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
	note = "The game's original gameplay messages, themed to Arcane. Turn it off to compare without them; use Move frames to reposition it.",
	get = function() return db and db.enabled end,
	set = function(on)
		if not db then return end
		db.enabled = on and true or false
		Apply()
	end,
})
