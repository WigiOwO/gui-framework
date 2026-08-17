--[[
    UILib — standalone Roblox GUI library
    Dark sidebar-tab UI: Window > Tabs > Sections > Components
    Components: Toggle, Slider, Dropdown, Button, Label, SearchBar

    Usage:
        local UILib = loadstring(game:HttpGet("..."))() -- or require(path)
        local Window = UILib:CreateWindow({ Title = "BigFroot", SubTitle = "Steal an Egg" })
        local Tab = Window:CreateTab("Eggs", "🥚")
        Tab:CreateToggle({ Text = "Auto Steal", Default = false, Callback = function(v) end })
--]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UILib = {}
UILib.__index = UILib

--============================================================
-- THEME
--============================================================
local Theme = {
	Background     = Color3.fromRGB(10, 10, 14),
	Sidebar        = Color3.fromRGB(14, 14, 18),
	Panel          = Color3.fromRGB(18, 18, 24),
	PanelLight     = Color3.fromRGB(26, 26, 33),
	Stroke         = Color3.fromRGB(38, 38, 46),
	Accent         = Color3.fromRGB(255, 140, 20),   -- orange accent
	AccentDim      = Color3.fromRGB(120, 70, 20),
	Text           = Color3.fromRGB(235, 235, 240),
	SubText        = Color3.fromRGB(140, 140, 150),
	Toggle_On      = Color3.fromRGB(255, 140, 20),
	Toggle_Off     = Color3.fromRGB(50, 50, 58),
}

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

--============================================================
-- HELPERS
--============================================================
local function create(class, props, children)
	local inst = Instance.new(class)
	for prop, value in pairs(props or {}) do
		inst[prop] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
	})
end

local function tween(inst, props, time, style)
	TweenService:Create(inst, TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad), props):Play()
end

local function makeDraggable(frame, dragHandle)
	local dragging, dragInput, dragStart, startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

--============================================================
-- WINDOW
--============================================================
function UILib:CreateWindow(config)
	config = config or {}
	local title = config.Title or "UILib"
	local subTitle = config.SubTitle or ""

	-- destroy any previous instance with same name to allow re-execution
	local existing = PlayerGui:FindFirstChild("UILib_ScreenGui")
	if existing then existing:Destroy() end

	local ScreenGui = create("ScreenGui", {
		Name = "UILib_ScreenGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})

	local Main = create("Frame", {
		Name = "Main",
		Size = UDim2.fromOffset(760, 460),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		Parent = ScreenGui,
	}, { corner(10), stroke(Theme.Stroke, 1) })

	-- Top bar (title + drag handle)
	local TopBar = create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = Main,
	})

	create("TextLabel", {
		Text = title,
		Font = FONT_BOLD,
		TextSize = 16,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(196, 6),
		Size = UDim2.fromOffset(300, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TopBar,
	})

	create("TextLabel", {
		Text = subTitle,
		Font = FONT,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(196, 24),
		Size = UDim2.fromOffset(300, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = TopBar,
	})

	makeDraggable(Main, TopBar)

	-- Close button
	local CloseBtn = create("TextButton", {
		Text = "✕",
		Font = FONT_BOLD,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -34, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		AutoButtonColor = false,
		Parent = TopBar,
	}, { corner(6) })
	CloseBtn.MouseEnter:Connect(function()
		tween(CloseBtn, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(200, 60, 60) })
		tween(CloseBtn, { TextColor3 = Color3.new(1, 1, 1) })
	end)
	CloseBtn.MouseLeave:Connect(function()
		tween(CloseBtn, { BackgroundTransparency = 1 })
		tween(CloseBtn, { TextColor3 = Theme.SubText })
	end)
	CloseBtn.MouseButton1Click:Connect(function()
		ScreenGui:Destroy()
	end)

	-- Minimize button
	local MinimizeBtn = create("TextButton", {
		Text = "—",
		Font = FONT_BOLD,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -64, 0, 6),
		Size = UDim2.fromOffset(28, 28),
		AutoButtonColor = false,
		Parent = TopBar,
	}, { corner(6) })
	MinimizeBtn.MouseEnter:Connect(function()
		tween(MinimizeBtn, { BackgroundTransparency = 0, BackgroundColor3 = Theme.PanelLight })
	end)
	MinimizeBtn.MouseLeave:Connect(function()
		tween(MinimizeBtn, { BackgroundTransparency = 1 })
	end)

	local minimized = false
	local expandedSize = Main.Size
	local function toggleMinimize()
		minimized = not minimized
		if minimized then
			expandedSize = Main.Size
			Sidebar.Visible = false
			ContentArea.Visible = false
			tween(Main, { Size = UDim2.fromOffset(expandedSize.X.Offset, 44) }, 0.2)
			MinimizeBtn.Text = "▢"
		else
			tween(Main, { Size = expandedSize }, 0.2)
			task.delay(0.2, function()
				Sidebar.Visible = true
				ContentArea.Visible = true
			end)
			MinimizeBtn.Text = "—"
		end
	end
	MinimizeBtn.MouseButton1Click:Connect(toggleMinimize)

	-- Sidebar
	local Sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 176, 1, -44),
		Position = UDim2.fromOffset(0, 44),
		BackgroundColor3 = Theme.Sidebar,
		Parent = Main,
	})

	local TabList = create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local TabHolder = create("Frame", {
		Name = "TabHolder",
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		Parent = Sidebar,
	}, { TabList })

	-- Content area
	local ContentArea = create("Frame", {
		Name = "ContentArea",
		Size = UDim2.new(1, -176, 1, -44),
		Position = UDim2.fromOffset(176, 44),
		BackgroundTransparency = 1,
		Parent = Main,
	})

	local Window = setmetatable({
		ScreenGui = ScreenGui,
		Main = Main,
		Sidebar = Sidebar,
		TabHolder = TabHolder,
		ContentArea = ContentArea,
		Tabs = {},
		_tabOrder = 0,
	}, UILib)

	function Window:Close()
		ScreenGui:Destroy()
	end

	function Window:Toggle()
		toggleMinimize()
	end

	return Window
end

--============================================================
-- TAB
--============================================================
function UILib:CreateTab(name, icon)
	self._tabOrder += 1
	icon = icon or "•"

	local Button = create("TextButton", {
		Name = name .. "_TabButton",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = self._tabOrder,
		Parent = self.TabHolder,
	}, { corner(6) })

	create("TextLabel", {
		Text = icon,
		Font = FONT,
		TextSize = 14,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(20, 34),
		Parent = Button,
	})

	local Label = create("TextLabel", {
		Text = name,
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Button,
	})

	local Page = create("ScrollingFrame", {
		Name = name .. "_Page",
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.ContentArea,
	})

	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = Page,
	})

	local Tab = setmetatable({
		Name = name,
		Button = Button,
		Label = Label,
		Page = Page,
		Window = self,
		_order = 0,
	}, UILib)

	local function selectTab()
		for _, t in pairs(self.Tabs) do
			t.Page.Visible = false
			tween(t.Button, { BackgroundTransparency = 1 })
			tween(t.Label, { TextColor3 = Theme.SubText })
		end
		Page.Visible = true
		tween(Button, { BackgroundTransparency = 0 })
		tween(Label, { TextColor3 = Theme.Text })
	end

	Button.MouseButton1Click:Connect(selectTab)

	table.insert(self.Tabs, Tab)
	if #self.Tabs == 1 then selectTab() end

	return Tab
end

--============================================================
-- SHARED ROW WRAPPER
--============================================================
local function baseRow(tab, height)
	tab._order += 1
	return create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 40),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = tab._order,
		Parent = tab.Page,
	}, { corner(8), stroke() })
end

--============================================================
-- SECTION HEADER
--============================================================
function UILib:CreateSection(text)
	self._order += 1
	create("TextLabel", {
		Text = text,
		Font = FONT_BOLD,
		TextSize = 13,
		TextColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = self._order,
		Parent = self.Page,
	})
end

--============================================================
-- LABEL
--============================================================
function UILib:CreateLabel(text)
	local Row = baseRow(self, 32)
	create("TextLabel", {
		Text = text,
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Row,
	})
	return Row
end

--============================================================
-- BUTTON
--============================================================
function UILib:CreateButton(config)
	config = config or {}
	local Row = baseRow(self, 38)
	local Btn = create("TextButton", {
		Text = config.Text or "Button",
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		AutoButtonColor = false,
		Parent = Row,
	})
	Btn.MouseEnter:Connect(function() tween(Row, { BackgroundColor3 = Theme.PanelLight }) end)
	Btn.MouseLeave:Connect(function() tween(Row, { BackgroundColor3 = Theme.Panel }) end)
	Btn.MouseButton1Click:Connect(function()
		if config.Callback then config.Callback() end
	end)
	return Row
end

--============================================================
-- TOGGLE
--============================================================
function UILib:CreateToggle(config)
	config = config or {}
	local state = config.Default or false

	local Row = baseRow(self, 40)

	create("TextLabel", {
		Text = config.Text or "Toggle",
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -70, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Row,
	})

	local Switch = create("Frame", {
		Size = UDim2.fromOffset(40, 22),
		Position = UDim2.new(1, -50, 0.5, -11),
		BackgroundColor3 = state and Theme.Toggle_On or Theme.Toggle_Off,
		Parent = Row,
	}, { corner(11) })

	local Knob = create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = Switch,
	}, { corner(9) })

	local Click = create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = Row,
	})

	local function set(newState)
		state = newState
		tween(Switch, { BackgroundColor3 = state and Theme.Toggle_On or Theme.Toggle_Off })
		tween(Knob, { Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2) })
		if config.Callback then config.Callback(state) end
	end

	Click.MouseButton1Click:Connect(function() set(not state) end)

	return { Set = set, Get = function() return state end }
end

--============================================================
-- SLIDER
--============================================================
function UILib:CreateSlider(config)
	config = config or {}
	local min = config.Min or 0
	local max = config.Max or 100
	local value = math.clamp(config.Default or min, min, max)
	local suffix = config.Suffix or ""

	local Row = baseRow(self, 46)

	create("TextLabel", {
		Text = config.Text or "Slider",
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -100, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Row,
	})

	local ValueLabel = create("TextLabel", {
		Text = tostring(value) .. suffix,
		Font = FONT,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -90, 0, 4),
		Size = UDim2.fromOffset(80, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = Row,
	})

	local Track = create("Frame", {
		Size = UDim2.new(1, -20, 0, 6),
		Position = UDim2.fromOffset(10, 30),
		BackgroundColor3 = Theme.Toggle_Off,
		Parent = Row,
	}, { corner(3) })

	local function pct() return (value - min) / (max - min) end

	local Fill = create("Frame", {
		Size = UDim2.new(pct(), 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		Parent = Track,
	}, { corner(3) })

	local dragging = false

	local function setFromX(xPos)
		local rel = math.clamp((xPos - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
		value = math.floor(min + rel * (max - min) + 0.5)
		Fill.Size = UDim2.new(rel, 0, 1, 0)
		ValueLabel.Text = tostring(value) .. suffix
		if config.Callback then config.Callback(value) end
	end

	Track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return {
		Set = function(v)
			value = math.clamp(v, min, max)
			Fill.Size = UDim2.new(pct(), 0, 1, 0)
			ValueLabel.Text = tostring(value) .. suffix
		end,
		Get = function() return value end,
	}
end

--============================================================
-- DROPDOWN
--============================================================
function UILib:CreateDropdown(config)
	config = config or {}
	local options = config.Options or {}
	local selected = config.Default or options[1] or "None"
	local open = false

	local Row = baseRow(self, 40)
	Row.ClipsDescendants = false

	create("TextLabel", {
		Text = config.Text or "Dropdown",
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.5, -10, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Row,
	})

	local Selector = create("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.PanelLight,
		Size = UDim2.new(0.5, -10, 0, 28),
		Position = UDim2.new(0.5, 0, 0.5, -14),
		AutoButtonColor = false,
		Parent = Row,
	}, { corner(6), stroke() })

	local SelectedLabel = create("TextLabel", {
		Text = selected,
		Font = FONT,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -30, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = Selector,
	})

	create("TextLabel", {
		Text = "▾",
		Font = FONT,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -22, 0, 0),
		Size = UDim2.fromOffset(18, 28),
		Parent = Selector,
	})

	local ListFrame = create("Frame", {
		Visible = false,
		BackgroundColor3 = Theme.PanelLight,
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(0.5, -10, 0, #options * 26),
		ZIndex = 5,
		Parent = Row,
	}, { corner(6), stroke() })

	local ListLayout = create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ListFrame,
	})

	for i, opt in ipairs(options) do
		local OptBtn = create("TextButton", {
			Text = tostring(opt),
			Font = FONT,
			TextSize = 12,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.PanelLight,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = i,
			ZIndex = 5,
			Parent = ListFrame,
		})
		OptBtn.MouseEnter:Connect(function() tween(OptBtn, { BackgroundTransparency = 0 }) end)
		OptBtn.MouseLeave:Connect(function() tween(OptBtn, { BackgroundTransparency = 1 }) end)
		OptBtn.MouseButton1Click:Connect(function()
			selected = opt
			SelectedLabel.Text = tostring(opt)
			ListFrame.Visible = false
			open = false
			if config.Callback then config.Callback(opt) end
		end)
	end

	Selector.MouseButton1Click:Connect(function()
		open = not open
		ListFrame.Visible = open
	end)

	return {
		Set = function(v) selected = v; SelectedLabel.Text = tostring(v) end,
		Get = function() return selected end,
	}
end

--============================================================
-- SEARCH BAR (standalone, e.g. for a filter panel)
--============================================================
function UILib:CreateSearchBar(config)
	config = config or {}
	local Row = baseRow(self, 34)

	local Box = create("TextBox", {
		Text = "",
		PlaceholderText = config.Placeholder or "Search...",
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = Row,
	})

	create("TextLabel", {
		Text = "🔍",
		Font = FONT,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(18, 34),
		Parent = Row,
	})

	Box:GetPropertyChangedSignal("Text"):Connect(function()
		if config.Callback then config.Callback(Box.Text) end
	end)

	return { GetText = function() return Box.Text end }
end

return UILib