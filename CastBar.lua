local DEFAULT_SCALE = 1
local MIN_SCALE = 0.5
local MAX_SCALE = 3
local CAST_BAR_WIDTH = 150
local CAST_BAR_HEIGHT = 10
local MIN_WIDTH = 100
local MAX_WIDTH = 400
local controllers = {}
local settingsCategory
local minimapButton

local VALID_ANCHOR_POINTS = {
	BOTTOM = true,
	BOTTOMLEFT = true,
	BOTTOMRIGHT = true,
	CENTER = true,
	LEFT = true,
	RIGHT = true,
	TOP = true,
	TOPLEFT = true,
	TOPRIGHT = true,
}

local function IsNumber(value)
	return type(value) == "number" and value == value
end

local function ClampScale(value)
	value = tonumber(value) or DEFAULT_SCALE
	return math.max(MIN_SCALE, math.min(MAX_SCALE, value))
end

local function ClampWidth(value)
	value = tonumber(value) or CAST_BAR_WIDTH
	return math.max(MIN_WIDTH, math.min(MAX_WIDTH, value))
end

local function GetCurrentPosition(castBar)
	local x, y = castBar:GetCenter()
	local parentX, parentY = UIParent:GetCenter()

	if x and y and parentX and parentY then
		return "CENTER", x - parentX, y - parentY
	end

	return "CENTER", 0, -40
end

local function InitializeDatabase(castBar, database)
	local databaseIsValid = type(database) == "table"
		and VALID_ANCHOR_POINTS[database.point]
		and IsNumber(database.x)
		and IsNumber(database.y)
		and VALID_ANCHOR_POINTS[database.defaultPoint]
		and IsNumber(database.defaultX)
		and IsNumber(database.defaultY)

	if databaseIsValid then
		database.scale = ClampScale(database.scale)
		database.width = ClampWidth(database.width)
		return database
	end

	local point, x, y = GetCurrentPosition(castBar)
	return {
		point = point,
		x = x,
		y = y,
		scale = DEFAULT_SCALE,
		width = CAST_BAR_WIDTH,
		defaultPoint = point,
		defaultX = x,
		defaultY = y,
	}
end

local function CreateCastBarTweaksController(editMode, castBar, database, displayName)
	local mover = CreateFrame("Frame", nil, UIParent)
	mover:SetSize(database.width, CAST_BAR_HEIGHT)
	mover:SetFrameStrata("MEDIUM")
	mover:Hide()
	local preview = CreateFrame("StatusBar", nil, UIParent)
	preview:SetSize(database.width, 20)
	local castTexture = castBar:GetStatusBarTexture()
	preview:SetStatusBarTexture(castTexture and castTexture:GetTexture() or "Interface/TargetingFrame/UI-StatusBar")
	preview:SetStatusBarColor(0.95, 0.65, 0.15)
	preview:SetMinMaxValues(0, 1)
	preview:SetValue(0.7)
	preview:SetFrameStrata("HIGH")
	preview:EnableMouse(true)
	preview:SetMovable(true)
	preview:RegisterForDrag("LeftButton")
	preview:Hide()
	local previewBackground = preview:CreateTexture(nil, "BACKGROUND")
	previewBackground:SetAllPoints()
	previewBackground:SetAtlas("ui-castingbar-background")
	local previewBorder = preview:CreateTexture(nil, "OVERLAY")
	previewBorder:SetAtlas("ui-castingbar-frame")
	previewBorder:SetPoint("TOPLEFT", preview, "TOPLEFT", -1, 2)
	previewBorder:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", 1, -2)
	local previewIcon = preview:CreateTexture(nil, "ARTWORK")
	previewIcon:SetSize(20, 20)
	previewIcon:SetPoint("RIGHT", preview, "LEFT", -2, -5)
	previewIcon:SetTexture(castBar.Icon and castBar.Icon:GetTexture() or "Interface\\Icons\\Spell_Nature_Slow")
	local previewText = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	previewText:SetPoint("CENTER")
	previewText:SetText(displayName .. " preview")

	local applyingSettings = false

	local function ApplySettings()
		mover:SetWidth(database.width)
		mover:ClearAllPoints()
		mover:SetPoint(database.point, UIParent, database.point, database.x, database.y)
		mover:SetScale(database.scale)

		applyingSettings = true
		-- The small FocusFrame has a 0.75 effective scale. Compensate locally so
		-- the cast bar's effective screen scale matches its UIParent-owned mover
		-- without changing the native child/parent scaling relationship.
		local parentScale = castBar:GetParent():GetEffectiveScale() / UIParent:GetEffectiveScale()
		castBar:ClearAllPoints()
		castBar:SetPoint(database.point, UIParent, database.point, database.x, database.y)
		castBar:SetWidth(database.width)
		castBar:SetScale(database.scale / parentScale)
		applyingSettings = false
		preview:ClearAllPoints()
		preview:SetPoint(database.point, UIParent, database.point, database.x, database.y)
		preview:SetWidth(database.width)
		preview:SetScale(database.scale)
		preview:SetShown(gsCastBarTweaksDB and gsCastBarTweaksDB.showPreview)
	end

	preview:SetScript("OnDragStart", function(self)
		if not InCombatLockdown() then
			self:StartMoving()
		end
	end)
	preview:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local previewX, previewY = self:GetCenter()
		local parentX, parentY = UIParent:GetCenter()
		if previewX and previewY and parentX and parentY then
			database.point = "CENTER"
			database.x = previewX - parentX
			database.y = previewY - parentY
			ApplySettings()
		end
	end)
	preview:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(displayName .. " preview")
		GameTooltip:AddLine("Drag to position this cast bar.", 1, 1, 1)
		GameTooltip:Show()
	end)
	preview:SetScript("OnLeave", GameTooltip_Hide)

	controllers[displayName] = {
		apply = ApplySettings,
	}

	-- Several Blizzard code paths position the cast bar directly instead of going
	-- through AdjustPosition. Reapply after every external anchor or scale change.
	-- Keep enforcing the saved layout during combat as well.
	local function OnNativeLayoutChanged()
		if not applyingSettings then
			ApplySettings()
		end
	end

	hooksecurefunc(castBar, "SetPoint", OnNativeLayoutChanged)
	hooksecurefunc(castBar, "SetScale", OnNativeLayoutChanged)

	local function SavePosition(_, _, point, x, y)
		database.point = point
		database.x = x
		database.y = y
		ApplySettings()
	end

	local defaultPosition = {
		point = database.defaultPoint,
		x = database.defaultX,
		y = database.defaultY,
	}

	editMode:AddFrame(mover, SavePosition, defaultPosition, displayName)
	editMode:AddFrameSettings(mover, {
		{
			name = "Scale",
			kind = editMode.SettingType.Slider,
			default = DEFAULT_SCALE,
			get = function()
				return database.scale
			end,
			set = function(_, value)
				database.scale = ClampScale(value)
				ApplySettings()
			end,
			minValue = MIN_SCALE,
			maxValue = MAX_SCALE,
			valueStep = 0.05,
			formatter = function(value)
				return FormatPercentage(value, true)
			end,
		},
		{
			name = "Horizontal position",
			kind = editMode.SettingType.Slider,
			default = defaultPosition.x,
			get = function()
				return database.x
			end,
			set = function(_, value)
				database.x = value
				ApplySettings()
			end,
			minValue = -2000,
			maxValue = 2000,
			valueStep = 1,
			formatter = function(value)
				return string.format("%.0f", value)
			end,
		},
		{
			name = "Vertical position",
			kind = editMode.SettingType.Slider,
			default = defaultPosition.y,
			get = function()
				return database.y
			end,
			set = function(_, value)
				database.y = value
				ApplySettings()
			end,
			minValue = -2000,
			maxValue = 2000,
			valueStep = 1,
			formatter = function(value)
				return string.format("%.0f", value)
			end,
		},
	})

	editMode:RegisterCallback("enter", function()
		mover:Show()
	end)
	editMode:RegisterCallback("exit", function()
		mover:Hide()
	end)

	ApplySettings()
end

local function CreatePositionSetting(category, variable, key, name, database, apply)
	local setting = Settings.RegisterAddOnSetting(category, variable, key, database, Settings.VarType.Number, name, database[key])
	setting:SetValueChangedCallback(function()
		apply()
	end)
	local options = Settings.CreateSliderOptions(-2000, 2000, 1)
	Settings.CreateSlider(category, setting, options, name)
end

local function CreateCastBarSettings(category, name, database)
	if not database then
		return
	end

	local apply = function()
		local controller = controllers[name]
		if controller then
			controller.apply()
		end
	end
	local prefix = "GSCASTBARTWEAKS_" .. string.upper(name:gsub(" ", "_"))
	local scaleName = name .. " scale"
	local scale = Settings.RegisterAddOnSetting(category, prefix .. "_SCALE", "scale", database, Settings.VarType.Number, scaleName, DEFAULT_SCALE)
	scale:SetValueChangedCallback(function()
		database.scale = ClampScale(database.scale)
		apply()
	end)
	local scaleOptions = Settings.CreateSliderOptions(MIN_SCALE, MAX_SCALE, 0.05)
	Settings.CreateSlider(category, scale, scaleOptions, scaleName)
	local widthName = name .. " width"
	local width = Settings.RegisterAddOnSetting(category, prefix .. "_WIDTH", "width", database, Settings.VarType.Number, widthName, CAST_BAR_WIDTH)
	width:SetValueChangedCallback(function()
		database.width = ClampWidth(database.width)
		apply()
	end)
	local widthOptions = Settings.CreateSliderOptions(MIN_WIDTH, MAX_WIDTH, 1)
	Settings.CreateSlider(category, width, widthOptions, widthName)
	CreatePositionSetting(category, prefix .. "_X", "x", name .. " horizontal position", database, apply)
	CreatePositionSetting(category, prefix .. "_Y", "y", name .. " vertical position", database, apply)
end

local function UpdatePreviews()
	for _, controller in pairs(controllers) do
		controller.apply()
	end
end

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff4da3ffgsCastBar|r |cffd7e8ffTweaks|r " .. message)
end

local function MatchPlayerCastBar()
	if InCombatLockdown() then
		Print("Leave combat before matching the player cast bar.")
		return
	end

	if not PlayerCastingBarFrame or not gsCastBarTweaksDB or not gsCastBarTweaksFocusDB then
		Print("The player cast bar is not available yet.")
		return
	end

	local playerX, playerY = PlayerCastingBarFrame:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	local parentScale = UIParent:GetEffectiveScale()
	if not playerX or not playerY or not parentX or not parentY or parentScale <= 0 then
		Print("Could not read the player cast bar layout.")
		return
	end

	local scale = ClampScale(PlayerCastingBarFrame:GetEffectiveScale() / parentScale)
	local width = ClampWidth(PlayerCastingBarFrame:GetWidth())
	for _, database in ipairs({ gsCastBarTweaksDB, gsCastBarTweaksFocusDB }) do
		database.point = "CENTER"
		database.x = playerX - parentX
		database.y = playerY - parentY
		database.scale = scale
		database.width = width
	end
	UpdatePreviews()
	Print("Matched the player cast bar layout and size.")
end

local function RegisterSettings()
	if settingsCategory or not Settings then
		return
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("gsCastBarTweaks")
	CreateCastBarSettings(category, "Target Cast Bar", gsCastBarTweaksDB)
	CreateCastBarSettings(category, "Focus Cast Bar", gsCastBarTweaksFocusDB)
	layout:AddInitializer(CreateSettingsButtonInitializer("Match Player Cast Bar", "Match Player Cast Bar", MatchPlayerCastBar, "Copies the current Blizzard player cast bar position, scale, and width to target and focus cast bars.", true))
	local preview = Settings.RegisterAddOnSetting(category, "GSCASTBARTWEAKS_SHOW_PREVIEW", "showPreview", gsCastBarTweaksDB, Settings.VarType.Boolean, "Show positioning previews", false)
	preview:SetValueChangedCallback(UpdatePreviews)
	Settings.CreateCheckbox(category, preview, "Shows target and focus cast-bar previews while positioning them.")
	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
end

local function OpenSettings()
	if settingsCategory and Settings then
		Settings.OpenToCategory(settingsCategory:GetID())
	end
end

local function UpdateMinimapButtonPosition()
	local angle = math.rad(gsCastBarTweaksDB.minimapAngle or 225)
	local radius = 80
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function CreateMinimapButton()
	if minimapButton or not Minimap then
		return
	end

	minimapButton = CreateFrame("Button", "gsCastBarTweaksMinimapButton", Minimap)
	minimapButton:SetSize(36, 36)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:RegisterForDrag("LeftButton")
	local background = minimapButton:CreateTexture(nil, "BACKGROUND")
	background:SetSize(30, 30)
	background:SetPoint("CENTER")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	local icon = minimapButton:CreateTexture(nil, "ARTWORK")
	icon:SetSize(26, 26)
	icon:SetPoint("CENTER")
	icon:SetTexture("Interface\\Icons\\Spell_Nature_Slow")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	minimapButton.icon = icon
	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	minimapButton:SetScript("OnClick", OpenSettings)
	minimapButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("gsCastBarTweaks")
		GameTooltip:AddLine("Left-click to open options.", 1, 1, 1)
		GameTooltip:AddLine("Drag to move this button.", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	minimapButton:SetScript("OnLeave", GameTooltip_Hide)
	minimapButton:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then
			return
		end

		self:SetScript("OnUpdate", function()
			local cursorX, cursorY = GetCursorPosition()
			local minimapX, minimapY = Minimap:GetCenter()
			local scale = Minimap:GetEffectiveScale()
			local offsetX = cursorX / scale - minimapX
			local offsetY = cursorY / scale - minimapY
			gsCastBarTweaksDB.minimapAngle = math.deg(math.atan2(offsetY, offsetX))
			UpdateMinimapButtonPosition()
		end)
	end)
	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	UpdateMinimapButtonPosition()
end

local function SeparateDefaultOverlaps()
	if not gsCastBarTweaksDB or not gsCastBarTweaksFocusDB or gsCastBarTweaksDB.layoutVersion then
		return
	end

	if gsCastBarTweaksDB.point == gsCastBarTweaksFocusDB.point and gsCastBarTweaksDB.x == gsCastBarTweaksFocusDB.x and gsCastBarTweaksDB.y == gsCastBarTweaksFocusDB.y then
		gsCastBarTweaksFocusDB.y = gsCastBarTweaksFocusDB.y + 24
	end

	gsCastBarTweaksDB.layoutVersion = 1
	gsCastBarTweaksFocusDB.layoutVersion = 1
end

EventUtil.ContinueOnPlayerLogin(function()
	local targetCastBar = TargetFrame and TargetFrame.spellbar
	local editMode = LibStub("LibEditMode")

	if targetCastBar then
		gsCastBarTweaksDB = InitializeDatabase(targetCastBar, gsCastBarTweaksDB)
		CreateCastBarTweaksController(editMode, targetCastBar, gsCastBarTweaksDB, "Target Cast Bar")
	end

	local focusCastBar = FocusFrame and FocusFrame.spellbar
	if focusCastBar then
		gsCastBarTweaksFocusDB = InitializeDatabase(focusCastBar, gsCastBarTweaksFocusDB)
		SeparateDefaultOverlaps()
		CreateCastBarTweaksController(editMode, focusCastBar, gsCastBarTweaksFocusDB, "Focus Cast Bar")
	end

	RegisterSettings()
	CreateMinimapButton()
	Print("loaded. Configure target and focus bars in Settings.")
end)
