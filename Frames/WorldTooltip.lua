-- Suppress the game's persistent world-hover information panel.
-- World unit/corpse/GameObject tooltips are owned by UIParent and default-anchor into
-- the bottom-right corner. Tooltips owned by actual UI controls remain untouched.
local C = Arcane

local function HideWorldTooltip()
	local tip = GameTooltip
	if not tip or not tip.IsShown or not tip:IsShown() then return end
	if type(tip.GetOwner) ~= "function" then return end
	if tip:GetOwner() == UIParent then tip:Hide() end
end

local function ChainScript(frame, scriptName, after)
	if not frame or type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function" then
		return false
	end
	local previous = frame:GetScript(scriptName)
	frame:SetScript(scriptName, function()
		if previous then previous() end
		after()
	end)
	return true
end

C.OnInit(function()
	if not GameTooltip or not UIParent then return end

	-- This runs when FrameXML chooses the world/default anchor, before it fills the lines.
	ChainScript(GameTooltip, "OnTooltipSetDefaultAnchor", HideWorldTooltip)

	-- Fallback for cursor-seated world objects which use SetOwner(UIParent, ANCHOR_CURSOR)
	-- without firing OnTooltipSetDefaultAnchor.
	ChainScript(GameTooltip, "OnShow", HideWorldTooltip)

	-- Also catches a world-owned tooltip that changes owner while already shown, or another
	-- addon that calls Show() again after the first hide. One cheap owner check; no UI traversal.
	local guard = CreateFrame("Frame", "ArcaneWorldTooltipGuard")
	guard:SetScript("OnUpdate", HideWorldTooltip)
end)
