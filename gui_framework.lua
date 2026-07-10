--[[
	GuiFramework — Roblox Luau UI Library
	Theme: Cosmic Purple
	Single-file library for executors (loadstring) and Studio (require).

	Usage:
		local Library = (loadstring or require)(...)
		local Window = Library:CreateWindow({ Title = "...", Keybind = Enum.KeyCode.RightShift })
		local Tab = Window:AddTab("Main")
		Tab:AddToggle / AddSlider / AddDropdown / AddButton
		Library:Notify({ Title = "...", Message = "...", Duration = 3 })
]]

--==========================================================================
-- Services & Environment
--==========================================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Prefer gethui() (executor) -> CoreGui -> PlayerGui (Studio / fallback)
local function getTargetParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then return hui end
	end
	local ok, cg = pcall(function() return CoreGui end)
	if ok and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

--==========================================================================
-- Theme — Cosmic Purple
--==========================================================================
local Theme = {
	Background      = Color3.fromHex("#12101C"),
	Panel           = Color3.fromHex("#151024"),
	TitleBar        = Color3.fromHex("#181428"),
	Border          = Color3.fromHex("#2E2540"),
	AccentFill      = Color3.fromHex("#8A3FF0"),
	AccentHighlight = Color3.fromHex("#B571F0"),
	TextPrimary     = Color3.fromHex("#ECE8F5"),
	TextSecondary   = Color3.fromHex("#C9C0DA"),
	TextMuted       = Color3.fromHex("#8A7FA0"),
	ToggleOff       = Color3.fromHex("#2E2540"),
	ButtonHover     = Color3.fromHex("#1E1832"),
	TabActive       = Color3.fromHex("#1C1630"),
	NotificationBg  = Color3.fromHex("#1A1530"),

	-- Notification type accents (left bar)
	Success = Color3.fromHex("#4ADE80"),
	Info    = Color3.fromHex("#60A5FA"),
	Warning = Color3.fromHex("#FBBF24"),
	Error   = Color3.fromHex("#F87171"),
}

--==========================================================================
-- Layout Constants
--==========================================================================
local Layout = {
	WindowSize          = Vector2.new(520, 380),
	TitleBarHeight      = 32,
	SidebarWidth        = 100,
	ControlHeight       = 36,
	ControlPad          = 6,
	SectionPad          = 8,
	NotificationWidth   = 240,
	NotificationPad     = 10,
	ToggleTrackSize     = Vector2.new(40, 20),
	SliderBarHeight     = 6,
	DropdownOptionHeight= 28,
	RadiusSmall         = 6,
	RadiusLarge         = 8,
}

--==========================================================================
-- Tween Presets
--==========================================================================
local Easing = {
	Quick   = TweenInfo.new(0.12, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out),
	Normal  = TweenInfo.new(0.20, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out),
	Slide   = TweenInfo.new(0.30, Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
	Fade    = TweenInfo.new(0.20, Enum.EasingStyle.Quad,   Enum.EasingDirection.Out),
	Back    = TweenInfo.new(0.35, Enum.EasingStyle.Back,   Enum.EasingDirection.Out),
}

--==========================================================================
-- Helpers
--==========================================================================
local function create(className, props, children)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or Layout.RadiusSmall) })
end

local function stroke(color, thickness, transparency)
	return create("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	})
end

local function pad(padding)
	return create("UIPadding", {
		PaddingTop    = UDim.new(0, padding),
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft   = UDim.new(0, padding),
		PaddingRight  = UDim.new(0, padding),
	})
end

local function tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

--==========================================================================
-- Library State
--==========================================================================
local Library = {}
Library._windows = {}
Library._connections = {}
Library._toggleKey = Enum.KeyCode.RightShift

--==========================================================================
-- Notifications
--==========================================================================
do
	local notifGui = create("ScreenGui", {
		Name = "GuiFrameworkNotifications",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		IgnoreGuiInset = true,
	})
	-- Defer parenting until first use so require()-in-Studio doesn't error early.
	Library._notifGui = notifGui
	Library._notifContainer = nil
	Library._activeNotifs = {} -- ordered list of notification objects (top -> bottom)
end

local function ensureNotifGui()
	local gui = Library._notifGui
	if not gui.Parent then
		gui.Parent = getTargetParent()
	end
	if not Library._notifContainer then
		Library._notifContainer = create("Frame", {
			Name = "NotifContainer",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, Layout.NotificationWidth + Layout.NotificationPad * 2, 1, 0),
			Position = UDim2.new(1, -(Layout.NotificationWidth + Layout.NotificationPad * 2), 0, 0),
			AnchorPoint = Vector2.new(0, 0),
		}, {
			create("UIListLayout", {
				Padding = UDim.new(0, Layout.NotificationPad),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			pad(Layout.NotificationPad),
		})
		Library._notifContainer.Parent = gui
	end
	return Library._notifContainer
end

local function reflowNotifs()
	local container = Library._notifContainer
	if not container then return end
	-- UIListLayout handles vertical stacking automatically; nothing else needed.
end

local function typeColor(t)
	t = t and tostring(t):lower() or "info"
	if t == "success" then return Theme.Success end
	if t == "warning" then return Theme.Warning end
	if t == "error"   then return Theme.Error end
	return Theme.Info
end

function Library:Notify(config)
	config = config or {}
	ensureNotifGui()
	local container = Library._notifContainer

	local duration = config.Duration or 5
	local accent = typeColor(config.Type)

	local toast = create("Frame", {
		Name = "Notification",
		BackgroundColor3 = Theme.NotificationBg,
		Size = UDim2.new(1, 0, 0, 0), -- height set by AutomaticSize
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #Library._activeNotifs + 1,
	}, {
		corner(Layout.RadiusSmall),
		stroke(Theme.Border, 1, 0.4),
		create("Frame", { -- left accent bar
			Name = "Accent",
			BackgroundColor3 = accent,
			Size = UDim2.new(0, 3, 1, 0),
			BorderSizePixel = 0,
		}, { corner(2) }),
		create("Frame", { -- content holder
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			create("UIListLayout", {
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("TextLabel", { -- title
				Name = "Title",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = Theme.TextPrimary,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = config.Title or "Notification",
				LayoutOrder = 1,
			}),
			create("TextLabel", { -- message
				Name = "Message",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Theme.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				Text = config.Message or "",
				LayoutOrder = 2,
			}),
		}),
	})

	-- Slide-in from the right with Back easing
	toast.Position = UDim2.new(1, 40, 0, 0) -- start off-screen right (within container)
	toast.Parent = container

	-- Set initial transparency for fade-in feel
	toast.BackgroundTransparency = 1
	for _, d in ipairs(toast:GetDescendants()) do
		if d:IsA("TextLabel") then d.TextTransparency = 1 end
		if d:IsA("Frame") and d.Name == "Accent" then d.BackgroundTransparency = 1 end
	end

	tween(toast, Easing.Back, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
	for _, d in ipairs(toast:GetDescendants()) do
		if d:IsA("TextLabel") then tween(d, Easing.Fade, { TextTransparency = 0 }) end
		if d:IsA("Frame") and d.Name == "Accent" then tween(d, Easing.Fade, { BackgroundTransparency = 0 }) end
	end

	local notifObj = {}
	notifObj._toast = toast
	notifObj._dismissed = false

	function notifObj:Dismiss()
		if notifObj._dismissed then return end
		notifObj._dismissed = true
		-- exit animation
		tween(toast, Easing.Quick, { BackgroundTransparency = 1, Position = UDim2.new(1, 40, 0, 0) })
		for _, d in ipairs(toast:GetDescendants()) do
			if d:IsA("TextLabel") then tween(d, Easing.Quick, { TextTransparency = 1 }) end
			if d:IsA("Frame") and d.Name == "Accent" then tween(d, Easing.Quick, { BackgroundTransparency = 1 }) end
		end
		task.delay(0.15, function()
			toast:Destroy()
			-- remove from active list
			for i, n in ipairs(Library._activeNotifs) do
				if n == notifObj then table.remove(Library._activeNotifs, i) break end
			end
			reflowNotifs()
		end)
	end

	table.insert(Library._activeNotifs, notifObj)

	-- auto dismiss
	if duration and duration > 0 then
		task.delay(duration, function()
			notifObj:Dismiss()
		end)
	end

	return notifObj
end

--==========================================================================
-- Window
--==========================================================================
local Tab = {}   -- metatable-based
Tab.__index = Tab

local function newTab(window, name)
	local sidebarBtn = create("TextButton", {
		Name = name .. "TabBtn",
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
		AutoButtonColor = false,
	}, {
		corner(Layout.RadiusSmall),
		create("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.new(0, 16, 0, 0),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = Theme.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = name,
		}),
		create("Frame", {
			Name = "AccentBar",
			BackgroundColor3 = Theme.AccentFill,
			Size = UDim2.new(0, 2, 0, 0),
			Position = UDim2.new(0, 0, 0, 6),
			BorderSizePixel = 0,
			Visible = false,
		}, { corner(1) }),
	})
	sidebarBtn.Parent = window._sidebarList

	-- content frame (scrollable)
	local content = create("ScrollingFrame", {
		Name = name .. "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, Layout.ControlPad),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		pad(Layout.SectionPad),
	})
	content.Parent = window._contentPane

	local tab = setmetatable({
		_window    = window,
		_name      = name,
		_btn       = sidebarBtn,
		_label     = sidebarBtn:FindFirstChild("Label"),
		_accentBar = sidebarBtn:FindFirstChild("AccentBar"),
		_content   = content,
		_index     = #window._tabs + 1,
	}, Tab)

	-- selection behavior
	sidebarBtn.MouseButton1Click:Connect(function()
		window:SelectTab(tab)
	end)

	table.insert(window._tabs, tab)
	return tab
end

function Tab:AddToggle(config)
	config = config or {}
	local holder = create("Frame", {
		Name = (config.Name or "Toggle") .. "Toggle",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(1, -Layout.SectionPad * 2, 0, Layout.ControlHeight),
		LayoutOrder = self._nextOrder(),
	}, { corner(Layout.RadiusSmall), stroke(Theme.Border, 1, 0.5) })
	holder.Parent = self._content

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -Layout.ToggleTrackSize.X - 24, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Name or "Toggle",
	}).Parent = holder

	local track = create("TextButton", {
		Name = "Track",
		BackgroundColor3 = Theme.ToggleOff,
		Size = UDim2.new(0, Layout.ToggleTrackSize.X, 0, Layout.ToggleTrackSize.Y),
		Position = UDim2.new(1, -Layout.ToggleTrackSize.X - 12, 0.5, -Layout.ToggleTrackSize.Y / 2),
		AnchorPoint = Vector2.new(0, 0),
		Text = "",
		AutoButtonColor = false,
	}, { corner(Layout.ToggleTrackSize.Y / 2) })
	track.Parent = holder

	local knob = create("Frame", {
		Name = "Knob",
		BackgroundColor3 = Theme.TextPrimary,
		Size = UDim2.new(0, Layout.ToggleTrackSize.Y - 4, 0, Layout.ToggleTrackSize.Y - 4),
		Position = UDim2.new(0, 2, 0.5, -(Layout.ToggleTrackSize.Y - 4) / 2),
		BorderSizePixel = 0,
	}, { corner((Layout.ToggleTrackSize.Y - 4) / 2) })
	knob.Parent = track

	local state = config.Default and true or false
	local toggle = {}

	local function apply(animate)
		local knobX = state and (Layout.ToggleTrackSize.X - (Layout.ToggleTrackSize.Y - 4) - 2) or 2
		if animate then
			tween(knob, Easing.Normal, { Position = UDim2.new(0, knobX, 0.5, -(Layout.ToggleTrackSize.Y - 4) / 2) })
			tween(track, Easing.Normal, { BackgroundColor3 = state and Theme.AccentFill or Theme.ToggleOff })
		else
			knob.Position = UDim2.new(0, knobX, 0.5, -(Layout.ToggleTrackSize.Y - 4) / 2)
			track.BackgroundColor3 = state and Theme.AccentFill or Theme.ToggleOff
		end
	end
	apply(false)

	function toggle:Set(v, silent)
		state = v and true or false
		apply(true)
		if not silent and config.Callback then
			task.spawn(config.Callback, state)
		end
	end
	function toggle:Get()
		return state
	end

	track.MouseButton1Click:Connect(function()
		state = not state
		apply(true)
		if config.Callback then task.spawn(config.Callback, state) end
	end)

	return toggle
end

function Tab:AddSlider(config)
	config = config or {}
	local min = config.Min or 0
	local max = config.Max or 100
	local decimals = config.Decimals or 0
	local suffix = config.Suffix or ""
	local value = math.clamp(config.Default or min, min, max)

	local holder = create("Frame", {
		Name = (config.Name or "Slider") .. "Slider",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(1, -Layout.SectionPad * 2, 0, Layout.ControlHeight + 6),
		LayoutOrder = self._nextOrder(),
	}, { corner(Layout.RadiusSmall), stroke(Theme.Border, 1, 0.5) })
	holder.Parent = self._content

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, 0, 0, 18),
		Position = UDim2.new(0, 12, 0, 4),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Name or "Slider",
	}).Parent = holder

	local valueLabel = create("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -12, 0, 18),
		Position = UDim2.new(1, -12, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.AccentHighlight,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = tostring(value),
	})
	valueLabel.Parent = holder

	local bar = create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.ToggleOff,
		Size = UDim2.new(1, -24, 0, Layout.SliderBarHeight),
		Position = UDim2.new(0, 12, 1, -14),
		BorderSizePixel = 0,
	}, { corner(Layout.SliderBarHeight / 2) })
	bar.Parent = holder

	local fill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.AccentFill,
		Size = UDim2.new(0, 0, 1, 0),
		BorderSizePixel = 0,
	}, { corner(Layout.SliderBarHeight / 2) })
	fill.Parent = bar

	local knob = create("Frame", {
		Name = "Knob",
		BackgroundColor3 = Theme.TextPrimary,
		Size = UDim2.new(0, 12, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BorderSizePixel = 0,
	}, { corner(6), stroke(Theme.AccentFill, 1) })
	knob.Parent = bar

	local slider = {}
	local dragging = false

	local function fmt(v)
		if decimals and decimals > 0 then
			return string.format("%." .. decimals .. "f", v) .. suffix
		end
		return tostring(math.floor(v + 0.5)) .. suffix
	end

	local function apply()
		local pct = (max == min) and 0 or (value - min) / (max - min)
		pct = math.clamp(pct, 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		-- knob position relative to bar width (use scale)
		knob.Position = UDim2.new(pct, 0, 0.5, 0)
		valueLabel.Text = fmt(value)
	end
	apply()

	local function setFromMouse(x)
		local rel = x - bar.AbsolutePosition.X
		local w = bar.AbsoluteSize.X
		local pct = math.clamp(w > 0 and rel / w or 0, 0, 1)
		value = min + (max - min) * pct
		if decimals and decimals > 0 then
			value = tonumber(string.format("%." .. decimals .. "f", value)) or value
		else
			value = math.floor(value + 0.5)
		end
		apply()
		if config.Callback then task.spawn(config.Callback, value) end
	end

	local function onInputChanged(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFromMouse(UserInputService:GetMouseLocation().X)
		end
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			setFromMouse(input.Position.X)
		end
	end)
	UserInputService.InputBegan:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(onInputChanged)

	function slider:Set(v, silent)
		value = math.clamp(v, min, max)
		apply()
		if not silent and config.Callback then task.spawn(config.Callback, value) end
	end
	function slider:Get()
		return value
	end

	return slider
end

function Tab:AddDropdown(config)
	config = config or {}
	local options = config.Options or {}
	local current = config.Default

	local holder = create("Frame", {
		Name = (config.Name or "Dropdown") .. "Dropdown",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(1, -Layout.SectionPad * 2, 0, Layout.ControlHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._nextOrder(),
	}, { corner(Layout.RadiusSmall), stroke(Theme.Border, 1, 0.5) })
	holder.Parent = self._content

	local header = create("TextButton", {
		Name = "Header",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(1, 0, 0, Layout.ControlHeight),
		Text = "",
		AutoButtonColor = false,
	}, { corner(Layout.RadiusSmall) })
	header.Parent = holder

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Name or "Dropdown",
	}).Parent = header

	local valueLabel = create("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = current or (options[1] or ""),
	}).Parent = header

	local chevron = create("TextLabel", {
		Name = "Chevron",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 20, 1, 0),
		Position = UDim2.new(1, -24, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "▼",
	})
	chevron.Parent = header

	local list = create("Frame", {
		Name = "List",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, Layout.ControlHeight),
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Visible = false,
	}, { corner(Layout.RadiusSmall), stroke(Theme.Border, 1, 0.5) })
	list.Parent = holder

	local listLayout = create("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	listLayout.Parent = list

	local dropdown = {}
	local open = false

	local function setListHeight()
		local n = 0
		for _ in ipairs(options) do n = n + 1 end
		list.Size = UDim2.new(1, 0, 0, n * Layout.DropdownOptionHeight)
	end

	local function rebuildOptions()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for i, opt in ipairs(options) do
			local btn = create("TextButton", {
				Name = "Option_" .. tostring(opt),
				BackgroundColor3 = Theme.Panel,
				Size = UDim2.new(1, 0, 0, Layout.DropdownOptionHeight),
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
			}, {
				create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -24, 1, 0),
					Position = UDim2.new(0, 12, 0, 0),
					Font = Enum.Font.Gotham,
					TextSize = 13,
					TextColor3 = (opt == current) and Theme.AccentHighlight or Theme.TextSecondary,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = tostring(opt),
				}),
			})
			btn.MouseButton1Click:Connect(function()
				dropdown:Set(opt)
				dropdown:_close()
			end)
			btn.Parent = list
		end
		setListHeight()
	end

	function dropdown:Set(opt, silent)
		current = opt
		valueLabel.Text = tostring(opt)
		-- refresh highlight
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("TextButton") then
				local lbl = c:FindFirstChildOfClass("TextLabel")
				if lbl then
					lbl.TextColor3 = (c.Name == "Option_" .. tostring(opt)) and Theme.AccentHighlight or Theme.TextSecondary
				end
			end
		end
		if not silent and config.Callback then task.spawn(config.Callback, opt) end
	end
	function dropdown:Get()
		return current
	end
	function dropdown:UpdateOptions(newList)
		options = newList or {}
		local stillValid = false
		for _, o in ipairs(options) do
			if o == current then stillValid = true break end
		end
		if not stillValid then
			current = options[1]
			valueLabel.Text = current or ""
		end
		rebuildOptions()
	end

	function dropdown:_close()
		open = false
		tween(chevron, Easing.Quick, { TextColor3 = Theme.TextMuted })
		list.Visible = true
		-- collapse animation
		local t = TweenService:Create(list, Easing.Normal, { Size = UDim2.new(1, 0, 0, 0) })
		t:Play()
		t.Completed:Connect(function()
			if not open then list.Visible = false end
		end)
	end
	function dropdown:_open()
		open = true
		tween(chevron, Easing.Quick, { TextColor3 = Theme.AccentHighlight })
		list.Visible = true
		setListHeight()
		list.Size = UDim2.new(1, 0, 0, 0)
		tween(list, Easing.Normal, { Size = UDim2.new(1, 0, 0, #options * Layout.DropdownOptionHeight) })
	end

	header.MouseButton1Click:Connect(function()
		if open then dropdown:_close() else dropdown:_open() end
	end)

	-- init
	if not current and options[1] then current = options[1]; valueLabel.Text = tostring(current) end
	rebuildOptions()

	return dropdown
end

function Tab:AddButton(config)
	config = config or {}
	local holder = create("TextButton", {
		Name = (config.Name or "Button") .. "Button",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(1, -Layout.SectionPad * 2, 0, Layout.ControlHeight),
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = self._nextOrder(),
	}, { corner(Layout.RadiusSmall), stroke(Theme.Border, 1, 0.5) })
	holder.Parent = self._content

	create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = Theme.AccentHighlight,
		Text = config.Name or "Button",
	}).Parent = holder

	holder.MouseEnter:Connect(function()
		tween(holder, Easing.Quick, { BackgroundColor3 = Theme.ButtonHover })
	end)
	holder.MouseLeave:Connect(function()
		tween(holder, Easing.Quick, { BackgroundColor3 = Theme.Panel })
	end)
	holder.MouseButton1Click:Connect(function()
		-- press flash
		tween(holder, Easing.Quick, { BackgroundColor3 = Theme.AccentFill })
		task.delay(0.1, function()
			tween(holder, Easing.Quick, { BackgroundColor3 = Theme.ButtonHover })
		end)
		if config.Callback then task.spawn(config.Callback) end
	end)

	return {}
end

-- per-tab layout order counter (set up in newTab via closure below)
local TabMT = Tab
function Tab:_nextOrder()
	self._order = (self._order or 0) + 1
	return self._order
end

function Tab:Rename(newName)
	self._name = newName
	if self._label then
		self._label.Text = newName
	end
	if self._btn then
		self._btn.Name = newName .. "TabBtn"
	end
	if self._content then
		self._content.Name = newName .. "Content"
	end
end

function Tab:SetVisible(visible)
	self._btn.Visible = visible
	if not visible and self._window._activeTab == self then
		local nextTab = nil
		for _, t in ipairs(self._window._tabs) do
			if t ~= self and t._btn.Visible then
				nextTab = t
				break
			end
		end
		if nextTab then
			self._window:SelectTab(nextTab)
		else
			self._content.Visible = false
			self._window._activeTab = nil
		end
	elseif visible and not self._window._activeTab then
		self._window:SelectTab(self)
	end
end

function Tab:Destroy()
	if self._window._activeTab == self then
		local nextTab = nil
		for _, t in ipairs(self._window._tabs) do
			if t ~= self and t._btn.Visible then
				nextTab = t
				break
			end
		end
		if nextTab then
			self._window:SelectTab(nextTab)
		else
			self._window._activeTab = nil
		end
	end

	for i, t in ipairs(self._window._tabs) do
		if t == self then
			table.remove(self._window._tabs, i)
			break
		end
	end

	for i, t in ipairs(self._window._tabs) do
		t._index = i
	end

	if self._btn then self._btn:Destroy() end
	if self._content then self._content:Destroy() end
end

--==========================================================================
-- Window object
--==========================================================================
local WindowMT = {}
WindowMT.__index = WindowMT

function WindowMT:AddTab(name)
	local tab = newTab(self, name)
	if #self._tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function WindowMT:SelectTab(tab)
	if self._activeTab == tab then return end
	if self._activeTab then
		local prev = self._activeTab
		prev._content.Visible = false
		tween(prev._btn, Easing.Quick, { BackgroundTransparency = 1 })
		tween(prev._label, Easing.Quick, { TextColor3 = Theme.TextSecondary })
		prev._accentBar.Visible = false
		tween(prev._accentBar, Easing.Quick, { Size = UDim2.new(0, 2, 0, 0) })
	end
	self._activeTab = tab
	tab._content.Visible = true
	tween(tab._btn, Easing.Quick, { BackgroundTransparency = 0 })
	tween(tab._btn, Easing.Quick, { BackgroundColor3 = Theme.TabActive })
	tween(tab._label, Easing.Quick, { TextColor3 = Theme.TextPrimary })
	tab._accentBar.Visible = true
	tween(tab._accentBar, Easing.Normal, { Size = UDim2.new(0, 2, 1, -12) })
end

function WindowMT:CreateTab(name)
	return self:AddTab(name)
end

function WindowMT:GetTab(name)
	for _, t in ipairs(self._tabs) do
		if t._name == name then
			return t
		end
	end
	return nil
end

function WindowMT:SelectTabByName(name)
	local tab = self:GetTab(name)
	if tab then
		self:SelectTab(tab)
		return true
	end
	return false
end

function WindowMT:SelectTabByIndex(index)
	local tab = self._tabs[index]
	if tab then
		self:SelectTab(tab)
		return true
	end
	return false
end

function WindowMT:ToggleMinimize()
	self._minimized = not self._minimized
	if self._minimized then
		tween(self._body, Easing.Normal, { Size = UDim2.new(0, Layout.WindowSize.X, 0, Layout.TitleBarHeight) })
	else
		tween(self._body, Easing.Normal, { Size = UDim2.new(0, Layout.WindowSize.X, 0, Layout.WindowSize.Y) })
	end
end

function WindowMT:Destroy()
	for _, c in ipairs(self._connections) do c:Disconnect() end
	self._connections = {}
	if self._screenGui then self._screenGui:Destroy() end
	for i, w in ipairs(Library._windows) do
		if w == self then table.remove(Library._windows, i) break end
	end
end

--==========================================================================
-- Library: CreateWindow
--==========================================================================
function Library:CreateWindow(config)
	config = config or {}
	local parent = getTargetParent()

	local screenGui = create("ScreenGui", {
		Name = "GuiFrameworkWindow_" .. tostring(#self._windows + 1),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000 + #self._windows,
		IgnoreGuiInset = true,
		Enabled = true,
	})
	screenGui.Parent = parent

	local sizeX, sizeY = Layout.WindowSize.X, Layout.WindowSize.Y
	local body = create("Frame", {
		Name = "Body",
		BackgroundColor3 = Theme.Background,
		Size = UDim2.new(0, sizeX, 0, sizeY),
		Position = UDim2.new(0.5, -sizeX / 2, 0.5, -sizeY / 2),
		BorderSizePixel = 0,
	}, { corner(Layout.RadiusLarge), stroke(Theme.Border, 1, 0.3) })
	body.Parent = screenGui

	-- Title bar
	local titleBar = create("Frame", {
		Name = "TitleBar",
		BackgroundColor3 = Theme.TitleBar,
		Size = UDim2.new(1, 0, 0, Layout.TitleBarHeight),
		BorderSizePixel = 0,
	}, { corner(Layout.RadiusLarge) })
	titleBar.Parent = body
	-- mask bottom corners of title bar
	create("Frame", {
		Name = "Mask",
		BackgroundColor3 = Theme.TitleBar,
		Size = UDim2.new(1, 0, 0, Layout.RadiusLarge),
		Position = UDim2.new(0, 0, 1, -Layout.RadiusLarge),
		BorderSizePixel = 0,
	}).Parent = titleBar

	local grip = create("TextLabel", {
		Name = "Grip",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 20, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "⋮⋮",
	})
	grip.Parent = titleBar

	local title = create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 34, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = config.Title or "GuiFramework",
	})
	title.Parent = titleBar

	-- minimize button
	local minBtn = create("TextButton", {
		Name = "Minimize",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(1, -28, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Theme.TextMuted,
		Text = "—",
		AutoButtonColor = false,
	})
	minBtn.Parent = titleBar

	-- Sidebar
	local sidebar = create("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.new(0, Layout.SidebarWidth, 1, -Layout.TitleBarHeight),
		Position = UDim2.new(0, 0, 0, Layout.TitleBarHeight),
		BorderSizePixel = 0,
	}, { stroke(Theme.Border, 1, 0.6) })
	sidebar.Parent = body

	local sidebarList = create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.new(0, 4, 0, 4),
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	sidebarList.Parent = sidebar

	-- Content pane (holds tab content frames)
	local contentPane = create("Frame", {
		Name = "ContentPane",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -Layout.SidebarWidth, 1, -Layout.TitleBarHeight),
		Position = UDim2.new(0, Layout.SidebarWidth, 0, Layout.TitleBarHeight),
	}, { pad(Layout.SectionPad) })
	contentPane.Parent = body

	local window = setmetatable({
		_screenGui   = screenGui,
		_body        = body,
		_titleBar    = titleBar,
		_sidebarList = sidebarList,
		_contentPane = contentPane,
		_tabs        = {},
		_activeTab   = nil,
		_minimized   = false,
		_connections = {},
	}, WindowMT)

	-- Dragging via title bar using UserInputService + AbsolutePosition (no jump)
	local dragging = false
	local dragOffset = Vector2.new(0, 0)
	local function onInputBegan(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			-- handled in changed
		end
	end
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			local mousePos = UserInputService:GetMouseLocation()
			dragOffset = mousePos - body.AbsolutePosition
		end
	end)
	local dragConn = UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos = UserInputService:GetMouseLocation()
			local newPos = mousePos - dragOffset
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local curSize = body.AbsoluteSize
			local clampedX = math.clamp(newPos.X, 0, math.max(0, viewport.X - curSize.X))
			local clampedY = math.clamp(newPos.Y, 36, math.max(36, viewport.Y - curSize.Y))
			body.Position = UDim2.new(0, clampedX, 0, clampedY)
		end
	end)
	table.insert(window._connections, dragConn)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	-- Minimize
	minBtn.MouseButton1Click:Connect(function()
		window:ToggleMinimize()
	end)
	minBtn.MouseEnter:Connect(function()
		tween(minBtn, Easing.Quick, { TextColor3 = Theme.TextPrimary })
	end)
	minBtn.MouseLeave:Connect(function()
		tween(minBtn, Easing.Quick, { TextColor3 = Theme.TextMuted })
	end)

	-- Apply per-window keybind (sets the global toggle key)
	if config.Keybind then
		self:SetToggleKey(config.Keybind)
	end

	table.insert(self._windows, window)
	return window
end

--==========================================================================
-- Global toggle keybind
--==========================================================================
function Library:SetToggleKey(keycode)
	self._toggleKey = keycode
end

local function isTyping()
	local gui = UserInputService:GetFocusedTextBox()
	return gui ~= nil
end

local keyConn
keyConn = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if isTyping() then return end
	if input.KeyCode == Library._toggleKey then
		for _, w in ipairs(Library._windows) do
			if w._screenGui then
				w._screenGui.Enabled = not w._screenGui.Enabled
			end
		end
	end
end)
table.insert(Library._connections, keyConn)

--==========================================================================
-- Library: Destroy
--==========================================================================
function Library:Destroy()
	for _, w in ipairs(self._windows) do
		if w._screenGui then w._screenGui:Destroy() end
	end
	self._windows = {}
	if self._notifGui then self._notifGui:Destroy() end
	for _, c in ipairs(self._connections) do
		if c and c.Disconnect then c:Disconnect() end
	end
	self._connections = {}
end

--==========================================================================
-- Return
--==========================================================================
return Library