local queue_on_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or (getgenv and getgenv().queue_on_teleport)

if queue_on_teleport and not getgenv().AlreadyLoaded then 
	queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/nashSatanic/snifeduels/refs/heads/main/leak.lua'))()")
end 

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local TeleportConn
pcall(function()
	TeleportConn = LocalPlayer.OnTeleport:Connect(function(State)
		if State == Enum.TeleportState.Started and queue_on_teleport and getgenv().AlreadyLoaded then
			queue_on_teleport("repeat task.wait() until game:IsLoaded() loadstring(game:HttpGet('https://raw.githubusercontent.com/nashSatanic/snifeduels/refs/heads/main/leak.lua'))()")
		end
	end)
end)

getgenv().AlreadyLoaded = true

local Connections = {}

local function BindSignal(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(Connections, conn)
	return conn
end

BindSignal(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	Camera = workspace.CurrentCamera
end)

local Tag = "NASH_GUI_" .. tostring(math.random(100000, 999999))
if CoreGui:FindFirstChild(Tag) then
	CoreGui[Tag]:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = Tag
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = pcall(function()
	ScreenGui.Parent = CoreGui
end)
if not parented then
	ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Config = {
	Settings = {
		TeamCheck = true,
		AccentColor = Color3.fromRGB(168, 85, 247),
	},
	ESP = {
		Enabled = false,
		Box = false,
		BoxColor = Color3.fromRGB(168, 85, 247),
		Chams = false,
		ChamsColor = Color3.fromRGB(168, 85, 247),
		Names = false,
		Health = false,
		HealthBar = false,
		Distance = false,
		Tracers = false,
		TracerColor = Color3.fromRGB(168, 85, 247),
		HeadDot = false,
		HeadDotColor = Color3.fromRGB(255, 255, 255),
	},
	Aimbot = {
		Enabled = false,
		VisCheck = true,
		FOV = 150,
		Smooth = 5,
		Target = "Head",
		ShowFOV = false,
	},
	KnifeControl = {
		Enabled = false,
		GuideSpeed = 150,
		PredictMovement = true,
		PredictionMultiplier = 1.1,
		ArcHeight = 0,
		SteerMode = "Direct",
		ControlRadius = 750,
		TargetPart = "Head",
	}
}

local ESPData = {}

local function IsEnemy(player)
	if not player or player == LocalPlayer then return false end
	if not Config.Settings.TeamCheck then return true end
	
	local localTeam = LocalPlayer.Team
	local targetTeam = player.Team

	if localTeam ~= nil and targetTeam ~= nil then
		return localTeam ~= targetTeam
	end

	local localTeamColor = LocalPlayer.TeamColor
	local targetTeamColor = player.TeamColor
	if localTeamColor ~= nil and targetTeamColor ~= nil then
		return localTeamColor ~= targetTeamColor
	end

	if LocalPlayer.Character and player.Character then
		local localAttr = LocalPlayer.Character:GetAttribute("Team") or LocalPlayer:GetAttribute("Team") or LocalPlayer.Character:GetAttribute("Faction")
		local targetAttr = player.Character:GetAttribute("Team") or player:GetAttribute("Team") or player.Character:GetAttribute("Faction")
		if localAttr and targetAttr then
			return localAttr ~= targetAttr
		end
	end

	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local targetLeaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and targetLeaderstats then
		local localTeamStat = leaderstats:FindFirstChild("Team") or leaderstats:FindFirstChild("Faction")
		local targetTeamStat = targetLeaderstats:FindFirstChild("Team") or targetLeaderstats:FindFirstChild("Faction")
		if localTeamStat and targetTeamStat then
			return localTeamStat.Value ~= targetTeamStat.Value
		end
	end

	return true
end

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "FOVCircle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Visible = false
FOVCircle.Parent = ScreenGui

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Config.Settings.AccentColor
FOVStroke.Thickness = 1.2
FOVStroke.Transparency = 0.3
FOVStroke.Parent = FOVCircle

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local function CleanPlayerESP(player)
	if ESPData[player] then
		local data = ESPData[player]
		if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
		if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
		if data.BoxFrame then pcall(function() data.BoxFrame:Destroy() end) end
		if data.HealthFrame then pcall(function() data.HealthFrame:Destroy() end) end
		if data.TracerLine then pcall(function() data.TracerLine:Destroy() end) end
		if data.HeadMarker then pcall(function() data.HeadMarker:Destroy() end) end
		ESPData[player] = nil
	end
end

local function ClearAllESP()
	for player, _ in pairs(ESPData) do
		CleanPlayerESP(player)
	end
	ESPData = {}
end

local function UpdatePlayerESP(player)
	if not IsEnemy(player) then
		CleanPlayerESP(player)
		return
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	local shouldDraw = Config.ESP.Enabled and char and hrp and hum and hum.Health > 0

	if not shouldDraw then
		CleanPlayerESP(player)
		return
	end

	if not ESPData[player] then
		ESPData[player] = {}
	end

	local data = ESPData[player]

	if Config.ESP.Chams then
		if not data.Highlight or not data.Highlight.Parent then
			if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
			local hl = Instance.new("Highlight")
			hl.Name = "ESP_Cham"
			hl.FillColor = Config.ESP.ChamsColor
			hl.FillTransparency = 0.4
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.OutlineTransparency = 0.1
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = char
			hl.Parent = ScreenGui
			data.Highlight = hl
		else
			data.Highlight.Adornee = char
			data.Highlight.FillColor = Config.ESP.ChamsColor
			data.Highlight.Enabled = true
		end
	else
		if data.Highlight then
			pcall(function() data.Highlight:Destroy() end)
			data.Highlight = nil
		end
	end

	local hrpPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

	if onScreen then
		local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
		local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
		local boxHeight = math.abs(headPos.Y - legPos.Y)
		local boxWidth = boxHeight * 0.65

		if Config.ESP.Box then
			if not data.BoxFrame or not data.BoxFrame.Parent then
				local box = Instance.new("Frame")
				box.Name = "ESP_Box"
				box.BackgroundTransparency = 1
				box.Parent = ScreenGui

				local stroke = Instance.new("UIStroke")
				stroke.Name = "Stroke"
				stroke.Thickness = 1.5
				stroke.Color = Config.ESP.BoxColor
				stroke.Parent = box

				data.BoxFrame = box
			end
			data.BoxFrame.Size = UDim2.new(0, boxWidth, 0, boxHeight)
			data.BoxFrame.Position = UDim2.new(0, hrpPos.X - (boxWidth / 2), 0, hrpPos.Y - (boxHeight / 2))
			data.BoxFrame.Visible = true
		else
			if data.BoxFrame then data.BoxFrame.Visible = false end
		end

		if Config.ESP.HealthBar then
			if not data.HealthFrame or not data.HealthFrame.Parent then
				local healthBg = Instance.new("Frame")
				healthBg.Name = "ESP_HealthBg"
				healthBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
				healthBg.BorderSizePixel = 0
				healthBg.Parent = ScreenGui

				local healthFill = Instance.new("Frame")
				healthFill.Name = "Fill"
				healthFill.BorderSizePixel = 0
				healthFill.Parent = healthBg

				data.HealthFrame = healthBg
				data.HealthFill = healthFill
			end

			local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			data.HealthFrame.Size = UDim2.new(0, 4, 0, boxHeight)
			data.HealthFrame.Position = UDim2.new(0, hrpPos.X - (boxWidth / 2) - 7, 0, hrpPos.Y - (boxHeight / 2))
			data.HealthFrame.Visible = true

			data.HealthFill.Size = UDim2.new(1, 0, healthPercent, 0)
			data.HealthFill.Position = UDim2.new(0, 0, 1 - healthPercent, 0)
			data.HealthFill.BackgroundColor3 = Color3.fromHSV(healthPercent * 0.3, 0.9, 0.9)
		else
			if data.HealthFrame then data.HealthFrame.Visible = false end
		end

		if Config.ESP.HeadDot then
			if not data.HeadMarker or not data.HeadMarker.Parent then
				local dot = Instance.new("Frame")
				dot.Name = "ESP_HeadDot"
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.BackgroundColor3 = Config.ESP.HeadDotColor
				dot.BorderSizePixel = 0
				dot.Parent = ScreenGui

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = dot

				data.HeadMarker = dot
			end
			local dotSize = math.clamp(boxHeight * 0.12, 4, 10)
			data.HeadMarker.Size = UDim2.new(0, dotSize, 0, dotSize)
			data.HeadMarker.Position = UDim2.new(0, headPos.X, 0, headPos.Y)
			data.HeadMarker.Visible = true
		else
			if data.HeadMarker then data.HeadMarker.Visible = false end
		end

		if Config.ESP.Tracers then
			if not data.TracerLine or not data.TracerLine.Parent then
				local line = Instance.new("Frame")
				line.Name = "ESP_Tracer"
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.BackgroundColor3 = Config.ESP.TracerColor
				line.BorderSizePixel = 0
				line.Parent = ScreenGui

				data.TracerLine = line
			end

			local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
			local targetScreenPos = Vector2.new(hrpPos.X, hrpPos.Y)
			local distance = (targetScreenPos - screenCenter).Magnitude
			local angle = math.atan2(targetScreenPos.Y - screenCenter.Y, targetScreenPos.X - screenCenter.X)

			data.TracerLine.Size = UDim2.new(0, distance, 0, 1.5)
			data.TracerLine.Position = UDim2.new(0, (screenCenter.X + targetScreenPos.X) / 2, 0, (screenCenter.Y + targetScreenPos.Y) / 2)
			data.TracerLine.Rotation = math.deg(angle)
			data.TracerLine.Visible = true
		else
			if data.TracerLine then data.TracerLine.Visible = false end
		end
	else
		if data.BoxFrame then data.BoxFrame.Visible = false end
		if data.HealthFrame then data.HealthFrame.Visible = false end
		if data.HeadMarker then data.HeadMarker.Visible = false end
		if data.TracerLine then data.TracerLine.Visible = false end
	end

	local needBillboard = Config.ESP.Names or Config.ESP.Health or Config.ESP.Distance
	if needBillboard and head then
		if not data.Billboard or not data.Billboard.Parent then
			if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
			local bb = Instance.new("BillboardGui")
			bb.Name = "ESP_Tag"
			bb.Size = UDim2.new(0, 200, 0, 50)
			bb.StudsOffset = Vector3.new(0, 2.5, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = head
			bb.Parent = ScreenGui

			local label = Instance.new("TextLabel")
			label.Name = "TagLabel"
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextSize = 13
			label.Font = Enum.Font.SourceSansBold
			label.TextStrokeTransparency = 0.2
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.Parent = bb

			data.Billboard = bb
			data.Label = label
		else
			data.Billboard.Adornee = head
			data.Billboard.Enabled = true
		end

		if data.Label then
			local textLines = {}
			if Config.ESP.Names then
				table.insert(textLines, player.DisplayName)
			end
			if Config.ESP.Health then
				local hp = math.floor(hum.Health)
				table.insert(textLines, "HP: " .. tostring(hp) .. "%")
			end
			if Config.ESP.Distance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
				table.insert(textLines, tostring(dist) .. "m")
			end
			data.Label.Text = table.concat(textLines, " | ")
		end
	else
		if data.Billboard then
			pcall(function() data.Billboard:Destroy() end)
			data.Billboard = nil
			data.Label = nil
		end
	end
end

BindSignal(Players.PlayerRemoving, function(plr)
	CleanPlayerESP(plr)
end)

local function IsVisible(targetPart, character)
	local origin = Camera.CFrame.Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character, character }
	local result = workspace:Raycast(origin, targetPart.Position - origin, rayParams)
	if result then
		return result.Instance:IsDescendantOf(character)
	end
	return true
end

local function GetClosestTarget(customFOV)
	local mousePos = UserInputService:GetMouseLocation()
	local closestDist = customFOV or Config.Aimbot.FOV
	local targetPart = nil

	for _, plr in ipairs(Players:GetPlayers()) do
		if IsEnemy(plr) and plr.Character then
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			local part = plr.Character:FindFirstChild(Config.Aimbot.Target) or plr.Character:FindFirstChild("Head")
			if hum and hum.Health > 0 and part then
				local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
					if dist < closestDist then
						if not Config.Aimbot.VisCheck or IsVisible(part, plr.Character) then
							closestDist = dist
							targetPart = part
						end
					end
				end
			end
		end
	end
	return targetPart
end

local function GetClosestTargetWorld()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local closestDist = Config.KnifeControl.ControlRadius
	local targetPart = nil

	for _, plr in ipairs(Players:GetPlayers()) do
		if IsEnemy(plr) and plr.Character then
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			local part = plr.Character:FindFirstChild(Config.KnifeControl.TargetPart) or plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and part then
				local dist = (part.Position - hrp.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					targetPart = part
				end
			end
		end
	end
	return targetPart
end

local function SteerKnifeProjectile(knife)
	if not knife or not knife:IsA("BasePart") then return end

	local target = GetClosestTargetWorld()
	if not target then return end

	local targetPos = target.Position

	if Config.KnifeControl.PredictMovement and target.Parent then
		local hum = target.Parent:FindFirstChildOfClass("Humanoid")
		local targetHRP = target.Parent:FindFirstChild("HumanoidRootPart")
		if hum and targetHRP then
			local velocity = targetHRP.AssemblyLinearVelocity
			local distance = (targetPos - knife.Position).Magnitude
			local timeToReach = distance / math.max(Config.KnifeControl.GuideSpeed, 1)
			targetPos = targetPos + (velocity * timeToReach * Config.KnifeControl.PredictionMultiplier)
		end
	end

	if Config.KnifeControl.ArcHeight > 0 then
		local distance = (targetPos - knife.Position).Magnitude
		local arcFactor = math.sin(math.pi * math.clamp(distance / Config.KnifeControl.ControlRadius, 0, 1))
		targetPos = targetPos + Vector3.new(0, arcFactor * Config.KnifeControl.ArcHeight, 0)
	end

	local direction = (targetPos - knife.Position).Unit
	local newVelocity = direction * Config.KnifeControl.GuideSpeed

	pcall(function()
		if Config.KnifeControl.SteerMode == "SmoothLerp" then
			knife.AssemblyLinearVelocity = knife.AssemblyLinearVelocity:Lerp(newVelocity, 0.35)
		else
			knife.AssemblyLinearVelocity = newVelocity
		end
		
		knife.CFrame = CFrame.lookAt(knife.Position, targetPos)

		local bodyVel = knife:FindFirstChildOfClass("BodyVelocity")
		if bodyVel then
			bodyVel.Velocity = newVelocity
		end

		local linearVel = knife:FindFirstChildOfClass("LinearVelocity")
		if linearVel then
			linearVel.VectorVelocity = newVelocity
		end
	end)
end

local function ProcessKnifeControl()
	if not Config.KnifeControl.Enabled then return end

	local searchFolders = {
		workspace,
		workspace:FindFirstChild("Projectiles"),
		workspace:FindFirstChild("Debris"),
		workspace:FindFirstChild("RaycastFilter"),
		workspace:FindFirstChild("Thrown"),
		workspace:FindFirstChild("Knives"),
		workspace:FindFirstChild("Entities"),
		workspace:FindFirstChild("Weapons"),
		workspace:FindFirstChild("Items")
	}

	for _, folder in ipairs(searchFolders) do
		if folder then
			for _, obj in ipairs(folder:GetChildren()) do
				if obj:IsA("BasePart") or obj:IsA("Model") then
					local name = obj.Name:lower()
					if name:find("knife") or name:find("blade") or name:find("throw") or name:find("projectile") or name:find("handle") or name:find("snife") or name:find("dagger") or name:find("kunai") or name:find("cleaver") then
						local mainPart = obj:IsA("BasePart") and obj or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
						if mainPart and not mainPart:IsDescendantOf(LocalPlayer.Character) then
							SteerKnifeProjectile(mainPart)
						end
					end
				end
			end
		end
	end
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 380)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 13, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(38, 33, 52)
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 150, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 15, 26)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideDivider = Instance.new("Frame")
SideDivider.Size = UDim2.new(0, 1, 1, 0)
SideDivider.Position = UDim2.new(1, -1, 0, 0)
SideDivider.BackgroundColor3 = Color3.fromRGB(38, 33, 52)
SideDivider.BorderSizePixel = 0
SideDivider.Parent = Sidebar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0, 40)
Title.Position = UDim2.new(0, 10, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "NASH CORE"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 15
Title.Font = Enum.Font.SourceSansBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Sidebar

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 1, -60)
TabContainer.Position = UDim2.new(0, 0, 0, 50)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = Sidebar

local TabList = Instance.new("UIListLayout")
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Padding = UDim.new(0, 4)
TabList.Parent = TabContainer

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -150, 1, 0)
ContentArea.Position = UDim2.new(0, 150, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}
local Pages = {}

local function CreateTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundTransparency = 1
	btn.Text = "  " .. name
	btn.TextColor3 = Color3.fromRGB(130, 130, 150)
	btn.TextSize = 13
	btn.Font = Enum.Font.SourceSansSemibold
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Parent = TabContainer

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0, 18)
	indicator.Position = UDim2.new(0, 0, 0.5, -9)
	indicator.BackgroundColor3 = Config.Settings.AccentColor
	indicator.BorderSizePixel = 0
	indicator.Visible = false
	indicator.Parent = btn

	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(1, 0)
	indCorner.Parent = indicator

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, -24, 1, -24)
	page.Position = UDim2.new(0, 12, 0, 12)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 2
	page.ScrollBarImageColor3 = Color3.fromRGB(38, 33, 52)
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = ContentArea

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Padding = UDim.new(0, 10)
	pageLayout.Parent = page

	Tabs[name] = { Btn = btn, Ind = indicator }
	Pages[name] = page

	btn.MouseButton1Click:Connect(function()
		for tName, tData in pairs(Tabs) do
			tData.Ind.Visible = false
			tData.Btn.TextColor3 = Color3.fromRGB(130, 130, 150)
			Pages[tName].Visible = false
		end
		indicator.Visible = true
		btn.TextColor3 = Config.Settings.AccentColor
		page.Visible = true
	end)

	return page
end

local function CreateToggle(parent, text, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 28)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.TextSize = 13
	label.Font = Enum.Font.SourceSansSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 34, 0, 18)
	btn.Position = UDim2.new(1, -34, 0.5, -9)
	btn.BackgroundColor3 = default and Config.Settings.AccentColor or Color3.fromRGB(32, 28, 44)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = frame

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(1, 0)
	bCorner.Parent = btn

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 12, 0, 12)
	knob.Position = default and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = btn

	local kCorner = Instance.new("UICorner")
	kCorner.CornerRadius = UDim.new(1, 0)
	kCorner.Parent = knob

	local state = default
	btn.MouseButton1Click:Connect(function()
		state = not state
		TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = state and Config.Settings.AccentColor or Color3.fromRGB(32, 28, 44) }):Play()
		TweenService:Create(knob, TweenInfo.new(0.2), { Position = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6) }):Play()
		if callback then callback(state) end
	end)
end

local function CreateSlider(parent, text, min, max, default, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.Text = text .. " (" .. tostring(default) .. ")"
	label.TextColor3 = Color3.fromRGB(240, 240, 245)
	label.TextSize = 13
	label.Font = Enum.Font.SourceSansSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local track = Instance.new("TextButton")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 22)
	track.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = frame

	local trCorner = Instance.new("UICorner")
	trCorner.CornerRadius = UDim.new(1, 0)
	trCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = Config.Settings.AccentColor
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fCorner = Instance.new("UICorner")
	fCorner.CornerRadius = UDim.new(1, 0)
	fCorner.Parent = fill

	local function ApplyValue(val)
		local clamped = math.clamp(math.floor(val + 0.5), min, max)
		local rel = (clamped - min) / (max - min)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		label.Text = text .. " (" .. tostring(clamped) .. ")"
		if callback then callback(clamped) end
	end

	local dragging = false
	track.MouseButton1Down:Connect(function()
		dragging = true
		local mousePos = UserInputService:GetMouseLocation()
		local rel = math.clamp((mousePos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		ApplyValue(min + rel * (max - min))
	end)

	BindSignal(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	BindSignal(UserInputService.InputChanged, function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			ApplyValue(min + rel * (max - min))
		end
	end)
end

local function CreateButton(parent, text, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(240, 240, 245)
	btn.TextSize = 13
	btn.Font = Enum.Font.SourceSansSemibold
	btn.Parent = frame

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 6)
	bCorner.Parent = btn

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Config.Settings.AccentColor
	bStroke.Thickness = 1
	bStroke.Transparency = 0.5
	bStroke.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
end

local espPage = CreateTab("ESP")
CreateToggle(espPage, "Master ESP Toggle", Config.ESP.Enabled, function(v)
	Config.ESP.Enabled = v
	if not v then ClearAllESP() end
end)
CreateToggle(espPage, "2D Bounding Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
CreateToggle(espPage, "Health Bar", Config.ESP.HealthBar, function(v) Config.ESP.HealthBar = v end)
CreateToggle(espPage, "Tracers / Snaplines", Config.ESP.Tracers, function(v) Config.ESP.Tracers = v end)
CreateToggle(espPage, "Head Marker", Config.ESP.HeadDot, function(v) Config.ESP.HeadDot = v end)
CreateToggle(espPage, "Chams Wallhack", Config.ESP.Chams, function(v) Config.ESP.Chams = v end)
CreateToggle(espPage, "Display Names", Config.ESP.Names, function(v) Config.ESP.Names = v end)
CreateToggle(espPage, "Display Health %", Config.ESP.Health, function(v) Config.ESP.Health = v end)
CreateToggle(espPage, "Display Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)

local aimPage = CreateTab("Aimbot")
CreateToggle(aimPage, "Enable Aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
CreateToggle(aimPage, "Show FOV Circle", Config.Aimbot.ShowFOV, function(v) Config.Aimbot.ShowFOV = v end)
CreateToggle(aimPage, "Visibility Check", Config.Aimbot.VisCheck, function(v) Config.Aimbot.VisCheck = v end)
CreateSlider(aimPage, "FOV Radius", 30, 500, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)
CreateSlider(aimPage, "Smoothness", 1, 20, Config.Aimbot.Smooth, function(v) Config.Aimbot.Smooth = v end)

local knifePage = CreateTab("Knife Control")
CreateToggle(knifePage, "Enable Knife Steering", Config.KnifeControl.Enabled, function(v) Config.KnifeControl.Enabled = v end)
CreateToggle(knifePage, "Predict Movement", Config.KnifeControl.PredictMovement, function(v) Config.KnifeControl.PredictMovement = v end)
CreateSlider(knifePage, "Knife Speed", 20, 500, Config.KnifeControl.GuideSpeed, function(v) Config.KnifeControl.GuideSpeed = v end)
CreateSlider(knifePage, "Arc Curve Height", 0, 50, Config.KnifeControl.ArcHeight, function(v) Config.KnifeControl.ArcHeight = v end)
CreateSlider(knifePage, "Control Radius", 50, 1500, Config.KnifeControl.ControlRadius, function(v) Config.KnifeControl.ControlRadius = v end)

local settingsPage = CreateTab("Settings")
CreateToggle(settingsPage, "Global Team Check", Config.Settings.TeamCheck, function(v) Config.Settings.TeamCheck = v end)

CreateButton(settingsPage, "Unload Script & Teleport Lock", function()
	getgenv().AlreadyLoaded = false

	if TeleportConn then
		pcall(function() TeleportConn:Disconnect() end)
		TeleportConn = nil
	end

	for _, conn in ipairs(Connections) do
		pcall(function() conn:Disconnect() end)
	end
	Connections = {}

	ClearAllESP()

	if ScreenGui then
		pcall(function() ScreenGui:Destroy() end)
	end
end)

for name, tData in pairs(Tabs) do
	tData.Ind.Visible = true
	tData.Btn.TextColor3 = Config.Settings.AccentColor
	Pages[name].Visible = true
	break
end

local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
	end
end)

BindSignal(UserInputService.InputChanged, function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

BindSignal(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

BindSignal(UserInputService.InputBegan, function(input, gpe)
	if not gpe and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert) then
		MainFrame.Visible = not MainFrame.Visible
	end
end)

BindSignal(RunService.RenderStepped, function()
	if Config.Aimbot.ShowFOV then
		local mousePos = UserInputService:GetMouseLocation()
		FOVCircle.Size = UDim2.new(0, Config.Aimbot.FOV * 2, 0, Config.Aimbot.FOV * 2)
		FOVCircle.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
		FOVCircle.Visible = true
	else
		FOVCircle.Visible = false
	end

	if Config.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local target = GetClosestTarget()
		if target then
			local smoothFactor = math.clamp(1 / math.max(Config.Aimbot.Smooth, 1), 0.01, 1)
			Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, target.Position), smoothFactor)
		end
	end

	if Config.ESP.Enabled then
		for _, plr in ipairs(Players:GetPlayers()) do
			UpdatePlayerESP(plr)
		end
	else
		ClearAllESP()
	end

	ProcessKnifeControl()
end)
