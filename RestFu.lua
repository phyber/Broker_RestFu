local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LQT = LibStub("LibQTip-1.0")
--local L = LibStub("AceLocale-3.0"):GetLocale("Broker_RestFu")
local abacus = LibStub("LibAbacus-3.0")
local crayon = LibStub("LibCrayon-3.0")
local dataobj = LDB:NewDataObject("Broker_RestFu", {
	type = "data source",
	text = "RestFu",
	icon = "Interface\\AddOns\\Broker_RestFu\\icon.tga",
})
local icon = LibStub("LibDBIcon-1.0")
local time = time
local pairs = pairs
local ipairs = ipairs
local string_format = string.format
local table_sort = table.sort
local GetRealmName = GetRealmName
local GetRealZoneText = GetRealZoneText
local GetXPExhaustion = GetXPExhaustion
local GetAddOnMetadata = GetAddOnMetadata
local IsResting = IsResting
local UnitXP = UnitXP
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local UnixXPMax = UnitXPMax
local UnitFactionGroup = UnitFactionGroup
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local maxLevel = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]
local timerSched = {}

Broker_RestFu = LibStub("AceAddon-3.0"):NewAddon("Broker_RestFu", "AceEvent-3.0", "AceTimer-3.0")
local self, Broker_RestFu = Broker_RestFu, Broker_RestFu
local db
local tooltip
local defaults = {
	profile = {
		minimap = {
			hide = false,
		},
	},
	global = {},
}

local function GetOptions(uiType, uiName, appName)
	if appName == "Broker_RestFu-General" then
		local options = {
			type = "group",
			name = GetAddOnMetadata("Broker_RestFu", "Title"),
			get = function(info) return db[info[#info]] end,
			set = function(info, value)
				db[info[#info]] = value
				Broker_RestFu:UpdateData()
			end,
			args = {
				brfudesc = {
					type = "description",
					order = 0,
					name = GetAddOnMetadata("Broker_RestFu", "Notes"),
				},
				minimap = {
					name = "Minimap Icon",
					desc = "Toggle minimap icon",
					type = "toggle",
					order = 10,
					get = function() return not db.minimap.hide end,
					set = function()
						db.minimap.hide = not db.minimap.hide
						if db.minimap.hide then
							icon:Hide("Broker_RestFu")
						else
							icon:Show("Broker_RestFu")
						end
					end,
				},
			},
		}
		return options
	end
end

function Broker_RestFu:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("Broker_RestFuDB", defaults, true)
	db = self.db.profile

	-- Minimap Icon
	icon:Register("Broker_RestFu", dataobj, db.minimap)

	-- Options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Broker_RestFu-General", GetOptions)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_RestFu-General", GetAddOnMetadata("Broker_RestFu", "Title"))
end

function Broker_RestFu:OnEnable()
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "Save")
	self:RegisterEvent("PLAYER_XP_UPDATE", "Save")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Save")
	self:RegisterEvent("TIME_PLAYED_MSG")

	timerSched.TimePlayed = self:ScheduleRepeatingTimer("OnUpdate_TimePlayed", 1)

	self:Save()
end

function Broker_RestFu:Save()
	local zone = GetRealZoneText()
	if zone == nil or zone == "" then
		self:ScheduleTimer("Save", 5)
	elseif UnitLevel("player") ~= 0 then
		local char = UnitName("player")
		local realm = GetRealmName()
		-- Create tables for realms and characters if they don't
		-- exist yet.
		if not self.db.global[realm] then
			self.db.global[realm] = {}
		end
		if not self.db.global[realm][char] then
			self.db.global[realm][char] = {}
		end
		local t = self.db.global[realm][char]
		local _
		t.level = UnitLevel("player")
		t.currXP = UnitXP("player")
		t.nextXP = UnitXPMax("player")
		t.faction = UnitFactionGroup("player")
		_, t.localrace = UnitRace("player")
		t.class, t.localclass = UnitClass("player")
		t.restXP = GetXPExhaustion() or 0
		t.isResting = IsResting() and true or false
		t.zone = zone
		t.realm = realm
		t.time = time()

		if self.timePlayed then
			t.timePlayed = self.timePlayed + time() - self.timePlayedMsgTime
		elseif not t.timePlayed then
			t.timePlayed = 0
		end

		t.lastPlayed = time()
	end
end

function Broker_RestFu:OnUpdate_TimePlayed()
	if timerSched.TimePlayed then
		if self:CancelTimer(timerSched.TimePlayed) then
			timerSched.TimePlayed = nil
		end
	end
	RequestTimePlayed()
end

function Broker_RestFu:TIME_PLAYED_MSG(event, totaltime, leveltime)
	if timerSched.TimePlayed then
		if self:CancelTimer(timerSched.TimePlayed) then
			timerSched.TimePlayed = nil
		end
	end
	self.timePlayed = totaltime
	self.timePlayedMsgTime = time()
	self:Save()
end

local percentPerSecond = 0.05 / 28800
local pandaPercentPerSecond = 0.1 / 28800
function Broker_RestFu:UpdateRestXPData(realm, char)
	if not realm or not char then
		return
	end
	local now = time()
	local t = self.db.global[realm][char]
	local multiplier = 1.5
	local PPS = percentPerSecond
	if t.localrace == "Pandaren" then
		PPS = pandaPercentPerSecond
		multiplier = 3
	end
	if t.level ~= maxLevel and t.restXP < t.nextXP * multiplier then
		local seconds = now - t.time
		local gained = t.nextXP * PPS * seconds
		if not t.isResting then
			gained = gained / 4
		end
		t.time = now
		t.restXP = t.restXP + gained
		if t.restXP > t.nextXP * multiplier then
			t.restXP = t.nextXP * multiplier
		end
	end
end

local realms
local chars
function Broker_RestFu:DrawTooltip()
	tooltip:Hide()
	tooltip:Clear()

	local myFont
	if not Broker_RestFu_Tooltip_Font then
		myFont = CreateFont("Broker_RestFu_Tooltip_Font")
		local filename, size, flags = tooltip:GetFont():GetFont()
		myFont:SetFont(filename, size, flags)
		myFont:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		myFont = Broker_RestFu_Tooltip_Font
	end
	tooltip:SetFont(myFont)

	local linenum
	local now = time()
	local totalTimePlayed = 0
	local NFC = ("%02x%02x%02x"):format(
		NORMAL_FONT_COLOR.r * 255,
		NORMAL_FONT_COLOR.g * 255,
		NORMAL_FONT_COLOR.b * 255
	)

	-- Header
	tooltip:AddHeader(nil, nil, nil, GetAddOnMetadata("Broker_RestFu", "Title"))
	tooltip:AddLine(" ")

	-- Generate a list of realms and chars the first time we build the tooltip
	if not realms then
		realms = {}
		chars = {}
		for realm, _ in pairs(self.db.global) do
			realms[#realms + 1] = realm
			chars[realm] = {}
			for char, _ in pairs(self.db.global[realm]) do
				chars[realm][#chars[realm] + 1] = char
			end
			table_sort(chars[realm])
		end
		table_sort(realms)
	end

	for realmCount, realm in ipairs(realms) do
		-- Ensure there is a blank line between each realm
		if realmCount ~= 1 then
			tooltip:AddLine(" ")
		end
		tooltip:AddHeader(realm, "Time Played", "Last Played", "Time to Rest", "Current XP", "Rest XP", "Zone")

		for _, char in ipairs(chars[realm]) do
			self:UpdateRestXPData(realm, char)
			local t = self.db.global[realm][char]
			local RCC = RAID_CLASS_COLORS[t.localclass]
			local classColor = string_format("%02x%02x%02x", RCC.r * 255, RCC.g * 255, RCC.b * 255)
			local lastPlayed
			if t.lastPlayed then
				lastPlayed = ("%s |cffffffffago|r"):format(abacus:FormatDurationCondensed(now - t.lastPlayed, true, true))
			else
				lastPlayed = "-"
			end
			local factionText = ""
			if t.faction == "Horde" then
				factionText = " |cffcf0000(H)|r"
			elseif t.faction == "Alliance" then
				factionText = " |cff0000cf(A)|r"
			end

			if t.level ~= maxLevel then
				local r, g, b = crayon:GetThresholdColor(t.restXP / t.nextXP, 0, 0.5, 1, 1.25, 1.5)
				local timePassed
				if t.localrace == "Pandaren" then
					timePassed = t.restXP / t.nextXP / pandaPercentPerSecond
				else
					timePassed = t.restXP / t.nextXP / percentPerSecond
				end
				local timeToMax = 864000 - timePassed
				if not t.isResting then
					timeToMax = timeToMax * 4
				end
				local playedTime
				if realm == GetRealmName() and char == UnitName("player") and self.timePlayed then
					playedTime = self.timePlayed + time() - self.timePlayedMsgTime
				else
					playedTime = t.timePlayed or 0
				end
				totalTimePlayed = totalTimePlayed + playedTime
				local charInfo = ("|cff%s|cff%s%s|r [|cffffffff%d|r]%s|r"):format(NFC, classColor, char, t.level or 0, factionText)
				local playedTimeText = abacus:FormatDurationCondensed(playedTime, true, true)
				tooltip:AddLine(
					charInfo,
					("|cff%s %s|r"):format(NFC, playedTimeText),
					lastPlayed,
					timeToMax > 0 and abacus:FormatDurationCondensed(timeToMax, true, true) or ("|cff00ff00%s|r"):format("Fully rested"),
					("%.0f%%"):format(t.currXP / t.nextXP * 100),
					("|cff%02x%02x%02x(%+.0f%%)|r"):format(r*255, g*255, b*255, t.restXP / t.nextXP * 100),
					("|cffffffff%s|r"):format(t.zone or "Unknown")
				)
			else
				local timePlayed
				if realm == GetRealmName() and char == UnitName("player") and self.timePlayed then
					playedTime = self.timePlayed + time() - self.timePlayedMsgTime
				else
					playedTime = t.timePlayed or 0
				end
				totalTimePlayed = totalTimePlayed + playedTime
				local charInfo = ("|cff%s|cff%s%s|r [|cffffffff%d|r]%s|r"):format(NFC, classColor, char, t.level or 0, factionText)
				tooltip:AddLine(
					charInfo,
					("|cff%s%s|r"):format(NFC, abacus:FormatDurationCondensed(playedTime, true, true)),
					lastPlayed,
					nil,
					nil,
					nil,
					("|cffffffff%s|r"):format(t.zone or "Unknown")
				)
			end
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(
		("|cffffffff%s|r"):format("Total time played"),
		nil, nil, nil, nil, nil,
		abacus:FormatDurationExtended(totalTimePlayed, true, true)
	)

	tooltip:UpdateScrolling()
	tooltip:Show()
end

-- LDB functions
function dataobj:OnEnter()
	if not LQT:IsAcquired("Broker_RestFu") then
		tooltip = LQT:Acquire("Broker_RestFuTip",
			-- Columns
			7,
			-- Alignments
			-- Realm, TimePlayed, LastPlayed, TimeToRest, CurrentXP, RestXP, Zone
			"LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "RIGHT"
		)
	end
	tooltip:Clear()
	tooltip:SmartAnchorTo(self)
	tooltip:SetAutoHideDelay(0.25, self)
	tooltip:SetScale(1)

	Broker_RestFu:DrawTooltip()
end

function dataobj:OnLeave()
	LQT:Release(tooltip)
	tooltip = nil
end

function dataobj:OnClick(button)
	if button == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory(GetAddOnMetadata("Broker_RestFu", "Title"))
	end
end
