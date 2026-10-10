--[[
	AIM ASSIST + MENU v3   (LocalScript)
	Put in: StarterPlayer > StarterPlayerScripts

	Desktop : RightShift opens/closes the menu, Insert = power on/off
	Mobile  : tap the floating "AA" bubble to open the menu, hold the on-screen AIM button to aim
	Gamepad : hold L2 to aim (rebindable)

	Menu    : black + rounded, draggable, minimize (-) to a floating bubble,
	          collapse (^) to a slim title bar, built-in Guide tab (?),
	          every setting has a slider / toggle / dropdown / keybind / color picker.
	          Profiles tab = presets, session slots, export / import as text.

	Built as an aim-assist system for YOUR OWN Roblox game
	(controller/mobile-style assist, practice ranges, etc).
	Works best with first-person / shooter-style cameras.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local IS_TOUCH = UserInputService.TouchEnabled
local IS_PHONE = IS_TOUCH and not UserInputService.KeyboardEnabled

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local DEFAULTS = {
	-- General / Input
	Enabled = true,
	AimMode = "Hold",                 -- Hold / Toggle / Always
	AimKey = Enum.UserInputType.MouseButton2,
	AimKeyAlt = Enum.KeyCode.ButtonL2,
	CycleKey = Enum.KeyCode.Q,
	PowerKey = Enum.KeyCode.Insert,
	MenuKey = Enum.KeyCode.RightShift,

	-- Aim feel
	Smoothness = 35,
	PullCurve = "Constant",           -- Constant / Ramp Up / Ramp Down / Smooth
	MaxSpeed = 360,
	Deadzone = 0.4,
	HorizontalStrength = 100,
	VerticalStrength = 100,
	Humanize = 20,
	HumanizeSpeed = 100,
	Magnetism = 50,
	MagnetRadius = 100,
	DistanceFalloff = 0,
	RequireLooking = false,
	LookGrace = 0.25,
	AimPart = "Head",                 -- Head / Torso / Root / Closest
	PartOffset = 0,

	-- Targeting
	FOV = 160,
	FOVFollowMouse = false,
	FOVOffsetX = 0,
	FOVOffsetY = 0,
	MaxDistance = 500,
	MinDistance = 0,
	Priority = "Crosshair",           -- Crosshair / Distance / Lowest Health / Highest Health
	TeamCheck = true,
	WallCheck = true,
	WallIgnoreSoft = true,
	IgnoreFriends = false,
	IgnoreForceField = true,
	MinHealth = 0,
	TargetNPCs = false,
	NPCRefresh = 1,
	IgnoreList = "",
	Sticky = true,
	StickyFOVScale = 130,
	SwitchDelay = 0.25,
	LostGrace = 0.15,

	-- Prediction
	Prediction = true,
	ProjectileSpeed = 800,
	PredictionStrength = 100,
	UseMeasuredVelocity = true,
	VelocitySmoothing = 0.12,
	BulletDrop = false,
	GravityMultiplier = 100,

	-- Visuals
	ShowFOV = true,
	FOVColor = Color3.fromRGB(120, 170, 255),
	FOVThickness = 1.5,
	FOVTransparency = 0.25,
	FOVFill = false,
	FOVFillTransparency = 0.9,
	ShowDot = false,
	DotSize = 4,
	DotColor = Color3.fromRGB(255, 255, 255),
	ShowSnapLine = false,
	SnapLineColor = Color3.fromRGB(120, 170, 255),
	SnapLineThickness = 1.5,
	ShowHighlight = true,
	HighlightFillColor = Color3.fromRGB(120, 170, 255),
	HighlightFillTransparency = 0.7,
	HighlightOutlineColor = Color3.fromRGB(255, 255, 255),
	HighlightOutlineTransparency = 0,
	HighlightAlwaysOnTop = true,
	ShowHUD = true,
	HUDPosition = "Top",              -- Top / Bottom
	HUDScale = 100,

	-- Mobile
	MobileButton = IS_TOUCH,
	MobileButtonSize = 76,
	MobileButtonX = 88,
	MobileButtonY = 62,
	MobileButtonOpacity = 70,

	-- UI
	UIScale = IS_PHONE and 80 or 100,
	UIOpacity = 100,
	AccentColor = Color3.fromRGB(110, 150, 255),
	BubbleAlways = false,
	BubbleSize = 44,
	BubbleOpacity = 90,
	Toasts = true,
}

local Config = {}
for k, v in pairs(DEFAULTS) do Config[k] = v end

local PRESET_ORDER = {"Legit", "Balanced", "Strong", "Controller", "Mobile Friendly", "Sniper", "Close Quarters"}
local PRESETS = {
	["Legit"] = {Smoothness = 15, MaxSpeed = 180, Humanize = 60, FOV = 110, Magnetism = 25, AimPart = "Torso", Sticky = false, PullCurve = "Ramp Down", RequireLooking = true},
	["Balanced"] = {Smoothness = 35, MaxSpeed = 360, Humanize = 20, FOV = 160, Magnetism = 50, AimPart = "Head", Sticky = true, PullCurve = "Constant", RequireLooking = false},
	["Strong"] = {Smoothness = 75, MaxSpeed = 720, Humanize = 5, FOV = 260, Magnetism = 80, AimPart = "Head", Sticky = true},
	["Controller"] = {Smoothness = 25, MaxSpeed = 240, Humanize = 0, FOV = 200, Magnetism = 70, AimPart = "Torso", AimMode = "Always", RequireLooking = true, PullCurve = "Smooth"},
	["Mobile Friendly"] = {Smoothness = 40, MaxSpeed = 300, FOV = 220, Magnetism = 70, Sticky = true, AimMode = "Hold", MobileButton = true, Humanize = 10},
	["Sniper"] = {Smoothness = 20, MaxSpeed = 120, FOV = 80, Prediction = true, ProjectileSpeed = 2000, BulletDrop = true, AimPart = "Head", Humanize = 0, MaxDistance = 1500},
	["Close Quarters"] = {Smoothness = 60, FOV = 300, MaxDistance = 120, AimPart = "Torso", Magnetism = 60, BulletDrop = false},
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local weakK = {__mode = "k"}
local State = {
	Target = nil,
	LockTime = 0,
	LastSeen = 0,
	LastAimPos = nil,
	ToggleOn = false,
	TouchHeld = false,
	TouchInput = nil,
	Listening = nil,
	MenuOpen = true,
	Collapsed = false,
	HideAll = false,
	CurrentTab = "Aim",
	Skip = setmetatable({}, weakK),
	Vel = setmetatable({}, weakK),
	LastPos = setmetatable({}, weakK),
	NPCs = {},
	NPCStamp = 0,
	IgnoreRaw = nil,
	IgnoreSet = {},
	PrevLook = nil,
	LastLookMove = 0,
	LastVS = Vector2.zero,
}
local Controls = {}   -- key -> {refresh = fn}
local Hooks = {}      -- key -> fn fired when that setting changes

local function changed(key)
	if Hooks[key] then Hooks[key]() end
end

----------------------------------------------------------------
-- UTIL
----------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function wrapAngle(a) return (a + math.pi) % (2 * math.pi) - math.pi end
local function fmt(v) return string.format("%g", v) end

local function isBindDown(bind)
	if not bind or bind == Enum.KeyCode.Unknown then return false end
	if bind.EnumType == Enum.KeyCode then
		if string.sub(bind.Name, 1, 6) == "Button" then
			return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, bind)
		end
		return UserInputService:IsKeyDown(bind)
	end
	if bind == Enum.UserInputType.Touch then return false end
	return UserInputService:IsMouseButtonPressed(bind)
end

local function bindMatches(input, bind)
	if not bind or bind == Enum.KeyCode.Unknown then return false end
	if bind.EnumType == Enum.KeyCode then return input.KeyCode == bind end
	return input.UserInputType == bind
end

----------------------------------------------------------------
-- SERIALIZATION (export / import / profile slots)
----------------------------------------------------------------
local function encodeConfig()
	local out = {}
	for k, v in pairs(Config) do
		local t = typeof(v)
		if t == "EnumItem" then
			out[k] = {__enum = (tostring(v.EnumType):gsub("Enum%.", "")), name = v.Name}
		elseif t == "Color3" then
			out[k] = {__color = {math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5)}}
		else
			out[k] = v
		end
	end
	return out
end

local function decodeValue(v)
	if type(v) == "table" then
		if v.__enum then
			local ok, item = pcall(function() return Enum[v.__enum][v.name] end)
			if ok then return item end
			return nil
		elseif v.__color then
			return Color3.fromRGB(v.__color[1] or 0, v.__color[2] or 0, v.__color[3] or 0)
		end
		return nil
	end
	return v
end

local function applyConfigTable(tbl, fireHooks)
	for k, raw in pairs(tbl) do
		if DEFAULTS[k] ~= nil then
			local v = decodeValue(raw)
			if v ~= nil and typeof(v) == typeof(DEFAULTS[k]) then
				Config[k] = v
			end
		end
	end
end

----------------------------------------------------------------
-- TARGETING
----------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function isVisible(part, char)
	local ignore = {Camera}
	if LocalPlayer.Character then ignore[#ignore + 1] = LocalPlayer.Character end
	local origin = Camera.CFrame.Position
	local goal = part.Position
	for _ = 1, 6 do
		rayParams.FilterDescendantsInstances = ignore
		local res = workspace:Raycast(origin, goal - origin, rayParams)
		if not res then return true end
		local hit = res.Instance
		if hit:IsDescendantOf(char) then return true end
		if Config.WallIgnoreSoft and (hit.Transparency >= 0.5 or not hit.CanCollide) then
			ignore[#ignore + 1] = hit
		else
			return false
		end
	end
	return false
end

local function getAimPart(char, ref)
	local mode = Config.AimPart
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local root = char:FindFirstChild("HumanoidRootPart")
	if mode == "Head" then return head or root
	elseif mode == "Torso" then return torso or root
	elseif mode == "Root" then return root
	end
	local best, bestD = nil, math.huge
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local v, on = Camera:WorldToViewportPoint(p.Position)
			if on then
				local d = (Vector2.new(v.X, v.Y) - ref).Magnitude
				if d < bestD then best, bestD = p, d end
			end
		end
	end
	return best or root
end

local function getReference()
	local base
	if Config.FOVFollowMouse then
		base = UserInputService:GetMouseLocation()
	else
		base = Camera.ViewportSize / 2
	end
	return base + Vector2.new(Config.FOVOffsetX, Config.FOVOffsetY)
end

local function rebuildIgnore()
	if State.IgnoreRaw == Config.IgnoreList then return end
	State.IgnoreRaw = Config.IgnoreList
	State.IgnoreSet = {}
	for name in string.gmatch(Config.IgnoreList, "[^,]+") do
		name = string.lower((string.gsub(name, "^%s*(.-)%s*$", "%1")))
		if name ~= "" then State.IgnoreSet[name] = true end
	end
end

local function refreshNPCs()
	local now = os.clock()
	if now - State.NPCStamp < Config.NPCRefresh then return end
	State.NPCStamp = now
	local list = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Humanoid") then
			local m = d.Parent
			if m and m:IsA("Model") and m ~= LocalPlayer.Character and not Players:GetPlayerFromCharacter(m) then
				list[#list + 1] = m
			end
		end
	end
	State.NPCs = list
end

local function getCandidates()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			list[#list + 1] = {Key = plr, Player = plr, Char = plr.Character, Name = plr.DisplayName}
		end
	end
	if Config.TargetNPCs then
		refreshNPCs()
		for _, m in ipairs(State.NPCs) do
			if m.Parent then list[#list + 1] = {Key = m, Char = m, Name = m.Name} end
		end
	end
	return list
end

local function updateVelocities(dt, cands)
	if dt <= 0 then return end
	local a = clamp(dt / (Config.VelocitySmoothing + dt), 0, 1)
	for _, c in ipairs(cands) do
		local root = c.Char:FindFirstChild("HumanoidRootPart")
		if root then
			local last = State.LastPos[c.Key]
			if last then
				local v = (root.Position - last) / dt
				if v.Magnitude < 400 then
					local old = State.Vel[c.Key] or v
					State.Vel[c.Key] = old:Lerp(v, a)
				else
					State.Vel[c.Key] = Vector3.zero
				end
			end
			State.LastPos[c.Key] = root.Position
		end
	end
end

local function validate(c, fovRadius, ref)
	local char = c.Char
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or hum.Health < Config.MinHealth then return nil end

	local nameL = string.lower(c.Name)
	if State.IgnoreSet[nameL] then return nil end
	if c.Player then
		if State.IgnoreSet[string.lower(c.Player.Name)] then return nil end
		if Config.TeamCheck and c.Player.Team and c.Player.Team == LocalPlayer.Team then return nil end
		if Config.IgnoreFriends and LocalPlayer:IsFriendsWith(c.Player.UserId) then return nil end
	end
	if Config.IgnoreForceField and char:FindFirstChildOfClass("ForceField") then return nil end

	local part = getAimPart(char, ref)
	if not part then return nil end
	local dist = (part.Position - Camera.CFrame.Position).Magnitude
	if dist > Config.MaxDistance or dist < Config.MinDistance then return nil end

	local v, on = Camera:WorldToViewportPoint(part.Position)
	if not on then return nil end
	local sp = Vector2.new(v.X, v.Y)
	local sd = (sp - ref).Magnitude
	if sd > fovRadius then return nil end

	if Config.WallCheck and not isVisible(part, char) then return nil end

	return {Cand = c, Key = c.Key, Name = c.Name, Part = part, Screen = sd, ScreenPos = sp, Dist = dist, Health = hum.Health, MaxHealth = hum.MaxHealth}
end

local function findTarget(cands, ref)
	local now = os.clock()

	-- keep current target?
	local cur = State.Target
	if cur then
		local keep = Config.Sticky or (now - State.LockTime) < Config.SwitchDelay
		if keep and not (State.Skip[cur] and State.Skip[cur] > now) then
			for _, c in ipairs(cands) do
				if c.Key == cur then
					local scale = Config.Sticky and (Config.StickyFOVScale / 100) or 1
					local info = validate(c, Config.FOV * scale, ref)
					if info then return info end
					break
				end
			end
		end
	end

	local best, bestScore = nil, math.huge
	for _, c in ipairs(cands) do
		if not (State.Skip[c.Key] and State.Skip[c.Key] > now) then
			local info = validate(c, Config.FOV, ref)
			if info then
				local score
				local p = Config.Priority
				if p == "Distance" then score = info.Dist
				elseif p == "Lowest Health" then score = info.Health
				elseif p == "Highest Health" then score = -info.Health
				else score = info.Screen end
				if score < bestScore then best, bestScore = info, score end
			end
		end
	end

	if best and best.Key ~= State.Target then
		State.Target = best.Key
		State.LockTime = now
	end
	return best
end

----------------------------------------------------------------
-- AIM LOGIC
----------------------------------------------------------------
local function computeAimPos(info)
	local part = info.Part
	local pos = part.Position + Vector3.new(0, Config.PartOffset, 0)
	if Config.Prediction and Config.ProjectileSpeed > 0 then
		local t = info.Dist / Config.ProjectileSpeed
		local vel = part.AssemblyLinearVelocity
		if Config.UseMeasuredVelocity and State.Vel[info.Key] then vel = State.Vel[info.Key] end
		pos = pos + vel * t * (Config.PredictionStrength / 100)
		if Config.BulletDrop then
			pos = pos + Vector3.new(0, 0.5 * workspace.Gravity * (Config.GravityMultiplier / 100) * t * t, 0)
		end
	end
	if Config.Humanize > 0 then
		local tt = os.clock() * (Config.HumanizeSpeed / 100)
		local amp = (Config.Humanize / 100) * clamp(info.Dist / 80, 0.2, 1.5) * 0.6
		pos = pos + Vector3.new(
			math.noise(tt * 1.7, 0.1) * amp,
			math.noise(tt * 1.3, 5.3) * amp,
			math.noise(tt * 1.9, 9.7) * amp
		)
	end
	return pos
end

local function applyAim(dt, aimPos, screenDist, dist)
	local camCF = Camera.CFrame
	local camPos = camCF.Position
	local look = camCF.LookVector
	local toTarget = aimPos - camPos
	if toTarget.Magnitude < 0.01 then return end
	local desired = toTarget.Unit

	local errDeg = math.deg(math.acos(clamp(look:Dot(desired), -1, 1)))
	if errDeg < Config.Deadzone then return end

	local cy, cp = math.atan2(-look.X, -look.Z), math.asin(clamp(look.Y, -1, 1))
	local ty, tp = math.atan2(-desired.X, -desired.Z), math.asin(clamp(desired.Y, -1, 1))
	local dYaw = wrapAngle(ty - cy)
	local dPitch = tp - cp

	local base = clamp(Config.Smoothness / 100, 0.01, 1)
	local alpha = 1 - (1 - base) ^ (dt * 60)

	-- pull curve
	local e = clamp(errDeg / 30, 0, 1)
	local curve = Config.PullCurve
	if curve == "Ramp Up" then alpha = alpha * (0.3 + 0.7 * e)
	elseif curve == "Ramp Down" then alpha = alpha * (1 - 0.7 * e)
	elseif curve == "Smooth" then alpha = alpha * (e * e * (3 - 2 * e) * 0.8 + 0.2) end

	-- magnetism
	if Config.Magnetism > 0 then
		local radius = math.max(Config.FOV * Config.MagnetRadius / 100, 1)
		local closeness = 1 - clamp(screenDist / radius, 0, 1)
		alpha = alpha * (1 + (Config.Magnetism / 100) * closeness)
	end

	-- distance falloff
	if Config.DistanceFalloff > 0 then
		alpha = alpha * (1 - (Config.DistanceFalloff / 100) * clamp(dist / math.max(Config.MaxDistance, 1), 0, 1))
	end
	alpha = clamp(alpha, 0, 1)

	local sYaw = dYaw * alpha * (Config.HorizontalStrength / 100)
	local sPitch = dPitch * alpha * (Config.VerticalStrength / 100)
	local total = math.sqrt(sYaw * sYaw + sPitch * sPitch)
	local maxStep = math.rad(Config.MaxSpeed) * dt
	if total > maxStep and total > 0 then
		local s = maxStep / total
		sYaw, sPitch = sYaw * s, sPitch * s
	end

	local newPitch = clamp(cp + sPitch, -1.45, 1.45)
	Camera.CFrame = CFrame.new(camPos) * CFrame.fromEulerAnglesYXZ(newPitch, cy + sYaw, 0)
end

local function aimActive()
	if not Config.Enabled then return false end
	if Config.AimMode == "Always" then return true end
	if Config.AimMode == "Toggle" then return State.ToggleOn end
	return isBindDown(Config.AimKey) or isBindDown(Config.AimKeyAlt) or State.TouchHeld
end

----------------------------------------------------------------
-- GUI ROOT
----------------------------------------------------------------
local oldGui = LocalPlayer.PlayerGui:FindFirstChild("AimAssistGui")
if oldGui then oldGui:Destroy() end

local Gui = new("ScreenGui", {
	Name = "AimAssistGui", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50,
}, LocalPlayer.PlayerGui)

local THEME = {
	Bg = Color3.fromRGB(9, 9, 11),
	Panel = Color3.fromRGB(16, 16, 19),
	Item = Color3.fromRGB(25, 25, 30),
	Item2 = Color3.fromRGB(37, 37, 44),
	Accent = Config.AccentColor,
	Text = Color3.fromRGB(240, 240, 245),
	Dim = Color3.fromRGB(145, 145, 158),
	Off = Color3.fromRGB(58, 58, 68),
}

local boundAccent = {}
local function bindAccent(inst, prop)
	boundAccent[#boundAccent + 1] = {inst, prop}
	inst[prop] = THEME.Accent
end

-- Overlay: FOV circle, dot, snap line
local Overlay = new("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false}, Gui)

local FOVCircle = new("Frame", {
	Name = "FOV", Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Config.FOVColor, BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2), Active = false,
}, Overlay)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, FOVCircle)
local FOVStroke = new("UIStroke", {Color = Config.FOVColor, Thickness = Config.FOVThickness, Transparency = Config.FOVTransparency}, FOVCircle)

local Dot = new("Frame", {
	BackgroundColor3 = Config.DotColor, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
	Size = UDim2.fromOffset(4, 4), Visible = false,
}, Overlay)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, Dot)

local SnapLine = new("Frame", {
	BackgroundColor3 = Config.SnapLineColor, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
	Size = UDim2.fromOffset(0, 2), Visible = false,
}, Overlay)

-- HUD
local HUD = new("TextLabel", {
	Name = "HUD", BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.25,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(250, 26), Font = Enum.Font.GothamMedium, TextSize = 13,
	TextColor3 = THEME.Text, Text = "", Visible = false,
}, Overlay)
new("UICorner", {CornerRadius = UDim.new(0, 8)}, HUD)
local HUDScale = new("UIScale", {Scale = 1}, HUD)

-- Highlight
local Highlight = new("Highlight", {Enabled = false}, Camera)

-- Toast
local Toast = new("TextLabel", {
	BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(240, 28), Font = Enum.Font.GothamMedium,
	TextSize = 13, TextColor3 = THEME.Text, Text = "", Visible = false, ZIndex = 20,
}, Gui)
new("UICorner", {CornerRadius = UDim.new(0, 8)}, Toast)
local toastId = 0
local function notify(text)
	if not Config.Toasts then return end
	toastId += 1
	local id = toastId
	Toast.Text = text
	Toast.Size = UDim2.fromOffset(clamp(#text * 7.5 + 40, 160, 440), 28)
	Toast.Visible = true
	task.delay(1.8, function()
		if toastId == id then Toast.Visible = false end
	end)
end

----------------------------------------------------------------
-- UI HELPERS
----------------------------------------------------------------
local function corner(inst, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, inst) end
local function pill(inst) return new("UICorner", {CornerRadius = UDim.new(1, 0)}, inst) end

local function tw(inst, props, t)
	TweenService:Create(inst, TweenInfo.new(t or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function contrast(c)
	local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return l > 0.6 and Color3.fromRGB(12, 12, 14) or Color3.new(1, 1, 1)
end

local orders = setmetatable({}, weakK)
local function nextOrder(page)
	orders[page] = (orders[page] or 0) + 1
	return orders[page]
end

local function friendlyBind(b)
	if b == Enum.UserInputType.MouseButton1 then return "Mouse 1" end
	if b == Enum.UserInputType.MouseButton2 then return "Mouse 2" end
	if b == Enum.UserInputType.MouseButton3 then return "Mouse 3" end
	return b.Name
end

----------------------------------------------------------------
-- SETTINGS API
----------------------------------------------------------------
local applyVisuals = function() end -- replaced once the UI exists

local function refreshControls()
	for _, c in pairs(Controls) do c.refresh() end
end

local function setSetting(key, value)
	Config[key] = value
	changed(key)
	local c = Controls[key]
	if c then c.refresh() end
	applyVisuals()
end

local function refreshAll()
	refreshControls()
	applyVisuals()
end

----------------------------------------------------------------
-- DRAG MANAGER (sliders + window + bubble share this)
----------------------------------------------------------------
local Drag = nil

local function endDrag()
	local d = Drag
	Drag = nil
	if d and d.onEnd then d.onEnd() end
end

local function beginDrag(input, onMove, onEnd)
	if Drag then endDrag() end
	local mine = {input = input, onMove = onMove, onEnd = onEnd}
	Drag = mine
	input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End and Drag == mine then endDrag() end
	end)
end

local function pointerOf(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return UserInputService:GetMouseLocation()
end

local function clampedPos(obj, x, y)
	local vp, sz = Gui.AbsoluteSize, obj.AbsoluteSize
	return UDim2.fromOffset(
		clamp(x, 0, math.max(vp.X - sz.X, 0)),
		clamp(y, 0, math.max(vp.Y - sz.Y, 0))
	)
end

-- drag `target` by grabbing `handle`; a short press without movement counts as a tap
local function attachDrag(handle, target, onTap)
	handle.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		local startPos = target.AbsolutePosition
		local startPointer = pointerOf(input)
		local moved = 0
		if target.Name == "Bubble" then State.BubbleDragged = false end
		beginDrag(input, function(pos)
			local dx, dy = pos.X - startPointer.X, pos.Y - startPointer.Y
			moved = math.max(moved, math.sqrt(dx * dx + dy * dy))
			if moved > 6 then
				if target.Name == "Window" then State.Moved = true end
				if target.Name == "Bubble" then State.BubbleDragged = true end
				target.Position = clampedPos(target, startPos.X + dx, startPos.Y + dy)
			end
		end, function()
			if moved <= 6 and onTap then onTap() end
		end)
	end)
end

----------------------------------------------------------------
-- MOBILE AIM BUTTON
----------------------------------------------------------------
local MobileBtn = new("TextButton", {
	Name = "AimButton", BackgroundColor3 = THEME.Bg, AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -Config.MobileButtonX, 1, -Config.MobileButtonY),
	Size = UDim2.fromOffset(Config.MobileButtonSize, Config.MobileButtonSize),
	Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = THEME.Text, Text = "AIM",
	Visible = Config.MobileButton, ZIndex = 3,
}, Gui)
pill(MobileBtn)
local MobileStroke = new("UIStroke", {Thickness = 2}, MobileBtn)
bindAccent(MobileStroke, "Color")

MobileBtn.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
	if Config.AimMode == "Toggle" then
		State.ToggleOn = not State.ToggleOn
	else
		State.TouchHeld = true
		State.TouchInput = input
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End and State.TouchInput == input then
				State.TouchHeld = false
				State.TouchInput = nil
			end
		end)
	end
end)

----------------------------------------------------------------
-- WINDOW
----------------------------------------------------------------
local WIN_W, WIN_H, TITLE_H, COLLAPSED_W = 540, 372, 42, 330
local windowPanels = {}   -- frames that follow the "Menu Opacity" setting

local Window = new("Frame", {
	Name = "Window", BackgroundColor3 = THEME.Bg, BorderSizePixel = 0,
	Position = UDim2.new(0.5, -WIN_W * Config.UIScale / 200, 0.5, -WIN_H * Config.UIScale / 200),
	Size = UDim2.fromOffset(WIN_W, WIN_H), ClipsDescendants = true, Active = true, ZIndex = 5,
}, Gui)
corner(Window, 16)
new("UIStroke", {Color = THEME.Item2, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, Window)
local WinScale = new("UIScale", {Scale = Config.UIScale / 100}, Window)
windowPanels[#windowPanels + 1] = Window

-- title bar
local TitleBar = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TITLE_H), Active = true}, Window)

local TitleDot = new("Frame", {
	BackgroundColor3 = THEME.Accent, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(8, 8),
}, TitleBar)
pill(TitleDot)
bindAccent(TitleDot, "BackgroundColor3")

new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(0, 130, 1, 0),
	Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
	RichText = true, Text = 'Aim Assist  <font color="#8f8f9e" size="12">v3</font>',
}, TitleBar)

local BtnHolder = new("Frame", {
	BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
}, TitleBar)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
	VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
}, BtnHolder)

local function titleButton(text, w, order)
	local b = new("TextButton", {
		BackgroundColor3 = THEME.Item, AutoButtonColor = true, Size = UDim2.fromOffset(w, 28),
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text, Text = text, LayoutOrder = order,
	}, BtnHolder)
	corner(b, 8)
	return b
end

local PowerBtn = titleButton("ON", 52, 1)
local GuideBtn = titleButton("?", 30, 2)
local CollapseBtn = titleButton("^", 30, 3)
local MinBtn = titleButton("-", 30, 4)

-- body
local Body = new("Frame", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 1, -TITLE_H),
}, Window)

local Sidebar = new("ScrollingFrame", {
	BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 2),
	Size = UDim2.new(0, 128, 1, -12), ScrollBarThickness = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Body)
corner(Sidebar, 12)
new("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, Sidebar)
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, Sidebar)
windowPanels[#windowPanels + 1] = Sidebar

local Content = new("Frame", {
	BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(146, 2),
	Size = UDim2.new(1, -156, 1, -12), ClipsDescendants = true,
}, Body)
corner(Content, 12)
windowPanels[#windowPanels + 1] = Content

-- tabs + pages
local TAB_ORDER = {"Aim", "Targeting", "Prediction", "Visuals", "Input", "Mobile", "Interface", "Profiles", "Guide"}
local Pages, Tabs = {}, {}

local function selectTab(name)
	State.CurrentTab = name
	for n, t in pairs(Tabs) do
		local on = (n == name)
		Pages[n].Visible = on
		t.btn.BackgroundTransparency = on and 0 or 1
		t.btn.TextColor3 = on and THEME.Text or THEME.Dim
		t.bar.Visible = on
	end
end

for i, name in ipairs(TAB_ORDER) do
	local page = new("ScrollingFrame", {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
	}, Content)
	bindAccent(page, "ScrollBarImageColor3")
	new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10)}, page)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, page)
	Pages[name] = page

	local b = new("TextButton", {
		Name = name, BackgroundColor3 = THEME.Item, BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Dim,
		Text = name, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i,
	}, Sidebar)
	corner(b, 8)
	new("UIPadding", {PaddingLeft = UDim.new(0, 14)}, b)
	local bar = new("Frame", {
		BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -9, 0.5, 0), Size = UDim2.fromOffset(3, 14), Visible = false,
	}, b)
	pill(bar)
	bindAccent(bar, "BackgroundColor3")
	b.Activated:Connect(function() selectTab(name) end)
	Tabs[name] = {btn = b, bar = bar}
end

-- bubble (shown when the menu is minimized)
local Bubble = new("TextButton", {
	Name = "Bubble", BackgroundColor3 = THEME.Bg, AutoButtonColor = false,
	Position = UDim2.new(0, 14, 0.38, 0), Size = UDim2.fromOffset(Config.BubbleSize, Config.BubbleSize),
	Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = THEME.Text, Text = "AA", Visible = false, ZIndex = 10,
}, Gui)
corner(Bubble, 10)
local BubbleStroke = new("UIStroke", {Thickness = 2, Color = THEME.Accent}, Bubble)

----------------------------------------------------------------
-- MENU ACTIONS
----------------------------------------------------------------
local function setMenuOpen(open)
	State.MenuOpen = open
	Window.Visible = open
	if open then State.NeedClamp = true end
end

local function setCollapsed(c)
	State.Collapsed = c
	CollapseBtn.Text = c and "v" or "^"
	if c then Body.Visible = false end
	local goal = UDim2.fromOffset(c and COLLAPSED_W or WIN_W, c and TITLE_H or WIN_H)
	local t = TweenService:Create(Window, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = goal})
	t.Completed:Connect(function() State.NeedClamp = true end)
	t:Play()
	if not c then Body.Visible = true end
	State.NeedClamp = true
end

local function centerWindow()
	local vp = Gui.AbsoluteSize
	if vp.X < 100 or vp.Y < 100 then vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or vp end
	local sc = WinScale.Scale
	local w = (State.Collapsed and COLLAPSED_W or WIN_W) * sc
	local h = (State.Collapsed and TITLE_H or WIN_H) * sc
	Window.Position = UDim2.fromOffset(math.max((vp.X - w) / 2, 0), math.max((vp.Y - h) / 2, 0))
	State.Moved = false
end

PowerBtn.Activated:Connect(function()
	setSetting("Enabled", not Config.Enabled)
	notify(Config.Enabled and "Aim assist ON" or "Aim assist OFF")
end)
GuideBtn.Activated:Connect(function()
	if State.Collapsed then setCollapsed(false) end
	selectTab("Guide")
end)
CollapseBtn.Activated:Connect(function() setCollapsed(not State.Collapsed) end)
MinBtn.Activated:Connect(function() setMenuOpen(false) end)

attachDrag(TitleBar, Window, nil)
attachDrag(Bubble, Bubble, function() setMenuOpen(true) end)
Bubble.Activated:Connect(function()
	if not State.BubbleDragged then setMenuOpen(true) end
end)

----------------------------------------------------------------
-- CONTROL BUILDERS
----------------------------------------------------------------
local function baseRow(page, height, class)
	local row = new(class or "Frame", {
		BackgroundColor3 = THEME.Item, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height), LayoutOrder = nextOrder(page),
	}, page)
	corner(row, 10)
	return row
end

local function rowLabel(parent, text, size)
	return new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = size or UDim2.new(1, -24, 1, 0),
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = text,
	}, parent)
end

local function section(page, text)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBold, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(text), LayoutOrder = nextOrder(page),
	}, page)
	bindAccent(l, "TextColor3")
	new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 8)}, l)
end

local function note(page, text)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Dim, TextWrapped = true, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = text, LayoutOrder = nextOrder(page),
	}, page)
	new("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4)}, l)
	return l
end

local function toggle(page, key, label)
	local row = baseRow(page, 38, "TextButton")
	row.Text = ""
	row.AutoButtonColor = false
	rowLabel(row, label, UDim2.new(1, -70, 1, 0))
	local sw = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = THEME.Off, BorderSizePixel = 0,
	}, row)
	pill(sw)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, sw)
	pill(knob)
	local last = nil
	local function refresh()
		local on = Config[key] and true or false
		local goal = on and THEME.Accent or THEME.Off
		local pos = on and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 11, 0.5, 0)
		if last ~= nil and last ~= on then
			tw(sw, {BackgroundColor3 = goal})
			tw(knob, {Position = pos})
		else
			sw.BackgroundColor3 = goal
			knob.Position = pos
		end
		last = on
	end
	Controls[key] = {refresh = refresh}
	row.Activated:Connect(function() setSetting(key, not Config[key]) end)
	refresh()
end

-- generic slider row. o = {label, min, max, step, get, set, scroller, plain}
local function sliderRow(parent, order, o)
	local row = new("Frame", {
		BackgroundColor3 = THEME.Item, BackgroundTransparency = o.plain and 1 or 0, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 50), LayoutOrder = order,
	}, parent)
	if not o.plain then corner(row, 10) end

	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -92, 0, 22),
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = o.label,
	}, row)

	local box = new("TextBox", {
		BackgroundColor3 = THEME.Item2, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(64, 22), Font = Enum.Font.GothamMedium,
		TextSize = 12, TextColor3 = THEME.Text, ClearTextOnFocus = false, Text = "",
	}, row)
	corner(box, 6)

	local hit = new("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 20),
	}, row)
	local track = new("Frame", {
		BackgroundColor3 = THEME.Off, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(1, -24, 0, 6),
	}, hit)
	pill(track)
	local fill = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, track)
	pill(fill)
	bindAccent(fill, "BackgroundColor3")
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
	}, track)
	pill(knob)

	local function refresh()
		local v = o.get()
		local t = clamp((v - o.min) / (o.max - o.min), 0, 1)
		fill.Size = UDim2.fromScale(t, 1)
		knob.Position = UDim2.fromScale(t, 0.5)
		if not box:IsFocused() then box.Text = fmt(v) end
	end

	local function snap(v)
		v = math.floor(v / o.step + 0.5) * o.step
		v = tonumber(string.format("%.4f", v))
		return clamp(v, o.min, o.max)
	end

	local function setFromX(x)
		local t = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		o.set(snap(o.min + t * (o.max - o.min)))
	end

	hit.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
		setFromX(input.Position.X)
		if o.scroller then o.scroller.ScrollingEnabled = false end
		beginDrag(input, function(pos) setFromX(pos.X) end, function()
			if o.scroller then o.scroller.ScrollingEnabled = true end
		end)
	end)

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then o.set(clamp(n, o.min, o.max)) end
		refresh()
	end)

	return row, refresh
end

local function slider(page, key, label, min, max, step)
	local _, refresh = sliderRow(page, nextOrder(page), {
		label = label, min = min, max = max, step = step, scroller = page,
		get = function() return Config[key] end,
		set = function(v) setSetting(key, v) end,
	})
	Controls[key] = {refresh = refresh}
	refresh()
end

local function dropdown(page, key, label, options)
	local row = new("Frame", {
		BackgroundColor3 = THEME.Item, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(page),
	}, page)
	corner(row, 10)
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, row)

	local head = new("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 1,
	}, row)
	rowLabel(head, label, UDim2.new(0.5, -12, 1, 0))
	local valueLbl = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0.5, -12, 1, 0), Font = Enum.Font.GothamBold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, head)
	bindAccent(valueLbl, "TextColor3")

	local list = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false, LayoutOrder = 2,
	}, row)
	new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}, list)

	local optBtns = {}
	for i, opt in ipairs(options) do
		local b = new("TextButton", {
			BackgroundColor3 = THEME.Item2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30),
			Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Text, Text = opt,
			AutoButtonColor = true, LayoutOrder = i,
		}, list)
		corner(b, 8)
		b.Activated:Connect(function()
			setSetting(key, opt)
			list.Visible = false
		end)
		optBtns[opt] = b
	end
	head.Activated:Connect(function() list.Visible = not list.Visible end)

	Controls[key] = {refresh = function()
		valueLbl.Text = tostring(Config[key])
		for opt, b in pairs(optBtns) do
			b.TextColor3 = (Config[key] == opt) and THEME.Accent or THEME.Text
		end
	end}
	Controls[key].refresh()
end

local function keybind(page, key, label)
	local row = baseRow(page, 38)
	rowLabel(row, label, UDim2.new(1, -150, 1, 0))
	local btn = new("TextButton", {
		BackgroundColor3 = THEME.Item2, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(122, 26), Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.Text,
		AutoButtonColor = true, Text = "",
	}, row)
	corner(btn, 7)
	Controls[key] = {refresh = function()
		if State.Listening == key then
			btn.Text = "Press a key..."
			btn.TextColor3 = THEME.Accent
		else
			local b = Config[key]
			btn.Text = (not b or b == Enum.KeyCode.Unknown) and "None" or friendlyBind(b)
			btn.TextColor3 = THEME.Text
		end
	end}
	btn.Activated:Connect(function()
		if State.Listening == key then State.Listening = nil else State.Listening = key end
		refreshControls()
	end)
	Controls[key].refresh()
end

local COLOR_SWATCHES = {
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 185), Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 220, 70), Color3.fromRGB(80, 230, 120),
	Color3.fromRGB(60, 220, 200), Color3.fromRGB(110, 150, 255), Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 110, 190),
}

local function colorRow(page, key, label)
	local row = new("Frame", {
		BackgroundColor3 = THEME.Item, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(page),
	}, page)
	corner(row, 10)
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, row)

	local head = new("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 1,
	}, row)
	rowLabel(head, label, UDim2.new(1, -70, 1, 0))
	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(36, 20),
		BackgroundColor3 = Config[key], BorderSizePixel = 0,
	}, head)
	corner(swatch, 6)
	new("UIStroke", {Color = THEME.Item2, Thickness = 1}, swatch)

	local panel = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false, LayoutOrder = 2,
	}, row)
	new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, panel)
	new("UIPadding", {PaddingBottom = UDim.new(0, 8)}, panel)

	local grid = new("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(panel),
	}, panel)
	new("UIGridLayout", {CellSize = UDim2.fromOffset(26, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6)}, grid)
	for i, c in ipairs(COLOR_SWATCHES) do
		local b = new("TextButton", {BackgroundColor3 = c, Text = "", AutoButtonColor = true, LayoutOrder = i}, grid)
		corner(b, 7)
		b.Activated:Connect(function() setSetting(key, c) end)
	end

	local refreshers = {}
	local chans = {{"Red", "R"}, {"Green", "G"}, {"Blue", "B"}}
	for idx, ch in ipairs(chans) do
		local _, refresh = sliderRow(panel, nextOrder(panel), {
			label = ch[1], min = 0, max = 255, step = 1, plain = true, scroller = page,
			get = function() return math.floor(Config[key][ch[2]] * 255 + 0.5) end,
			set = function(v)
				local c = Config[key]
				local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
				if idx == 1 then r = v elseif idx == 2 then g = v else b = v end
				setSetting(key, Color3.fromRGB(r, g, b))
			end,
		})
		refreshers[#refreshers + 1] = refresh
	end

	head.Activated:Connect(function() panel.Visible = not panel.Visible end)
	Controls[key] = {refresh = function()
		swatch.BackgroundColor3 = Config[key]
		for _, r in ipairs(refreshers) do r() end
	end}
	Controls[key].refresh()
end

local function textbox(page, key, label, placeholder)
	local row = baseRow(page, 38)
	rowLabel(row, label, UDim2.new(0.36, 0, 1, 0))
	local box = new("TextBox", {
		BackgroundColor3 = THEME.Item2, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0.62, -8, 0, 26), Font = Enum.Font.GothamMedium,
		TextSize = 12, TextColor3 = THEME.Text, PlaceholderText = placeholder or "", PlaceholderColor3 = THEME.Dim,
		ClearTextOnFocus = false, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	corner(box, 7)
	new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, box)
	box.FocusLost:Connect(function() setSetting(key, box.Text) end)
	Controls[key] = {refresh = function()
		if not box:IsFocused() then box.Text = tostring(Config[key]) end
	end}
	Controls[key].refresh()
end

local function button(page, text, fn, accent)
	local row = baseRow(page, 36, "TextButton")
	row.Text = text
	row.Font = Enum.Font.GothamMedium
	row.TextSize = 13
	row.TextColor3 = accent and THEME.Accent or THEME.Text
	row.AutoButtonColor = true
	row.Activated:Connect(fn)
	return row
end

local function buttonRow(page, label, buttons)
	local row = baseRow(page, 38)
	rowLabel(row, label, UDim2.new(0.4, 0, 1, 0))
	local holder = new("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
	}, row)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	for i, b in ipairs(buttons) do
		local btn = new("TextButton", {
			BackgroundColor3 = THEME.Item2, Size = UDim2.fromOffset(66, 26), Font = Enum.Font.GothamMedium,
			TextSize = 12, TextColor3 = THEME.Text, Text = b[1], AutoButtonColor = true, LayoutOrder = i,
		}, holder)
		corner(btn, 7)
		btn.Activated:Connect(b[2])
	end
end

-- collapsible text card (used by the Guide tab)
local function guideTopic(page, title, bodyFn)
	local row = new("Frame", {
		BackgroundColor3 = THEME.Item, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(page),
	}, page)
	corner(row, 10)
	new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, row)
	local head = new("TextButton", {
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 1,
	}, row)
	rowLabel(head, title, UDim2.new(1, -50, 1, 0))
	local plus = new("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(20, 38), Font = Enum.Font.GothamBold, TextSize = 16, Text = "+",
	}, head)
	bindAccent(plus, "TextColor3")
	local body = new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = THEME.Dim, TextWrapped = true, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false, LayoutOrder = 2, Text = "",
	}, row)
	new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12)}, body)
	head.Activated:Connect(function()
		body.Visible = not body.Visible
		plus.Text = body.Visible and "-" or "+"
		if body.Visible then body.Text = bodyFn() end
	end)
end

----------------------------------------------------------------
-- ERROR REPORTER (a bug in one tab can no longer stop the whole menu)
----------------------------------------------------------------
local ErrLog = {}
local ErrBtn = new("TextButton", {
	Name = "AimAssistErrors", BackgroundColor3 = Color3.fromRGB(60, 18, 18), AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(0, 460, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y, Font = Enum.Font.Code, TextSize = 12,
	TextColor3 = Color3.fromRGB(255, 190, 190), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, Text = "", Visible = false, ZIndex = 30,
}, Gui)
corner(ErrBtn, 8)
new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, ErrBtn)
ErrBtn.Activated:Connect(function() ErrBtn.Visible = false end)

local function reportError(where, err)
	warn("[AimAssist] " .. where .. ": " .. tostring(err))
	if #ErrLog < 4 then ErrLog[#ErrLog + 1] = where .. ": " .. tostring(err) end
	ErrBtn.Text = "Aim Assist error (tap to hide):\n" .. table.concat(ErrLog, "\n")
	ErrBtn.Visible = true
end

local function safe(where, fn)
	local ok, err = pcall(fn)
	if not ok then reportError(where, err) end
end

----------------------------------------------------------------
-- TAB: AIM
----------------------------------------------------------------
safe("Aim tab", function()
	local P = Pages.Aim
	section(P, "Pull")
	slider(P, "Smoothness", "Smoothness (%)", 1, 100, 1)
	dropdown(P, "PullCurve", "Pull Curve", {"Constant", "Ramp Up", "Ramp Down", "Smooth"})
	slider(P, "MaxSpeed", "Max Turn Speed (deg/s)", 30, 1440, 10)
	slider(P, "Deadzone", "Deadzone (deg)", 0, 10, 0.1)
	slider(P, "HorizontalStrength", "Horizontal Strength (%)", 0, 100, 1)
	slider(P, "VerticalStrength", "Vertical Strength (%)", 0, 100, 1)

	section(P, "Feel")
	slider(P, "Humanize", "Humanize (%)", 0, 100, 1)
	slider(P, "HumanizeSpeed", "Humanize Speed (%)", 10, 300, 5)
	slider(P, "Magnetism", "Magnetism (%)", 0, 100, 1)
	slider(P, "MagnetRadius", "Magnet Radius (% of FOV)", 10, 200, 5)
	slider(P, "DistanceFalloff", "Distance Falloff (%)", 0, 100, 1)

	section(P, "Look gating")
	toggle(P, "RequireLooking", "Only Assist While Looking")
	slider(P, "LookGrace", "Look Grace (sec)", 0.05, 1.5, 0.05)

	section(P, "Aim point")
	dropdown(P, "AimPart", "Aim Part", {"Head", "Torso", "Root", "Closest"})
	slider(P, "PartOffset", "Part Offset (studs)", -3, 3, 0.1)
end)

----------------------------------------------------------------
-- FOV CIRCLE MOVE HANDLE
----------------------------------------------------------------
local FOVHandle = new("TextButton", {
	Name = "FOVHandle", BackgroundColor3 = THEME.Accent, AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32),
	Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Text = "+",
	Visible = false, ZIndex = 8,
}, Gui)
corner(FOVHandle, 8)
new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2}, FOVHandle)
bindAccent(FOVHandle, "BackgroundColor3")
FOVHandle.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	local startPointer = pointerOf(input)
	local sx, sy = Config.FOVOffsetX, Config.FOVOffsetY
	beginDrag(input, function(pos)
		setSetting("FOVOffsetX", clamp(math.floor(sx + pos.X - startPointer.X + 0.5), -1000, 1000))
		setSetting("FOVOffsetY", clamp(math.floor(sy + pos.Y - startPointer.Y + 0.5), -1000, 1000))
	end)
end)

----------------------------------------------------------------
-- TAB: TARGETING
----------------------------------------------------------------
safe("Targeting tab", function()
	local P = Pages.Targeting
	section(P, "Field of view")
	slider(P, "FOV", "FOV Radius (px)", 20, 600, 5)
	toggle(P, "FOVFollowMouse", "FOV Follows Mouse")
	slider(P, "FOVOffsetX", "FOV Center X (px from middle)", -1000, 1000, 1)
	slider(P, "FOVOffsetY", "FOV Center Y (px from middle)", -1000, 1000, 1)
	local moveBtn
	moveBtn = button(P, "Move Circle With Handle: OFF", function()
		State.EditCircle = not State.EditCircle
		moveBtn.Text = "Move Circle With Handle: " .. (State.EditCircle and "ON" or "OFF")
		if State.EditCircle then notify("Drag the + handle to move the circle") end
	end)
	button(P, "Reset Circle To Center", function()
		setSetting("FOVOffsetX", 0)
		setSetting("FOVOffsetY", 0)
	end)

	section(P, "Range & priority")
	slider(P, "MaxDistance", "Max Distance (studs)", 50, 3000, 10)
	slider(P, "MinDistance", "Min Distance (studs)", 0, 200, 1)
	dropdown(P, "Priority", "Target Priority", {"Crosshair", "Distance", "Lowest Health", "Highest Health"})

	section(P, "Filters")
	toggle(P, "TeamCheck", "Team Check")
	toggle(P, "WallCheck", "Wall Check")
	toggle(P, "WallIgnoreSoft", "Ignore Glass / Non-Solid Parts")
	toggle(P, "IgnoreFriends", "Ignore Friends")
	toggle(P, "IgnoreForceField", "Ignore Force Fields")
	slider(P, "MinHealth", "Min Target Health", 0, 100, 1)
	textbox(P, "IgnoreList", "Ignore Names", "name1, name2")

	section(P, "NPCs")
	toggle(P, "TargetNPCs", "Target NPCs")
	slider(P, "NPCRefresh", "NPC Rescan Rate (sec)", 0.25, 5, 0.25)

	section(P, "Lock behavior")
	toggle(P, "Sticky", "Sticky Target")
	slider(P, "StickyFOVScale", "Sticky FOV Scale (%)", 100, 300, 5)
	slider(P, "SwitchDelay", "Switch Delay (sec)", 0, 2, 0.05)
	slider(P, "LostGrace", "Lost Target Grace (sec)", 0, 1, 0.05)
end)

----------------------------------------------------------------
-- TAB: PREDICTION
----------------------------------------------------------------
safe("Prediction tab", function()
	local P = Pages.Prediction
	section(P, "Lead")
	toggle(P, "Prediction", "Movement Prediction")
	slider(P, "ProjectileSpeed", "Projectile Speed (studs/s)", 0, 5000, 50)
	slider(P, "PredictionStrength", "Prediction Strength (%)", 0, 200, 5)
	toggle(P, "UseMeasuredVelocity", "Use Measured Velocity")
	slider(P, "VelocitySmoothing", "Velocity Smoothing (sec)", 0.02, 0.5, 0.01)

	section(P, "Drop")
	toggle(P, "BulletDrop", "Bullet Drop Compensation")
	slider(P, "GravityMultiplier", "Gravity Multiplier (%)", 0, 300, 5)
	note(P, "Projectile Speed 0 turns lead off (instant hit weapons).")
end)

----------------------------------------------------------------
-- TAB: VISUALS
----------------------------------------------------------------
safe("Visuals tab", function()
	local P = Pages.Visuals
	section(P, "FOV circle")
	toggle(P, "ShowFOV", "Show FOV Circle")
	colorRow(P, "FOVColor", "FOV Color")
	slider(P, "FOVThickness", "Thickness", 0.5, 6, 0.5)
	slider(P, "FOVTransparency", "Line Transparency", 0, 1, 0.05)
	toggle(P, "FOVFill", "Fill Circle")
	slider(P, "FOVFillTransparency", "Fill Transparency", 0, 1, 0.05)

	section(P, "Target dot")
	toggle(P, "ShowDot", "Show Aim Dot")
	slider(P, "DotSize", "Dot Size", 2, 16, 1)
	colorRow(P, "DotColor", "Dot Color")

	section(P, "Snap line")
	toggle(P, "ShowSnapLine", "Show Snap Line")
	colorRow(P, "SnapLineColor", "Line Color")
	slider(P, "SnapLineThickness", "Line Thickness", 0.5, 6, 0.5)

	section(P, "Target highlight")
	toggle(P, "ShowHighlight", "Highlight Target")
	colorRow(P, "HighlightFillColor", "Fill Color")
	slider(P, "HighlightFillTransparency", "Fill Transparency", 0, 1, 0.05)
	colorRow(P, "HighlightOutlineColor", "Outline Color")
	slider(P, "HighlightOutlineTransparency", "Outline Transparency", 0, 1, 0.05)
	toggle(P, "HighlightAlwaysOnTop", "Visible Through Walls")

	section(P, "Status HUD")
	toggle(P, "ShowHUD", "Show HUD")
	dropdown(P, "HUDPosition", "HUD Position", {"Top", "Bottom"})
	slider(P, "HUDScale", "HUD Scale (%)", 50, 200, 5)
end)

----------------------------------------------------------------
-- TAB: INPUT
----------------------------------------------------------------
safe("Input tab", function()
	local P = Pages.Input
	section(P, "Aim activation")
	toggle(P, "Enabled", "Aim Assist Enabled")
	dropdown(P, "AimMode", "Aim Mode", {"Hold", "Toggle", "Always"})
	keybind(P, "AimKey", "Aim Key (mouse / keyboard)")
	keybind(P, "AimKeyAlt", "Aim Key (gamepad)")

	section(P, "Shortcuts")
	keybind(P, "CycleKey", "Switch Target")
	keybind(P, "PowerKey", "Power On / Off")
	keybind(P, "MenuKey", "Open / Close Menu")
	note(P, "Tap a key button, then press the new key, right / middle mouse button or gamepad button. Esc cancels, Backspace / Delete clears the bind.")

	section(P, "Feedback")
	toggle(P, "Toasts", "Show Notifications")
end)

----------------------------------------------------------------
-- TAB: MOBILE
----------------------------------------------------------------
safe("Mobile tab", function()
	local P = Pages.Mobile
	section(P, "On-screen aim button")
	toggle(P, "MobileButton", "Show AIM Button")
	slider(P, "MobileButtonSize", "Button Size (px)", 40, 160, 2)
	slider(P, "MobileButtonX", "Distance From Right (px)", 20, 700, 2)
	slider(P, "MobileButtonY", "Distance From Bottom (px)", 20, 500, 2)
	slider(P, "MobileButtonOpacity", "Button Opacity (%)", 10, 100, 5)
	note(P, "Hold the AIM button while aiming. In Toggle mode, tap it once to turn aim on and tap again to turn it off.")
end)

----------------------------------------------------------------
-- TAB: INTERFACE
----------------------------------------------------------------
safe("Interface tab", function()
	local P = Pages.Interface
	section(P, "Menu")
	slider(P, "UIScale", "Menu Scale (%)", 50, 150, 5)
	slider(P, "UIOpacity", "Menu Opacity (%)", 40, 100, 5)
	colorRow(P, "AccentColor", "Accent Color")

	section(P, "Floating bubble")
	toggle(P, "BubbleAlways", "Always Show Bubble")
	slider(P, "BubbleSize", "Bubble Size (px)", 30, 80, 2)
	slider(P, "BubbleOpacity", "Bubble Opacity (%)", 20, 100, 5)

	section(P, "Utilities")
	button(P, "Center Menu On Screen", function()
		setMenuOpen(true)
		centerWindow()
	end)
	button(P, "Hide / Show All Overlays", function()
		State.HideAll = not State.HideAll
		notify(State.HideAll and "Overlays hidden" or "Overlays shown")
	end)
end)

----------------------------------------------------------------
-- TAB: PROFILES
----------------------------------------------------------------
local Slots = {}
safe("Profiles tab", function()
	local P = Pages.Profiles
	section(P, "Presets")
	for _, name in ipairs(PRESET_ORDER) do
		button(P, name, function()
			applyConfigTable(PRESETS[name])
			refreshAll()
			notify("Preset: " .. name)
		end)
	end

	section(P, "Session slots")
	for i = 1, 3 do
		buttonRow(P, "Slot " .. i, {
			{"Save", function()
				local copy = {}
				for k, v in pairs(Config) do copy[k] = v end
				Slots[i] = copy
				notify("Saved to slot " .. i)
			end},
			{"Load", function()
				if not Slots[i] then notify("Slot " .. i .. " is empty") return end
				for k, v in pairs(Slots[i]) do Config[k] = v end
				refreshAll()
				notify("Loaded slot " .. i)
			end},
		})
	end
	note(P, "Slots last until you leave the game. Use Export to keep a setup permanently.")

	section(P, "Export / import")
	local boxRow = baseRow(P, 100)
	local box = new("TextBox", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16),
		Font = Enum.Font.Code, TextSize = 11, TextColor3 = THEME.Text, PlaceholderColor3 = THEME.Dim,
		PlaceholderText = "Press Export to get your settings as text.\nPaste settings text here and press Import to load them.",
		MultiLine = true, TextWrapped = true, ClearTextOnFocus = false, Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	}, boxRow)
	buttonRow(P, "Settings text", {
		{"Export", function()
			local ok, json = pcall(function() return HttpService:JSONEncode(encodeConfig()) end)
			if ok then
				box.Text = json
				notify("Exported - copy the text")
			else
				notify("Export failed")
			end
		end},
		{"Import", function()
			local ok, data = pcall(function() return HttpService:JSONDecode(box.Text) end)
			if ok and type(data) == "table" then
				applyConfigTable(data)
				refreshAll()
				notify("Settings imported")
			else
				notify("That text is not valid settings")
			end
		end},
	})

	section(P, "Reset")
	local resetArmed = 0
	local resetBtn
	resetBtn = button(P, "Reset Everything To Defaults", function()
		if os.clock() - resetArmed < 3 then
			resetArmed = 0
			for k, v in pairs(DEFAULTS) do Config[k] = v end
			State.ToggleOn = false
			resetBtn.Text = "Reset Everything To Defaults"
			refreshAll()
			notify("Settings reset")
		else
			resetArmed = os.clock()
			resetBtn.Text = "Tap again to confirm"
			task.delay(3, function()
				if resetArmed ~= 0 then
					resetArmed = 0
					resetBtn.Text = "Reset Everything To Defaults"
				end
			end)
		end
	end, true)
end)

----------------------------------------------------------------
-- TAB: GUIDE
----------------------------------------------------------------
safe("Guide tab", function()
	local P = Pages.Guide
	local function bn(b)
		if not b or b == Enum.KeyCode.Unknown then return "(unbound)" end
		return friendlyBind(b)
	end

	note(P, "Tap a topic to open it. Tap the number next to any slider to type an exact value.")

	guideTopic(P, "Quick Start", function()
		return "1. Open <b>Profiles</b> and pick a preset. <b>Balanced</b> is a good first choice.\n"
			.. "2. In game, hold <b>" .. bn(Config.AimKey) .. "</b> (or the on-screen <b>AIM</b> button on mobile, or <b>" .. bn(Config.AimKeyAlt) .. "</b> on a gamepad). Your camera is gently pulled toward the best target inside the FOV circle.\n"
			.. "3. Fine tune in <b>Aim</b>, <b>Targeting</b> and <b>Visuals</b>.\n"
			.. "4. Use <b>Profiles, then Export</b> to copy your setup as text so you can paste it back later."
	end)

	guideTopic(P, "Using The Menu", function()
		return "<b>" .. bn(Config.MenuKey) .. "</b> opens and closes the menu. On mobile, tap the floating <b>AA</b> bubble.\n"
			.. "<b>Drag the title bar</b> to move the menu. Drag the bubble to move it.\n"
			.. "<b>ON / OFF</b> button: master power switch (" .. bn(Config.PowerKey) .. " on keyboard).\n"
			.. "<b>?</b> jumps to this guide.\n"
			.. "<b>^</b> collapses the menu to a slim bar, <b>v</b> expands it again.\n"
			.. "<b>-</b> minimizes the whole menu to the bubble.\n"
			.. "Size and look are in <b>Interface</b> (scale, opacity, accent color). If the menu ever goes missing, use <b>Interface, then Center Menu</b>."
	end)

	guideTopic(P, "Controls By Device", function()
		return "<b>PC:</b> hold " .. bn(Config.AimKey) .. " to aim. " .. bn(Config.CycleKey) .. " switches to a different target. " .. bn(Config.PowerKey) .. " toggles the assist.\n"
			.. "<b>Mobile:</b> hold the AIM button with one thumb while you look around with the other. Move or resize the button in the <b>Mobile</b> tab.\n"
			.. "<b>Gamepad:</b> hold " .. bn(Config.AimKeyAlt) .. ". The Controller preset keeps it always on while you move the right stick.\n"
			.. "<b>Aim Mode:</b> Hold = active while the key is held, Toggle = press once to turn on and again to turn off, Always = no key needed."
	end)

	guideTopic(P, "Aim Tab", function()
		return "<b>Smoothness</b>: how much of the gap closes each frame. Low is gentle, high is snappy.\n"
			.. "<b>Pull Curve</b>: Constant, Ramp Up (stronger when far), Ramp Down (stronger when close), Smooth (eased).\n"
			.. "<b>Max Turn Speed</b>: hard cap on turning speed in degrees per second.\n"
			.. "<b>Deadzone</b>: no pull when you are already this close (degrees) to the target.\n"
			.. "<b>Horizontal / Vertical Strength</b>: scale the pull on each axis separately.\n"
			.. "<b>Humanize</b>: adds a small natural drift. Humanize Speed controls how fast it wanders.\n"
			.. "<b>Magnetism</b>: extra pull near the middle of the circle. Magnet Radius sets how wide that zone is.\n"
			.. "<b>Distance Falloff</b>: weaker pull on far targets.\n"
			.. "<b>Only Assist While Looking</b>: only helps while you are moving the camera. Look Grace is how long help lingers after you stop.\n"
			.. "<b>Aim Part / Part Offset</b>: Head, Torso, Root or the part closest to the circle center, plus a vertical shift in studs."
	end)

	guideTopic(P, "Targeting Tab", function()
		return "<b>FOV Radius</b>: only targets inside the circle are considered. The circle can follow the mouse and be offset.\n"
			.. "<b>Max / Min Distance</b>: ignore targets that are too far or too close.\n"
			.. "<b>Target Priority</b>: Crosshair (closest to the circle center), Distance, Lowest Health or Highest Health.\n"
			.. "<b>Team Check</b>, <b>Wall Check</b>, <b>Ignore Friends</b>, <b>Ignore Force Fields</b>, <b>Min Target Health</b> filter who can be picked.\n"
			.. "<b>Ignore Names</b>: comma separated list of player or NPC names to skip.\n"
			.. "<b>Target NPCs</b>: also considers humanoid models that are not players.\n"
			.. "<b>Sticky Target</b>: keeps the current target until it leaves the (scaled) circle. Switch Delay and Lost Target Grace smooth out flicker."
	end)

	guideTopic(P, "Prediction Tab", function()
		return "<b>Movement Prediction</b> leads moving targets using Projectile Speed (studs per second). Set speed to 0 for instant-hit weapons.\n"
			.. "<b>Prediction Strength</b> scales how much lead is applied.\n"
			.. "<b>Use Measured Velocity</b> tracks real movement instead of trusting physics velocity. Velocity Smoothing controls how steady that reading is.\n"
			.. "<b>Bullet Drop Compensation</b> aims a little higher on far targets. Gravity Multiplier tunes it to your game's projectiles."
	end)

	guideTopic(P, "Visuals Tab", function()
		return "Everything here is cosmetic and fully optional.\n"
			.. "<b>FOV circle</b>: color, thickness, transparency and optional fill.\n"
			.. "<b>Aim dot / Snap line</b>: show where the assist is pointing and draw a line to it.\n"
			.. "<b>Target highlight</b>: outlines the locked target, optionally through walls.\n"
			.. "<b>Status HUD</b>: small label showing mode, target name and distance. Move it top or bottom and resize it.\n"
			.. "Tap a color row to open swatches and Red / Green / Blue sliders."
	end)

	guideTopic(P, "Profiles & Sharing", function()
		return "<b>Presets</b> change many values at once: Legit, Balanced, Strong, Controller, Mobile Friendly, Sniper and Close Quarters. Tweak anything afterwards.\n"
			.. "<b>Session slots</b> remember three setups until you leave the game.\n"
			.. "<b>Export</b> turns your settings into text. <b>Import</b> loads text you paste in. Great for moving a setup between devices.\n"
			.. "<b>Reset</b> restores every default (tap twice to confirm)."
	end)

	guideTopic(P, "Troubleshooting", function()
		return "<b>Nothing happens when I aim:</b> check the ON switch, your aim key / mode, and that a target is inside the circle. Turn off Team Check or Wall Check to test.\n"
			.. "<b>Camera fights back:</b> games with custom scripted cameras may override the assist. Lower Smoothness or use a first-person style camera.\n"
			.. "<b>Aim feels too strong:</b> try the Legit preset, lower Smoothness and Max Turn Speed, raise Humanize.\n"
			.. "<b>Mobile button missing:</b> enable it in the Mobile tab.\n"
			.. "<b>Keybind stuck:</b> tap the key button again to cancel, or press Esc."
	end)
end)

----------------------------------------------------------------
-- APPLY VISUALS (runs on every setting change)
----------------------------------------------------------------
applyVisuals = function()
	-- accent color
	if THEME.Accent ~= Config.AccentColor then
		THEME.Accent = Config.AccentColor
		for _, b in ipairs(boundAccent) do
			if b[1].Parent then b[1][b[2]] = THEME.Accent end
		end
		refreshControls()
	end

	-- FOV / dot / line
	if not Config.FOVFollowMouse then
		FOVCircle.Position = UDim2.new(0.5, Config.FOVOffsetX, 0.5, Config.FOVOffsetY)
	end
	FOVCircle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
	FOVCircle.BackgroundColor3 = Config.FOVColor
	FOVCircle.BackgroundTransparency = Config.FOVFill and Config.FOVFillTransparency or 1
	FOVStroke.Color = Config.FOVColor
	FOVStroke.Thickness = Config.FOVThickness
	FOVStroke.Transparency = Config.FOVTransparency
	Dot.BackgroundColor3 = Config.DotColor
	Dot.Size = UDim2.fromOffset(Config.DotSize, Config.DotSize)
	SnapLine.BackgroundColor3 = Config.SnapLineColor

	-- highlight
	Highlight.FillColor = Config.HighlightFillColor
	Highlight.FillTransparency = Config.HighlightFillTransparency
	Highlight.OutlineColor = Config.HighlightOutlineColor
	Highlight.OutlineTransparency = Config.HighlightOutlineTransparency
	Highlight.DepthMode = Config.HighlightAlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded

	-- HUD
	HUDScale.Scale = Config.HUDScale / 100
	if Config.HUDPosition == "Bottom" then
		HUD.AnchorPoint = Vector2.new(0.5, 1)
		HUD.Position = UDim2.new(0.5, 0, 1, -70)
	else
		HUD.AnchorPoint = Vector2.new(0.5, 0)
		HUD.Position = UDim2.new(0.5, 0, 0, 52)
	end

	-- mobile button
	local s = Config.MobileButtonSize
	MobileBtn.Size = UDim2.fromOffset(s, s)
	MobileBtn.Position = UDim2.new(1, -Config.MobileButtonX, 1, -Config.MobileButtonY)
	MobileBtn.TextSize = clamp(math.floor(s * 0.26), 10, 30)
	local mt = 1 - Config.MobileButtonOpacity / 100
	MobileBtn.BackgroundTransparency = mt
	MobileBtn.TextTransparency = mt * 0.6
	MobileStroke.Transparency = mt * 0.6

	-- bubble
	Bubble.Size = UDim2.fromOffset(Config.BubbleSize, Config.BubbleSize)
	Bubble.TextSize = clamp(math.floor(Config.BubbleSize * 0.34), 10, 24)
	local bt = 1 - Config.BubbleOpacity / 100
	Bubble.BackgroundTransparency = bt
	Bubble.TextTransparency = bt * 0.6
	BubbleStroke.Transparency = bt * 0.6

	-- window
	local newScale = Config.UIScale / 100
	if WinScale.Scale ~= newScale then
		WinScale.Scale = newScale
		State.NeedClamp = true
	end
	local panelT = 1 - Config.UIOpacity / 100
	for _, p in ipairs(windowPanels) do p.BackgroundTransparency = panelT end

	-- power button
	PowerBtn.Text = Config.Enabled and "ON" or "OFF"
	PowerBtn.BackgroundColor3 = Config.Enabled and THEME.Accent or THEME.Item
	PowerBtn.TextColor3 = Config.Enabled and contrast(THEME.Accent) or THEME.Dim
end

----------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------
local STEP_NAME = "AimAssistMenuStep"
local lastHud = ""

local function stepInner(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	Camera = cam
	if Highlight.Parent ~= Camera then Highlight.Parent = Camera end

	if State.NeedClamp then
		State.NeedClamp = false
		local wp, bp = Window.AbsolutePosition, Bubble.AbsolutePosition
		Window.Position = clampedPos(Window, wp.X, wp.Y)
		Bubble.Position = clampedPos(Bubble, bp.X, bp.Y)
	end

	if State.MenuOpen then
		local wp, ws, vp = Window.AbsolutePosition, Window.AbsoluteSize, Gui.AbsoluteSize
		if vp.X > 100 and (wp.X > vp.X - 40 or wp.Y > vp.Y - 20 or wp.X + ws.X < 40 or wp.Y + ws.Y < 20) then
			centerWindow()
		end
	end

	rebuildIgnore()
	local now = os.clock()
	local ref = getReference()
	local show = Config.Enabled and not State.HideAll

	if Config.FOVFollowMouse then
		FOVCircle.Position = UDim2.fromOffset(ref.X, ref.Y)
	else
		FOVCircle.Position = UDim2.new(0.5, Config.FOVOffsetX, 0.5, Config.FOVOffsetY)
	end
	FOVCircle.Visible = (show and Config.ShowFOV) or State.EditCircle == true
	FOVHandle.Position = FOVCircle.Position
	FOVHandle.Visible = State.EditCircle == true and not State.HideAll

	local info, canAim = nil, false
	if Config.Enabled then
		local cands = getCandidates()
		if Config.Prediction and Config.UseMeasuredVelocity then updateVelocities(dt, cands) end
		info = findTarget(cands, ref)

		if info then
			State.LastSeen = now
			canAim = aimActive() and (not Config.RequireLooking or (now - State.LastLookMove) <= Config.LookGrace)
		elseif State.Target and (now - State.LastSeen) > Config.LostGrace then
			State.Target = nil
		end

		if canAim then
			local aimPos = computeAimPos(info)
			State.LastAimPos = aimPos
			applyAim(dt, aimPos, info.Screen, info.Dist)
		end
	else
		State.Target = nil
	end

	-- target visuals
	local showTarget = show and info ~= nil
	if showTarget and Config.ShowHighlight then
		Highlight.Adornee = info.Cand.Char
		Highlight.Enabled = true
	else
		Highlight.Enabled = false
	end

	local dotVisible, lineVisible = false, false
	if showTarget and (Config.ShowDot or Config.ShowSnapLine) then
		local p3 = (canAim and State.LastAimPos) or info.Part.Position
		local v, on = Camera:WorldToViewportPoint(p3)
		if on then
			local pt = Vector2.new(v.X, v.Y)
			if Config.ShowDot then
				Dot.Position = UDim2.fromOffset(pt.X, pt.Y)
				dotVisible = true
			end
			if Config.ShowSnapLine then
				local d = pt - ref
				SnapLine.Position = UDim2.fromOffset((pt.X + ref.X) / 2, (pt.Y + ref.Y) / 2)
				SnapLine.Size = UDim2.fromOffset(d.Magnitude, Config.SnapLineThickness)
				SnapLine.Rotation = math.deg(math.atan2(d.Y, d.X))
				lineVisible = true
			end
		end
	end
	Dot.Visible = dotVisible
	SnapLine.Visible = lineVisible

	-- HUD
	HUD.Visible = Config.ShowHUD and not State.HideAll
	if HUD.Visible then
		local txt
		if not Config.Enabled then
			txt = "AIM ASSIST  |  OFF"
		elseif info then
			txt = string.format("%s  |  %s  |  %d studs", canAim and "LOCKED" or "TARGET", info.Name, math.floor(info.Dist + 0.5))
		else
			txt = "AIM ASSIST  |  " .. string.upper(Config.AimMode)
		end
		if txt ~= lastHud then
			lastHud = txt
			HUD.Text = txt
			HUD.Size = UDim2.fromOffset(clamp(#txt * 7.2 + 28, 170, 460), 26)
		end
		HUD.TextColor3 = canAim and THEME.Accent or THEME.Text
	end

	-- mobile button + bubble state
	MobileBtn.Visible = Config.MobileButton and not State.HideAll
	if MobileBtn.Visible then
		local on = aimActive()
		MobileBtn.BackgroundColor3 = on and THEME.Accent or THEME.Bg
		MobileBtn.TextColor3 = on and contrast(THEME.Accent) or THEME.Text
	end
	Bubble.Visible = (not State.MenuOpen) or Config.BubbleAlways
	BubbleStroke.Color = Config.Enabled and THEME.Accent or THEME.Off
	Bubble.TextColor3 = Config.Enabled and THEME.Text or THEME.Dim
end

local lastStepErr = nil
local function step(dt)
	Bubble.Visible = (not State.MenuOpen) or Config.BubbleAlways
	local ok, err = pcall(stepInner, dt)
	if not ok and tostring(err) ~= lastStepErr then
		lastStepErr = tostring(err)
		reportError("loop", err)
	end
end

pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, step)
Gui.Destroying:Connect(function()
	pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
end)

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	-- keybind capture
	if State.Listening then
		local key = State.Listening
		local bind
		local t = input.UserInputType
		if t == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				State.Listening = nil
				refreshControls()
				return
			elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				bind = Enum.KeyCode.Unknown
			else
				bind = input.KeyCode
			end
		elseif t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 then
			bind = t
		elseif t == Enum.UserInputType.Gamepad1 then
			local n = input.KeyCode.Name
			if string.sub(n, 1, 6) == "Button" or string.sub(n, 1, 4) == "DPad" then bind = input.KeyCode end
		end
		if bind then
			State.Listening = nil
			setSetting(key, bind)
			refreshControls()
			notify("Bound to " .. ((bind == Enum.KeyCode.Unknown) and "None" or friendlyBind(bind)))
		end
		return
	end

	if gp then return end

	if bindMatches(input, Config.MenuKey) then
		setMenuOpen(not State.MenuOpen)
	elseif bindMatches(input, Config.PowerKey) then
		setSetting("Enabled", not Config.Enabled)
		notify(Config.Enabled and "Aim assist ON" or "Aim assist OFF")
	elseif bindMatches(input, Config.CycleKey) then
		if State.Target then
			State.Skip[State.Target] = os.clock() + 3
			State.Target = nil
			notify("Switching target")
		end
	end

	if Config.AimMode == "Toggle" and (bindMatches(input, Config.AimKey) or bindMatches(input, Config.AimKeyAlt)) then
		State.ToggleOn = not State.ToggleOn
		notify(State.ToggleOn and "Aim toggled ON" or "Aim toggled OFF")
	end
end)

UserInputService.InputChanged:Connect(function(input, gp)
	-- drag manager
	if Drag then
		local di = Drag.input
		if input == di or (input.UserInputType == Enum.UserInputType.MouseMovement and di.UserInputType == Enum.UserInputType.MouseButton1) then
			Drag.onMove(pointerOf(di))
		end
	end

	-- "is the player actively looking around?" (for Only Assist While Looking)
	if gp then return end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
		if input.Delta.Magnitude > 0 then State.LastLookMove = os.clock() end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		if input.Position.Magnitude > 0.15 then State.LastLookMove = os.clock() end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if Drag then
		local di = Drag.input
		if input == di or (di.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
			endDrag()
		end
	end
end)

----------------------------------------------------------------
-- START
----------------------------------------------------------------
safe("select tab", function() selectTab(State.CurrentTab) end)
safe("apply visuals", applyVisuals)
safe("refresh controls", refreshControls)
safe("open menu", function()
	setMenuOpen(true)
	Window.Visible = true
	centerWindow()
end)
task.spawn(function()
	-- the screen size can be 0 on the very first frame, so re-center until it is real
	local t0 = os.clock()
	while Gui.Parent and Gui.AbsoluteSize.X < 100 and os.clock() - t0 < 3 do task.wait() end
	if Gui.Parent and not State.Moved then centerWindow() end
end)
local function watchViewport()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if not State.Moved then centerWindow() end
			State.NeedClamp = true
		end)
	end
end
watchViewport()
notify(IS_TOUCH and "Aim Assist ready - tap ? for the guide" or ("Aim Assist ready - " .. friendlyBind(Config.MenuKey) .. " toggles the menu"))
