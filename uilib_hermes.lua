--[=[
	UiLibrary.lua  (v1.1.1)
	A small, dependency-free UI library for Roblox — raw instances + UI Constraints.
	Client-side only: require this from a LocalScript.

	Quick start:
		local UI = require(ReplicatedStorage.UiLibrary)

		local win = UI.Window({ Title = "My Game" })
		local tab = win:Tab("Main")

		tab:Button({
			Text = "Go",
			Callback = function() print("hi") end,
		})

	Components: Window, Tab, Button, Toggle, Slider, TextBox, Dropdown, Label, Section, Divider.
	Theme: mutate UI.Theme globally, or pass Theme = {...} per window (merged over the defaults).
]=]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local UI = {}
UI.Version = "1.1.1"

-- ============================================================
-- THEME (defaults — dark + purple accent)
-- ============================================================

-- Font compatibility. Modern Roblox types the Font property as a Font class;
-- some executor/legacy host environments still type it as an enum (EnumItem).
-- Probe once at load and pick whichever the host accepts.
local function makeFonts()
	local okNormal, normal = pcall(function()
		return Font.new("rbxasset://fonts/families/GothamSSm.json")
	end)
	local okBold, bold = pcall(function()
		return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	end)
	if okNormal and okBold then
		local acceptsClass = pcall(function()
			local probe = Instance.new("TextLabel")
			probe.Font = normal
			probe:Destroy()
		end)
		if acceptsClass then
			return normal, bold
		end
	end
	-- Legacy fallback: enum fonts (GothamSSm exists on older clients).
	local okEnum1, enumNormal = pcall(function()
		return Enum.Font.GothamSSm
	end)
	local okEnum2, enumBold = pcall(function()
		return Enum.Font.GothamSSmBold
	end)
	if okEnum1 and okEnum2 then
		return enumNormal, enumBold
	end
	-- Last resort: SourceSans (present in every known Roblox version).
	return Enum.Font.SourceSans, Enum.Font.SourceSansBold
end

local themeFont, themeFontBold = makeFonts()

UI.Theme = {
	Font = themeFont,
	FontBold = themeFontBold,

	Background = Color3.fromRGB(19, 19, 26), -- window body
	Surface = Color3.fromRGB(26, 26, 35), -- title bar / sidebar
	Field = Color3.fromRGB(36, 36, 48), -- rows / inputs
	FieldHover = Color3.fromRGB(47, 47, 62),
	FieldPress = Color3.fromRGB(29, 29, 39),

	Accent = Color3.fromRGB(139, 92, 246), -- purple
	AccentHover = Color3.fromRGB(163, 122, 250),
	AccentPress = Color3.fromRGB(116, 74, 220),

	Text = Color3.fromRGB(240, 240, 245),
	TextMuted = Color3.fromRGB(146, 146, 163),
	Outline = Color3.fromRGB(52, 52, 68),
	Danger = Color3.fromRGB(240, 90, 90),

	RowHeight = 32,
	CornerRadius = 8,
}

-- ============================================================
-- HELPERS
-- ============================================================

local function new(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

local function tween(obj, props, duration)
	TweenService:Create(
		obj,
		TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local function lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- Hover-only feedback (background color).
local function bindHover(obj, base, hover, baseTrans, hoverTrans)
	obj.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			tween(obj, { BackgroundColor3 = hover, BackgroundTransparency = hoverTrans or 0 }, 0.1)
		end
	end)
	obj.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			tween(obj, { BackgroundColor3 = base, BackgroundTransparency = baseTrans or 0 }, 0.15)
		end
	end)
end

-- Press feedback + click callback, firing OnPress on RELEASE (button semantics).
-- Handles both mouse and touch; the same input object is tracked so nothing double-fires.
local function bindPress(obj, o)
	local pressedInput = nil
	local hovering = false

	local function paint(bg, trans)
		tween(obj, { BackgroundColor3 = bg, BackgroundTransparency = trans }, 0.12)
	end

	obj.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering = true
			if not pressedInput then
				paint(o.Hover, o.HoverTransparency or 0)
			end
		elseif (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) and o.OnPress then
			if pressedInput then return end
			pressedInput = input
			paint(o.Pressed or o.Hover, o.PressedTransparency or 0)
		end
	end)

	obj.InputEnded:Connect(function(input)
		if input == pressedInput then
			pressedInput = nil
			paint(
				hovering and o.Hover or o.Base,
				hovering and (o.HoverTransparency or 0) or (o.BaseTransparency or 0)
			)
			o.OnPress()
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering = false
			if not pressedInput then
				paint(o.Base, o.BaseTransparency or 0)
			end
		end
	end)
end

-- Input release detection. Some host environments don't expose
-- InputObject.IsPressed (observed on executor hosts) — probe each input and
-- fall back to UserInputState.End, then to "assume pressed" (once the input
-- ends, Changed stops firing, so the drag halts either way).
local function isInputPressed(input)
	local ok, pressed = pcall(function()
		return input.IsPressed
	end)
	if ok then
		return pressed
	end
	local ok2, state = pcall(function()
		return input.UserInputState
	end)
	if ok2 then
		return state ~= Enum.UserInputState.End
	end
	return true
end

-- ============================================================
-- WINDOW
-- ============================================================

function UI.Window(config)
	config = config or {}

	-- Theme: per-window overrides merged over the global defaults.
	local theme = {}
	for k, v in pairs(UI.Theme) do
		theme[k] = v
	end
	for k, v in pairs(config.Theme or {}) do
		theme[k] = v
	end

	local z = config.ZIndex or 100 -- base ZIndex; popups sit at z + 50
	local r = theme.CornerRadius
	local sidebarW = 110

	-- Declared up-front so closures created during construction (drag handler,
	-- button handlers) can never observe nil — some host environments fire
	-- input events before the constructor finishes.
	local win = {}
	local allDropdowns = {}
	local function closeAllDropdowns()
		for _, d in ipairs(allDropdowns) do
			d:close()
		end
	end

	-- Parent: use the provided one, otherwise create our own ScreenGui.
	local parent = config.Parent
	if not parent then
		local player = Players.LocalPlayer
		if not player then
			error("UiLibrary must be required from a LocalScript (client-side only)", 2)
		end
		parent = new("ScreenGui", {
			Name = "UiLibrary",
			ResetOnSpawn = false, -- survives respawns
			IgnoreGuiInset = true, -- not pushed down by the topbar
			DisplayOrder = config.DisplayOrder or 10,
		}, player:WaitForChild("PlayerGui"))
	end

	-- Root. CanvasGroup so the whole window can fade via GroupTransparency.
	local root = new("CanvasGroup", {
		Name = config.Name or "UiWindow",
		Size = config.Size or UDim2.fromScale(0.28, 0.55),
		Position = config.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.Background,
		ClipsDescendants = true,
		ZIndex = z,
	}, parent)
	corner(root, r)
	new("UIStroke", { Color = theme.Outline, Thickness = 1, Transparency = 0 }, root)

	-- Title bar (inset horizontally by the corner radius so its square corners
	-- don't poke out past the window's rounded ones).
	local titleBar = new("Frame", {
		Position = UDim2.new(0, r, 0, 0),
		Size = UDim2.new(1, -2 * r, 0, 36),
		BackgroundColor3 = theme.Surface,
		ZIndex = z + 1,
	}, root)

	-- Space reserved on the right of the title for the minimize/close buttons.
	local rightReserve = 12
	if config.Minimizable ~= false then
		rightReserve = rightReserve + 44
	end
	if config.Closable ~= false then
		rightReserve = rightReserve + 44
	end

	new("TextLabel", {
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -rightReserve, 1, 0),
		BackgroundTransparency = 1,
		Text = config.Title or "UI",
		TextColor3 = theme.Text,
		Font = theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = z + 1,
	}, titleBar)

	-- Minimize button (collapses the window to the title bar; drawn with frames).
	local minimizeBtn = nil
	if config.Minimizable ~= false then
		minimizeBtn = new("Frame", {
			Position = UDim2.new(1, -88, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			ZIndex = z + 1,
		}, titleBar)
		corner(minimizeBtn, 6)
		local barMin = new("Frame", {
			Position = UDim2.fromOffset(6, 13),
			Size = UDim2.fromOffset(16, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.TextMuted,
		}, minimizeBtn)
		local barRestore1 = new("Frame", {
			Position = UDim2.fromOffset(6, 9),
			Size = UDim2.fromOffset(16, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.TextMuted,
			Visible = false,
		}, minimizeBtn)
		local barRestore2 = new("Frame", {
			Position = UDim2.fromOffset(6, 15),
			Size = UDim2.fromOffset(16, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.TextMuted,
			Visible = false,
		}, minimizeBtn)
		bindPress(minimizeBtn, {
			Base = theme.Surface,
			Hover = theme.FieldHover,
			Pressed = theme.FieldPress,
			OnPress = function()
				win:SetMinimized(not win._minimized)
			end,
		})
		win._setMinimizeGlyph = function(minimized)
			barMin.Visible = not minimized
			barRestore1.Visible = minimized
			barRestore2.Visible = minimized
		end
	end

	-- Close button (drawn as a frame "x", no font-glyph dependency).
	local closeBtn = nil
	if config.Closable ~= false then
		closeBtn = new("Frame", {
			Position = UDim2.new(1, -44, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			ZIndex = z + 1,
		}, titleBar)
		corner(closeBtn, 6)
		new("Frame", {
			Position = UDim2.fromOffset(6, 13),
			Size = UDim2.fromOffset(16, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = theme.TextMuted,
		}, closeBtn)
		new("Frame", {
			Position = UDim2.fromOffset(6, 13),
			Size = UDim2.fromOffset(16, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = -45,
			BackgroundColor3 = theme.TextMuted,
		}, closeBtn)
		bindPress(closeBtn, {
			Base = theme.Surface,
			Hover = lerp(theme.Surface, theme.Danger, 0.55),
			Pressed = theme.FieldPress,
			OnPress = function()
				win:Toggle()
			end,
		})
	end

	-- Drag: keep the Position's Scale parts (responsive placement) and only
	-- accumulate the mouse delta into the Offset parts. Clamped to the screen.
	titleBar.InputBegan:Connect(function(input, gObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		-- Don't start a drag when grabbing the minimize/close buttons.
		if minimizeBtn and gObject and gObject:IsDescendantOf(minimizeBtn) then
			return
		end
		if closeBtn and gObject and gObject:IsDescendantOf(closeBtn) then
			return
		end
		closeAllDropdowns()
		local startScale = root.Position
		local start = input.Position
		local conn
		conn = input.Changed:Connect(function()
			if not isInputPressed(input) then
				conn:Disconnect()
				return
			end
			local delta = input.Position - start
			local screen = root.Parent.AbsoluteSize
			local size = root.AbsoluteSize
			local xOff = startScale.X.Offset + delta.X
			local yOff = startScale.Y.Offset + delta.Y
			local margin = 8
			if size.X > 0 and size.X + margin * 2 <= screen.X then
				xOff = math.clamp(
					xOff,
					margin - startScale.X.Scale * screen.X,
					screen.X - size.X - margin - startScale.X.Scale * screen.X
				)
			end
			if size.Y > 0 and size.Y + margin * 2 <= screen.Y then
				yOff = math.clamp(
					yOff,
					margin - startScale.Y.Scale * screen.Y,
					screen.Y - size.Y - margin - startScale.Y.Scale * screen.Y
				)
			end
			root.Position = UDim2.new(startScale.X.Scale, xOff, startScale.Y.Scale, yOff)
		end)
	end)

	-- Sidebar (tab list).
	local sidebar = new("Frame", {
		Position = UDim2.new(0, r, 0, 36),
		Size = UDim2.new(0, sidebarW, 1, -36),
		BackgroundColor3 = theme.Surface,
		ZIndex = z + 1,
	}, root)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, sidebar)
	local sidebarList = new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, sidebar)

	-- Content area (tab pages live here).
	local contentFrame = new("Frame", {
		Position = UDim2.new(0, sidebarW + r + 12, 0, 48),
		Size = UDim2.new(1, -(sidebarW + 2 * r + 24), 1, -60),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
	}, root)

	-- ============================================================
	-- WINDOW OBJECT
	-- ============================================================

	win._theme = theme
	win._root = root
	win._parent = parent
	win._z = z
	win._tabs = {}
	win._tabOrder = {}
	win._sidebar = sidebar
	win._content = contentFrame
	win._minimizeBtn = minimizeBtn
	win._minimized = false
	win._fullSize = nil
	win._dropdowns = allDropdowns

	local function refreshLayouts()
		for _, tab in ipairs(win._tabOrder) do
			tab:_refresh()
		end
	end

	function win:SetVisible(v)
		if v == root.Visible then return end
		if not v then
			closeAllDropdowns()
			root.GroupTransparency = 1
			root.Visible = false
		else
			root.Visible = true
			root.GroupTransparency = 1
			tween(root, { GroupTransparency = 0 }, 0.18)
			refreshLayouts()
		end
	end

	function win:SetMinimized(v)
		v = v == true
		if win._minimized == v then return end
		win._minimized = v
		closeAllDropdowns()
		if v then
			win._fullSize = root.Size
			-- Keep the title bar exactly where it is while the body collapses.
			local absPos = root.AbsolutePosition
			root.AnchorPoint = Vector2.new(0.5, 0)
			root.Position = UDim2.fromOffset(absPos.X + root.AbsoluteSize.X / 2, absPos.Y)
			tween(root, { Size = UDim2.new(win._fullSize.X.Scale, win._fullSize.X.Offset, 0, 36) }, 0.15)
			sidebar.Visible = false
			contentFrame.Visible = false
		else
			sidebar.Visible = true
			contentFrame.Visible = true
			tween(root, { Size = win._fullSize or config.Size or UDim2.fromScale(0.28, 0.55) }, 0.15)
			refreshLayouts()
		end
		if win._setMinimizeGlyph then
			win._setMinimizeGlyph(v)
		end
	end

	function win:Minimize()
		win:SetMinimized(not win._minimized)
	end

	function win:Toggle()
		win:SetVisible(not root.Visible)
	end

	function win:Destroy()
		closeAllDropdowns()
		for _, d in ipairs(win._dropdowns) do
			d:destroy()
		end
		root:Destroy()
	end

	-- ============================================================
	-- TABS
	-- ============================================================

	local function selectTab(tab)
		for _, t in ipairs(win._tabOrder) do
			local active = t == tab
			t._active = active
			t._page.Visible = active
			tween(t._button, {
				BackgroundColor3 = active and lerp(theme.Field, theme.Accent, 0.3) or theme.Field,
				BackgroundTransparency = active and 0 or 1,
			}, 0.12)
			tween(t._text, {
				TextColor3 = active and theme.Text or theme.TextMuted,
			}, 0.12)
			t._bar.Visible = active
			if active then
				t:_refresh()
			end
		end
	end

	local function makeTab(name)
		-- Sidebar button.
		local btn = new("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = theme.Field,
			BackgroundTransparency = 1,
			ZIndex = z + 1,
		}, sidebar)
		corner(btn, 6)
		local bar = new("Frame", {
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(3, 16),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = theme.Accent,
			Visible = false,
			ZIndex = z + 2,
		}, btn)
		corner(bar, 1.5)
		local txt = new("TextLabel", {
			Position = UDim2.new(0, 16, 0, 0),
			Size = UDim2.new(1, -20, 1, 0),
			BackgroundTransparency = 1,
			Text = name,
			TextColor3 = theme.TextMuted,
			Font = theme.Font,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = z + 2,
		}, btn)

		-- Tab page (scrolling, auto-sized canvas).
		local page = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Visible = false,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = theme.Outline,
			ScrollBarImageTransparency = 0.4,
			VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			ZIndex = z + 1,
		}, contentFrame)
		new("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, page)

		local tab = {
			_name = name,
			_page = page,
			_button = btn,
			_text = txt,
			_bar = bar,
			_active = false,
			_sliders = {},
		}

		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				selectTab(tab)
			elseif input.UserInputType == Enum.UserInputType.MouseMovement and not tab._active then
				tween(btn, { BackgroundColor3 = theme.Field, BackgroundTransparency = 0.8 }, 0.1)
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and not tab._active then
				tween(btn, { BackgroundTransparency = 1 }, 0.15)
			end
		end)

		-- Recompute anything that depends on layout (slider knobs).
		function tab:_refresh()
			for _, s in ipairs(tab._sliders) do
				s:refresh()
			end
		end

		-- ============================================================
		-- COMPONENTS
		-- ============================================================

		local rowCount = 0
		local function nextOrder()
			rowCount += 1
			return rowCount
		end

		local function makeRow(height)
			local row = new("Frame", {
				Size = UDim2.new(1, 0, 0, height),
				BackgroundColor3 = theme.Field,
				ZIndex = z + 2,
			}, page)
			corner(row, 6)
			return row
		end

		-- ---------- Button ----------

		function tab:Button(config)
			config = config or {}
			local row = makeRow(theme.RowHeight)
			local label = new("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = config.Text or "Button",
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 14,
				ZIndex = z + 3,
			}, row)
			local enabled = true
			bindPress(row, {
				Base = theme.Field,
				Hover = theme.FieldHover,
				Pressed = theme.FieldPress,
				OnPress = function()
					if enabled and config.Callback then
						config.Callback()
					end
				end,
			})
			local handle = {}
			function handle:SetText(t)
				label.Text = t
			end
			function handle:SetEnabled(v)
				enabled = v
				tween(row, {
					BackgroundColor3 = enabled and theme.Field or lerp(theme.Field, theme.Background, 0.6),
				}, 0.12)
				label.TextColor3 = enabled and theme.Text or theme.TextMuted
			end
			row.LayoutOrder = nextOrder()
			return handle
		end

		-- ---------- Toggle ----------

		function tab:Toggle(config)
			config = config or {}
			local state = config.Default == true
			local row = makeRow(theme.RowHeight)
			local label = new("TextLabel", {
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(1, -80, 0, 18),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = config.Text or "Toggle",
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = z + 3,
			}, row)
			local pill = new("Frame", {
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(44, 22),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = theme.Field,
				ZIndex = z + 3,
			}, row)
			corner(pill, 11)
			local knob = new("Frame", {
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = theme.TextMuted,
				ZIndex = z + 4,
			}, pill)
			corner(knob, 9)

			local handle = { Value = state }

			local function setState(v, fire)
				if state == v then
					if fire and config.Callback then
						config.Callback(v)
					end
					return
				end
				state = v
				handle.Value = v
				tween(pill, { BackgroundColor3 = v and theme.Accent or theme.Field }, 0.15)
				tween(knob, {
					Position = UDim2.new(0, v and 24 or 2, 0.5, 0),
					BackgroundColor3 = v and theme.Text or theme.TextMuted,
				}, 0.15)
				if fire and config.Callback then
					config.Callback(v)
				end
			end

			function handle:Set(v, fire)
				setState(v == true, fire ~= false)
			end

			bindHover(row, theme.Field, theme.FieldHover)
			row.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					setState(not state, true)
				end
			end)

			setState(state, false)
			row.LayoutOrder = nextOrder()
			return handle
		end

		-- ---------- Slider ----------

		function tab:Slider(config)
			config = config or {}
			local min = config.Min or 0
			local max = config.Max or 100
			local decimal = config.Decimal or 0
			local mult = 10 ^ decimal
			local value = math.clamp(config.Default or min, min, max)
			local range = max - min

			local row = makeRow(54)
			local nameLabel = new("TextLabel", {
				Position = UDim2.new(0, 12, 0, 8),
				Size = UDim2.new(1, -110, 0, 18),
				BackgroundTransparency = 1,
				Text = config.Text or "Slider",
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = z + 3,
			}, row)
			local valueLabel = new("TextLabel", {
				Position = UDim2.new(1, -12, 0, 8),
				Size = UDim2.fromOffset(64, 18),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Text = "",
				TextColor3 = theme.Accent,
				Font = theme.FontBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = z + 3,
			}, row)
			local track = new("Frame", {
				Position = UDim2.new(0, 12, 0, 34),
				Size = UDim2.new(1, -24, 0, 8),
				BackgroundColor3 = theme.Surface,
				ZIndex = z + 3,
			}, row)
			corner(track, 4)
			local fill = new("Frame", {
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = theme.Accent,
				ZIndex = z + 4,
			}, track)
			corner(fill, 4)
			local knob = new("Frame", {
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = theme.Text,
				ZIndex = z + 5,
			}, track)
			corner(knob, 8)

			local handle = { Value = value, Min = min, Max = max }

			local function setValue(v, fire)
				local rounded = math.round(v * mult) / mult
				value = math.clamp(rounded, min, max)
				handle.Value = value
				local frac = range > 0 and (value - min) / range or 0
				fill.Size = UDim2.new(frac, 0, 1, 0)
				local tw = track.AbsoluteSize.X
				if tw > 0 then
					knob.Position = UDim2.new(0, frac * (tw - 16), 0.5, 0)
				end
				valueLabel.Text = tostring(value)
				if fire and config.Callback then
					config.Callback(value)
				end
			end

			function handle:Set(v, fire)
				setValue(v, fire ~= false)
			end

			local function updateFromInput(input)
				local rel = input.Position.X - track.AbsolutePosition.X
				local frac = math.clamp(rel / track.AbsoluteSize.X, 0, 1)
				setValue(min + range * frac, true)
			end

			track.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					updateFromInput(input)
					local conn
					conn = input.Changed:Connect(function()
						if not isInputPressed(input) then
							conn:Disconnect()
							return
						end
						updateFromInput(input)
					end)
				end
			end)

			-- Knob position needs real layout; re-apply when the tab shows.
			function handle:refresh()
				setValue(value, false)
			end
			table.insert(tab._sliders, handle)

			setValue(value, false)
			row.LayoutOrder = nextOrder()
			return handle
		end

		-- ---------- TextBox ----------

		function tab:TextBox(config)
			config = config or {}
			local row = makeRow(theme.RowHeight)
			local stroke = new("UIStroke", {
				Color = theme.Accent,
				Thickness = 1,
				Transparency = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}, row)
			local box = new("TextBox", {
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = config.Text or "",
				PlaceholderText = config.Placeholder or "",
				PlaceholderColor3 = theme.TextMuted,
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 14,
				ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = z + 3,
			}, row)

			local handle = { Value = box.Text }

			box.Focused:Connect(function()
				tween(stroke, { Transparency = 0 }, 0.1)
			end)
			box.FocusLost:Connect(function()
				tween(stroke, { Transparency = 1 }, 0.15)
				handle.Value = box.Text
				if config.Callback then
					config.Callback(box.Text)
				end
			end)

			function handle:Set(t)
				box.Text = t
				handle.Value = t
			end

			bindHover(row, theme.Field, theme.FieldHover)
			row.LayoutOrder = nextOrder()
			return handle
		end

		-- ---------- Dropdown ----------

		function tab:Dropdown(config)
			config = config or {}
			local options = {}
			for _, opt in ipairs(config.Options or {}) do
				table.insert(options, opt)
			end

			local selected = nil
			if config.Default and table.find(options, config.Default) then
				selected = config.Default
			else
				selected = options[1]
			end

			local row = makeRow(theme.RowHeight)
			local nameLabel = new("TextLabel", {
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(1, -170, 0, 18),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = config.Text or "Dropdown",
				TextColor3 = theme.TextMuted,
				Font = theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = z + 3,
			}, row)
			local valueLabel = new("TextLabel", {
				Position = UDim2.new(1, -34, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 18),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Text = tostring(selected or "—"),
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = z + 3,
			}, row)
			-- Chevron drawn from two rotated bars (no font-glyph dependency).
			local chev = new("Frame", {
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(12, 8),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ZIndex = z + 3,
			}, row)
			new("Frame", {
				Position = UDim2.fromOffset(3.17, 4.17),
				Size = UDim2.fromOffset(8, 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				BackgroundColor3 = theme.TextMuted,
			}, chev)
			new("Frame", {
				Position = UDim2.fromOffset(8.83, 4.17),
				Size = UDim2.fromOffset(8, 2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = -45,
				BackgroundColor3 = theme.TextMuted,
			}, chev)

			local isOpen = false
			local handle = { Value = selected }

			-- Popup + click-away blocker live as siblings of the window so the
			-- window's ClipsDescendants can't cut them off.
			local popup = new("Frame", {
				Size = UDim2.fromOffset(0, 0),
				BackgroundColor3 = theme.Surface,
				BackgroundTransparency = 1,
				Visible = false,
				ZIndex = z + 50,
			}, parent)
			corner(popup, 6)
			new("UIStroke", { Color = theme.Outline, Thickness = 1, Transparency = 0 }, popup)
			new("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}, popup)
			local popupList = new("UIListLayout", {
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, popup)

			local blocker = new("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Visible = false,
				ZIndex = z + 49,
			}, parent)

			local optionRows = {}
			for i, opt in ipairs(options) do
				local optRow = new("Frame", {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = theme.FieldHover,
					BackgroundTransparency = 1,
					ZIndex = z + 51,
				}, popup)
				corner(optRow, 5)
				local optLabel = new("TextLabel", {
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.new(1, -16, 0, 18),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Text = tostring(opt),
					TextColor3 = theme.Text,
					Font = theme.Font,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = z + 52,
				}, optRow)
				bindPress(optRow, {
					Base = theme.Surface,
					Hover = theme.FieldHover,
					Pressed = theme.FieldPress,
					BaseTransparency = 1,
					OnPress = function()
						select(opt, true)
					end,
				})
				table.insert(optionRows, { row = optRow, label = optLabel })
			end

			local function refreshOptions()
				for _, o in ipairs(optionRows) do
					o.label.TextColor3 = o.label.Text == tostring(selected)
						and theme.Accent
						or theme.Text
				end
			end

			local function select(opt, fire)
				if not table.find(options, opt) or opt == selected then
					return
				end
				selected = opt
				handle.Value = opt
				valueLabel.Text = tostring(opt)
				refreshOptions()
				if fire and config.Callback then
					config.Callback(opt)
				end
			end

			function handle:Set(opt, fire)
				select(opt, fire ~= false)
			end

			local function open()
				if #options == 0 then return end
				task.defer(function()
					local rowAbs = row.AbsolutePosition
					local rowSize = row.AbsoluteSize
					local screen = parent.AbsoluteSize
					local popupH = math.min(#options, 7) * 28 + 8
					popup.Size = UDim2.fromOffset(rowSize.X, popupH)
					local x = math.clamp(rowAbs.X, 8, math.max(8, screen.X - rowSize.X - 8))
					local y = rowAbs.Y + rowSize.Y + 2
					if y + popupH > screen.Y - 8 then
						y = rowAbs.Y - popupH - 2 -- flip up instead of overflowing
					end
					popup.Position = UDim2.fromOffset(x, y)
					popup.BackgroundTransparency = 1
					popup.Visible = true
					blocker.Visible = true
					tween(popup, { BackgroundTransparency = 0 }, 0.12)
					tween(chev, { Rotation = 180 }, 0.15)
				end)
				isOpen = true
			end

			local function close()
				if not isOpen then return end
				isOpen = false
				popup.Visible = false
				blocker.Visible = false
				tween(chev, { Rotation = 0 }, 0.15)
			end

			blocker.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					close()
				end
			end)

			bindPress(row, {
				Base = theme.Field,
				Hover = theme.FieldHover,
				Pressed = theme.FieldPress,
				OnPress = function()
					if isOpen then close() else open() end
				end,
			})

			local dropdown = { close = close, destroy = function()
				popup:Destroy()
				blocker:Destroy()
			end }
			table.insert(allDropdowns, dropdown)

			refreshOptions()
			row.LayoutOrder = nextOrder()
			return handle
		end

		-- ---------- Label ----------

		function tab:Label(text)
			local label = new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = text or "",
				TextColor3 = theme.Text,
				Font = theme.Font,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = z + 2,
			}, page)
			local handle = {}
			function handle:Set(t)
				label.Text = t
			end
			label.LayoutOrder = nextOrder()
			return handle
		end

		-- ---------- Section ----------

		function tab:Section(text)
			local row = new("Frame", {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				ZIndex = z + 2,
			}, page)
			new("Frame", {
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(3, 14),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = theme.Accent,
				ZIndex = z + 3,
			}, row)
			corner(row:FindFirstChildOfClass("Frame"), 1.5)
			new("TextLabel", {
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.new(1, -16, 0, 18),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Text = string.upper(text or "SECTION"),
				TextColor3 = theme.Accent,
				Font = theme.FontBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = z + 3,
			}, row)
			row.LayoutOrder = nextOrder()
		end

		-- ---------- Divider ----------

		function tab:Divider()
			local line = new("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = theme.Outline,
				ZIndex = z + 2,
			}, page)
			line.LayoutOrder = nextOrder()
			return line
		end

		return tab
	end

	function win:Tab(name, _config)
		local key = tostring(name)
		if win._tabs[key] then
			return win._tabs[key]
		end
		local tab = makeTab(key)
		win._tabs[key] = tab
		table.insert(win._tabOrder, tab)
		if #win._tabOrder == 1 then
			selectTab(tab)
		end
		return tab
	end

	return win
end

return UI
