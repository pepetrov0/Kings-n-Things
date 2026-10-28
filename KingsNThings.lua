--[[ Kings-n-Things - buff bar for raid buffs and consumables (WotLK 3.3.5)
     A column of icons for the buffs you should have: grayed out while you
     lack one, in colour with a cooldown sweep and the time left while you
     have it. A buff is
     shown when the class that casts it is in the group. Blessings and
     shouts follow Rally's assignments when Rally is loaded, otherwise the
     same priority Rally's auto-assign uses.
     /knt on|off   show or hide the bar
     Shift-drag to move (snaps to the screen centre lines), right-click for
     options.

     File layout: Data > Helpers > Bar keys > Bar > Events > Slash.
]]

local _, MY_CLASS = UnitClass("player") -- never changes, so looked up once
local db

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local BUFFS = {
	KINGS  = { label = "Kings",  spell = "Greater Blessing of Kings",     auras = { "Blessing of Kings", "Greater Blessing of Kings" } },
	MIGHT  = { label = "Might",  spell = "Greater Blessing of Might",     auras = { "Blessing of Might", "Greater Blessing of Might" } },
	WISDOM = { label = "Wisdom", spell = "Greater Blessing of Wisdom",    auras = { "Blessing of Wisdom", "Greater Blessing of Wisdom" } },
	SANC   = { label = "Sanct",  spell = "Greater Blessing of Sanctuary", auras = { "Blessing of Sanctuary", "Greater Blessing of Sanctuary" } },
	FORT   = { label = "Fort",   spell = "Prayer of Fortitude",           auras = { "Power Word: Fortitude", "Prayer of Fortitude" } },
	SPIRIT = { label = "Spirit", spell = "Prayer of Spirit",              auras = { "Divine Spirit", "Prayer of Spirit" } },
	SHADOW = { label = "ShadP",  spell = "Prayer of Shadow Protection",   auras = { "Shadow Protection", "Prayer of Shadow Protection" } },
	MARK   = { label = "Wild",   spell = "Gift of the Wild",              auras = { "Mark of the Wild", "Gift of the Wild" } },
	THORNS = { label = "Thorns", spell = "Thorns",                        auras = { "Thorns" } },
	AI     = { label = "Int",    spell = "Arcane Brilliance",             auras = { "Arcane Intellect", "Arcane Brilliance" } },
	BSHOUT = { label = "BShout", spell = "Battle Shout",                  auras = { "Battle Shout" } },
	CSHOUT = { label = "CShout", spell = "Commanding Shout",              auras = { "Commanding Shout" } },
	HORN   = { label = "Horn",   spell = "Horn of Winter",                auras = { "Horn of Winter" } },
}

-- spell ids, used for icons and tooltips (works even if the spell isn't known)
local SPELL_IDS = {
	KINGS = 25898, MIGHT = 25782, WISDOM = 25894, SANC = 25899,
	FORT = 21562, SPIRIT = 27681, SHADOW = 27683,
	MARK = 21849, THORNS = 467, AI = 23028,
	BSHOUT = 6673, CSHOUT = 469, HORN = 57330,
}

-- without Rally: paladin #1 (by name) gives entry 1 for my class, #2 entry 2, ...
-- (the same priority as Rally's auto-assign)
local PALADIN_PRIORITY = {
	WARRIOR     = { "KINGS", "MIGHT", "SANC" },
	DEATHKNIGHT = { "KINGS", "MIGHT", "SANC" },
	ROGUE       = { "KINGS", "MIGHT" },
	HUNTER      = { "KINGS", "MIGHT", "WISDOM" },
	PALADIN     = { "KINGS", "WISDOM", "MIGHT", "SANC" },
	SHAMAN      = { "KINGS", "WISDOM", "MIGHT" },
	DRUID       = { "KINGS", "WISDOM", "MIGHT" },
	PRIEST      = { "KINGS", "WISDOM" },
	MAGE        = { "KINGS", "WISDOM" },
	WARLOCK     = { "KINGS", "WISDOM" },
}

local BAR_ORDER = { "KINGS", "MIGHT", "WISDOM", "SANC", "FORT", "SPIRIT", "SHADOW", "MARK", "THORNS", "AI", "BSHOUT", "CSHOUT", "HORN" }
local BAR_CASTER = { FORT = "PRIEST", SPIRIT = "PRIEST", SHADOW = "PRIEST", MARK = "DRUID", THORNS = "DRUID", AI = "MAGE", HORN = "DEATHKNIGHT" }
local THORNS_MAX = 10 -- Thorns is only cast in groups this small

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }
local BAR_GAP = 2
local ICON_SIZES = { 20, 24, 28, 32, 40, 48 }
local TEXT_SIZES = { 10, 12, 14, 16, 20, 24 }

-- consumables on the bar: matched by aura name, the icon is the one of the
-- aura found (a flask or elixir shows whichever one you drank)
-- WotLK elixir auras mostly drop the "Elixir of" part ("Mighty Thoughts"), so
-- they are matched by name, with "Elixir" in the name as a catch-all
local ELIXIR_AURAS = {}
for _, name in ipairs({ "Mighty Thoughts", "Mighty Defense", "Mighty Fortitude", "Mighty Agility", "Mighty Strength",
	"Lightning Speed", "Accuracy", "Armor Piercing", "Deadly Strikes", "Expertise", "Spellpower", "Demonslaying",
	"Spirit of the Guru", "Guru's Elixir", "Wrath Elixir" }) do ELIXIR_AURAS[name] = true end
local function IsFlask(name) return name:find("Flask") end
local function IsElixir(name) return ELIXIR_AURAS[name] or (name:find("Elixir") and not name:find("Flask")) end
-- nth: the nth matching aura (two elixirs can be active, one slot each)
local CONSUMABLES = {
	FOOD    = { unit = "player", match = function(n) return n == "Well Fed" end, icon = "Interface\\Icons\\Spell_Misc_Food" },
	FLASK   = { unit = "player", match = IsFlask, spell = 53760 }, -- Flask of Endless Rage, for the empty icon
	ELIXIR1 = { unit = "player", match = IsElixir, nth = 1, spell = 53748 }, -- Mighty Strength, for the empty icon
	ELIXIR2 = { unit = "player", match = IsElixir, nth = 2, spell = 53747 }, -- Elixir of Spirit
	ELIXIR3 = { unit = "player", match = IsElixir, nth = 3, spell = 53747 },
	PETFOOD = { unit = "pet", match = function(n) return n == "Well Fed" end, spell = 6991 }, -- read from the pet; Feed Pet icon for the empty slot
}

local CONSUMABLE_LABELS = { FOOD = "Well Fed", FLASK = "Flask", ELIXIR1 = "Elixir", ELIXIR2 = "Elixir", ELIXIR3 = "Elixir", PETFOOD = "Pet's Well Fed" }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function Size(obj, w, h)
	obj:SetWidth(w)
	obj:SetHeight(h)
end

local function SetShown(obj, shown)
	if shown then obj:Show() else obj:Hide() end
end

local function BuffIcon(key)
	local buff = BUFFS[key]
	if not buff.icon then
		buff.icon = select(3, GetSpellInfo(buff.spell)) or select(3, GetSpellInfo(SPELL_IDS[key]))
	end
	return buff.icon or FALLBACK_ICON
end

local function FormatLeft(t)
	if t >= 3600 then return math.floor(t / 3600 + 0.5) .. "h" end
	if t >= 60 then return math.floor(t / 60 + 0.5) .. "m" end
	return math.floor(t) .. "s"
end

local function Units()
	local t, n = {}, GetNumRaidMembers()
	if n > 0 then
		for i = 1, n do t[#t + 1] = "raid" .. i end
	else
		t[1] = "player"
		for i = 1, GetNumPartyMembers() do t[#t + 1] = "party" .. i end
	end
	return t
end

local function IconSize() return db.icon or 28 end
local function TextSize() return db.text or 14 end

-- time left on my aura: nil when absent, 0 when it has no timer; with the
-- aura index and, for the sweeper, its start and duration
local function AuraLeft(buff)
	for i = 1, 40 do
		local name, _, _, _, _, duration, expires = UnitBuff("player", i)
		if not name then return nil end
		for _, a in ipairs(buff.auras) do
			if a == name then
				if expires and expires > 0 and duration and duration > 0 then
					return math.max(expires - GetTime(), 0), i, expires - duration, duration
				end
				return 0, i
			end
		end
	end
end

-- time left on the matching aura (0 = no timer, nil = absent), its icon,
-- index and, for the sweeper, its start and duration
local function ConsumableInfo(key)
	local c = CONSUMABLES[key]
	local found = 0
	for i = 1, 40 do
		local name, _, tex, _, _, duration, expires = UnitBuff(c.unit, i)
		if not name then break end
		if c.match(name) then
			found = found + 1
			if found == (c.nth or 1) then
				if expires and expires > 0 and duration and duration > 0 then
					return math.max(expires - GetTime(), 0), tex, i, expires - duration, duration
				end
				return 0, tex, i
			end
		end
	end
	return nil, c.icon or (c.spell and select(3, GetSpellInfo(c.spell))) or FALLBACK_ICON
end

---------------------------------------------------------------------------
-- Bar keys
---------------------------------------------------------------------------
-- blessings and shouts aimed at my class: Rally's assignments when Rally is
-- loaded, otherwise the auto-assign priority per paladin
local function AssignedKeys(paladins, casters, shown)
	local assigns = Rally and Rally.Assigns and Rally.Assigns()
	if assigns and Rally.ASSIGN then
		for _, name in ipairs(casters) do
			local row = assigns[name]
			local key = row and row[MY_CLASS]
			if key and Rally.ASSIGN[key] then
				for _, bkey in ipairs(Rally.ASSIGN[key].buffs) do shown[bkey] = true end
			end
		end
		return
	end
	local priority = PALADIN_PRIORITY[MY_CLASS] or {}
	for i = 1, #paladins do
		if priority[i] then shown[priority[i]] = true end
	end
end

-- buff keys worth showing: the casting class is in the group, and for the
-- blessings and shouts that class has assigned them to my class
local function BarKeys()
	local present, shown = {}, {}
	local units = Units()
	local paladins, casters = {}, {} -- paladins (sorted by name), and everyone Rally assigns: paladins and warriors
	for _, u in ipairs(units) do
		local name = UnitName(u)
		local _, class = UnitClass(u)
		if class then
			present[class] = true
			if class == "PALADIN" then paladins[#paladins + 1] = name end
			if class == "PALADIN" or class == "WARRIOR" then casters[#casters + 1] = name end
		end
	end
	table.sort(paladins)
	AssignedKeys(paladins, casters, shown)
	if present.WARRIOR and not (shown.BSHOUT or shown.CSHOUT) then shown.BSHOUT, shown.CSHOUT = true, true end
	-- consumables lead: food, then a flask or else two elixirs, then the pet's food
	local keys = { "FOOD" }
	if ConsumableInfo("FLASK") then
		keys[#keys + 1] = "FLASK"
	else -- one icon per active elixir, a single gray one when there is none
		keys[#keys + 1] = "ELIXIR1"
		for n = 2, 3 do
			if ConsumableInfo("ELIXIR" .. n) then keys[#keys + 1] = "ELIXIR" .. n end
		end
	end
	if (MY_CLASS == "HUNTER" or MY_CLASS == "WARLOCK") and UnitExists("pet") then keys[#keys + 1] = "PETFOOD" end
	for _, key in ipairs(BAR_ORDER) do
		local caster = BAR_CASTER[key]
		-- a buff I actually have is always shown, whatever the assignments say
		local skip = key == "THORNS" and #units > THORNS_MAX
		if (caster and present[caster] or shown[key] or AuraLeft(BUFFS[key])) and not skip then keys[#keys + 1] = key end
	end
	return keys
end

---------------------------------------------------------------------------
-- Bar
---------------------------------------------------------------------------
local bar, barIcons = nil, {}
local UpdateBar -- BarMenu calls it before its definition

local SNAP = 12 -- pixels from the screen centre line where the bar snaps to it
local guideV, guideH

local function BarGuides()
	if guideV then return end
	guideV = UIParent:CreateTexture(nil, "OVERLAY")
	guideV:SetTexture(0, 0.8, 1)
	guideV:SetWidth(1)
	guideV:SetPoint("TOP", UIParent, "TOP")
	guideV:SetPoint("BOTTOM", UIParent, "BOTTOM")
	guideH = UIParent:CreateTexture(nil, "OVERLAY")
	guideH:SetTexture(0, 0.8, 1)
	guideH:SetHeight(1)
	guideH:SetPoint("LEFT", UIParent, "LEFT")
	guideH:SetPoint("RIGHT", UIParent, "RIGHT")
	guideV:Hide()
	guideH:Hide()
end

-- the bar's offset from the screen centre, pulled to 0 on an axis within SNAP
local function BarOffset()
	local cx, cy = bar:GetCenter()
	local ux, uy = UIParent:GetCenter()
	local ox, oy = cx - ux, cy - uy
	return ox, oy, math.abs(ox) < SNAP, math.abs(oy) < SNAP
end

local function SizeMenu(label, sizes, field, default)
	local list = {}
	for _, size in ipairs(sizes) do
		list[#list + 1] = { text = tostring(size), checked = (db[field] or default) == size,
			func = function() db[field] = size; CloseDropDownMenus(); UpdateBar() end }
	end
	return { text = label, hasArrow = true, notCheckable = true, menuList = list }
end

local function BarMenu()
	return {
		{ text = "Kings-n-Things", isTitle = true, notCheckable = true },
		{ text = "Horizontal", checked = db.horiz, keepShownOnClick = true,
			func = function() db.horiz = not db.horiz; UpdateBar() end },
		{ text = "Text on the other side", checked = db.flip, keepShownOnClick = true,
			func = function() db.flip = not db.flip; UpdateBar() end },
		SizeMenu("Icon size", ICON_SIZES, "icon", 28),
		SizeMenu("Text size", TEXT_SIZES, "text", 14),
	}
end

-- ElvUI restyles the background when present; never breaks the addon
local function Skin(frame)
	if ElvUI and frame.SetTemplate then pcall(frame.SetTemplate, frame, "Transparent") end
end

local function BuildBar()
	bar = CreateFrame("Frame", "KingsNThingsBar", UIParent)
	Size(bar, IconSize(), IconSize())
	bar:SetPoint("CENTER", UIParent, "CENTER", 450, 0)
	local bg = CreateFrame("Frame", nil, bar)
	bg:SetFrameLevel(bar:GetFrameLevel())
	bg:SetPoint("TOPLEFT", -3, 3)
	bg:SetPoint("BOTTOMRIGHT", 3, -3)
	bg:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	bg:SetBackdropColor(0, 0, 0, 0.8)
	Skin(bg)
	bar:SetMovable(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function(self)
		if not IsShiftKeyDown() then return end
		BarGuides()
		self:StartMoving()
		self:SetScript("OnUpdate", function()
			local _, _, snapX, snapY = BarOffset()
			guideV:SetAlpha(snapX and 1 or 0.3); guideH:SetAlpha(snapY and 1 or 0.3)
			guideV:Show(); guideH:Show()
		end)
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetScript("OnUpdate", nil)
		if guideV then guideV:Hide(); guideH:Hide() end
		local ox, oy, snapX, snapY = BarOffset()
		if snapX then ox = 0 end
		if snapY then oy = 0 end
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
		db.pos = { "CENTER", "CENTER", ox, oy }
	end)
	bar:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			if not KingsNThingsMenu then CreateFrame("Frame", "KingsNThingsMenu", UIParent, "UIDropDownMenuTemplate") end
			EasyMenu(BarMenu(), KingsNThingsMenu, "cursor", 0, 0, "MENU")
		end
	end)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Kings-n-Things")
		GameTooltip:AddLine("Right-click: options", 1, 1, 1)
		GameTooltip:AddLine("Shift-drag: move", 1, 1, 1)
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if db.pos then
		bar:ClearAllPoints()
		bar:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
	end
	bar:Hide()
end

local function GetBarIcon(i)
	if barIcons[i] then return barIcons[i] end
	local f = CreateFrame("Frame", nil, bar)
	Size(f, IconSize(), IconSize())
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f.tex:SetTexCoord(unpack(ICON_CROP))
	-- Blizzard's cooldown swipe, over the icon while the aura ticks down;
	-- reversed so a fresh buff is bright and darkens as it runs out, and
	-- opted out of OmniCC / ElvUI cooldown text (the bar has its own timer)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints()
	f.cd:SetReverse(true)
	f.cd.noCooldownCount, f.cd.noOCC = true, true
	-- on the icon, not the swipe: the swipe hides itself when it is cleared
	-- or runs out, and would take the text with it
	f.time = f:CreateFontString(nil, "OVERLAY")
	-- the icon shows the buff tooltip; drags and the options menu still reach the bar
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() bar:GetScript("OnDragStart")(bar) end)
	f:SetScript("OnDragStop", function() bar:GetScript("OnDragStop")(bar) end)
	f:SetScript("OnMouseUp", function(_, button) bar:GetScript("OnMouseUp")(bar, button) end)
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.auraIndex then
			GameTooltip:SetUnitBuff(self.unit, self.auraIndex)
		elseif self.spellId then
			GameTooltip:SetHyperlink("spell:" .. self.spellId)
		else
			GameTooltip:SetText(self.label or "")
		end
		GameTooltip:AddLine("Right-click: options, shift-drag: move", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	barIcons[i] = f
	return f
end

-- place icon i and its timer for the chosen direction and text side
local function PlaceBarIcon(f, i)
	local horiz, flip = db.horiz, db.flip
	local step = (i - 1) * (IconSize() + BAR_GAP)
	Size(f, IconSize(), IconSize())
	f.time:SetFont(DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT, TextSize(), "OUTLINE") -- the combat text font
	f:ClearAllPoints()
	f.time:ClearAllPoints()
	if horiz then
		f:SetPoint("LEFT", bar, "LEFT", step, 0)
		if flip then f.time:SetPoint("TOP", f, "BOTTOM", 0, -3) else f.time:SetPoint("BOTTOM", f, "TOP", 0, 3) end
	else
		f:SetPoint("TOP", bar, "TOP", 0, -step)
		if flip then f.time:SetPoint("LEFT", f, "RIGHT", 6, 0) else f.time:SetPoint("RIGHT", f, "LEFT", -6, 0) end
	end
end

function UpdateBar()
	if not bar then return end
	if db.off then bar:Hide() return end
	local keys = BarKeys()
	-- size, font and anchors only change with the options or the icon's slot,
	-- so they are applied when that signature differs, not on every tick
	local layout = table.concat({ IconSize(), TextSize(), tostring(db.horiz), tostring(db.flip) }, ":")
	for i, key in ipairs(keys) do
		local f = GetBarIcon(i)
		local left, icon, index, start, duration
		if CONSUMABLES[key] then
			left, icon, index, start, duration = ConsumableInfo(key)
			f.unit, f.spellId, f.label = CONSUMABLES[key].unit, nil, CONSUMABLE_LABELS[key]
		else
			left, index, start, duration = AuraLeft(BUFFS[key])
			icon = BuffIcon(key)
			f.unit, f.spellId, f.label = "player", SPELL_IDS[key], BUFFS[key].label
		end
		f.auraIndex = left and index or nil
		if f.layout ~= layout or f.slot ~= i then
			PlaceBarIcon(f, i)
			f.layout, f.slot = layout, i
		end
		f.tex:SetTexture(icon)
		f.tex:SetDesaturated(not left)
		f.tex:SetAlpha(key == "HORN" and not left and 0.5 or 1) -- its icon is already gray, so fade it instead
		f.tex:SetVertexColor(left and 1 or 0.6, left and 1 or 0.6, left and 1 or 0.6)
		-- the sweep is restarted only when the aura's timer changes, not on
		-- every tick, otherwise it would visibly jump back to full
		if duration and duration > 0 then
			if f.cdStart ~= start or f.cdDuration ~= duration then
				f.cdStart, f.cdDuration = start, duration
				CooldownFrame_SetTimer(f.cd, start, duration, 1)
			end
		elseif f.cdStart then
			f.cdStart, f.cdDuration = nil, nil
			CooldownFrame_SetTimer(f.cd, 0, 0, 0) -- clears the sweep
		end
		if left and left > 0 then
			f.time:SetText(FormatLeft(left))
			if left < 60 then f.time:SetTextColor(1, 0.15, 0.15) else f.time:SetTextColor(1, 1, 1) end
		else
			f.time:SetText("")
		end
		f:Show()
	end
	for i = #keys + 1, #barIcons do barIcons[i]:Hide() end
	local icon = IconSize()
	local length = math.max(#keys, 1) * (icon + BAR_GAP) - BAR_GAP
	if db.horiz then Size(bar, length, icon) else Size(bar, icon, length) end
	SetShown(bar, #keys > 0)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local tick = 0

driver:SetScript("OnUpdate", function(_, elapsed)
	tick = tick + elapsed
	if tick > 1 then tick = 0; UpdateBar() end
end)

driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function()
	if not KingsNThingsDB then
		KingsNThingsDB = {}
		-- first run: take over the bar settings from Rally, which used to own the bar
		local r = RallyDB
		if r then
			KingsNThingsDB.pos, KingsNThingsDB.horiz, KingsNThingsDB.flip = r.barPos, r.barHoriz, r.barFlip
			KingsNThingsDB.icon, KingsNThingsDB.text, KingsNThingsDB.off = r.barIcon, r.barText, r.barOff
		end
	end
	db = KingsNThingsDB
	BuildBar()
	UpdateBar()
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
SLASH_KINGSNTHINGS1 = "/knt"
SLASH_KINGSNTHINGS2 = "/kingsnthings"
SlashCmdList["KINGSNTHINGS"] = function(msg)
	msg = strlower(strtrim(msg or ""))
	if msg == "on" or msg == "off" then
		db.off = msg == "off" or nil
	else
		db.off = not db.off or nil
	end
	UpdateBar()
	print("|cff00ccffKings-n-Things:|r buff bar " .. (db.off and "off" or "on"))
end
