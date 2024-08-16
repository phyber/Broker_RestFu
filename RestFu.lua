local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LQT = LibStub("LibQTip-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Broker_RestFu")
local abacus = LibStub("LibAbacus-3.0")
local crayon = LibStub("LibCrayon-3.0")
local icon = LibStub("LibDBIcon-1.0")
local dataobj = LDB:NewDataObject("Broker_RestFu", {
	type = "data source",
	text = "RestFu",
	icon = "Interface\\AddOns\\Broker_RestFu\\icon.tga",
})

local time = time
local pairs = pairs
local ipairs = ipairs
local table_sort = table.sort
local GetAddOnMetadata = _G.GetAddOnMetadata or C_AddOns.GetAddOnMetadata
local GetRealmName = GetRealmName
local GetRealZoneText = GetRealZoneText
local GetXPExhaustion = GetXPExhaustion
local InCombatLockdown = InCombatLockdown
local IsResting = IsResting
local RequestTimePlayed = RequestTimePlayed
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitRace = UnitRace
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GUILD_ONLINE_LABEL = GUILD_ONLINE_LABEL
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local maxLevel = GetMaxLevelForPlayerExpansion()
local timerSched = {}
local purged = false
local addonOptionsFrameName

local ADDON_NOTES = GetAddOnMetadata("Broker_RestFu", "Notes")
local ADDON_TITLE = GetAddOnMetadata("Broker_RestFu", "Title")

Broker_RestFu = LibStub("AceAddon-3.0"):NewAddon("Broker_RestFu", "AceEvent-3.0", "AceTimer-3.0")
local Broker_RestFu = Broker_RestFu
local db
local tooltip
local defaults = {
	profile = {
		minimap = {
			hide = false,
		},
		filter = {
			realm = {},
			char = {},
		},
	},
	global = {},
}

local function GetOptions(uiType, uiName, appName)
	if appName == "Broker_RestFu-General" then
		local options = {
			type = "group",
			name = ADDON_TITLE,
			args = {
				brfudesc = {
					type = "description",
					order = 0,
					name = ADDON_NOTES,
				},
				minimap = {
					name = L["Minimap Icon"],
					desc = L["Toggle minimap icon"],
					type = "toggle",
					order = 10,
					get = function()
                        return not db.minimap.hide
                    end,
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

	if appName == "Broker_RestFu-Filter" then
		local options = {
			type = "group",
			name = L["Filter"],
			args = {
				brfufdesc = {
					type = "description",
					order = 0,
					name = "Filter specific characters or realms to hide them from the tooltip.",
				},
				filterrealm = {
					name = "Filter Realm",
					desc = "Select a realm to filter",
					type = "multiselect",
					order = 50,
					values = function()
						local t = {}

						for realm, _ in pairs(Broker_RestFu.db.global) do
							t[realm] = realm
						end

						return t
					end,
					get = function(info, value)
						return db.filter.realm[value] and true or false
					end,
					set = function(info, value)
						if db.filter.realm[value] then
							db.filter.realm[value] = nil
						else
							db.filter.realm[value] = true
						end
					end,
				},
			},
		}
		-- Generate character purge options
		local optOrder = 200
		for realm, _ in pairs(Broker_RestFu.db.global) do
			options.args["filterchar"..realm] = {
				name = (L["Filter Character from %s"]):format(realm),
				desc = L["Select a character to filter"],
				type = "multiselect",
				order = optOrder,
				values = function()
					local t = {}

					for char, _ in pairs(Broker_RestFu.db.global[realm]) do
						t[char] = char
					end

					return t
				end,
				get = function(info, value)
					if not db.filter.char[realm] then
						return false
					end

					return db.filter.char[realm][value] and true or false
				end,
				set = function(info, value)
					if not db.filter.char[realm] then
						db.filter.char[realm] = {}
					end

					if db.filter.char[realm][value] then
						db.filter.char[realm][value] = nil
					else
						db.filter.char[realm][value] = true
					end

					-- Check if we also need to purge the realm
					local count = 0
					for _ in pairs(db.filter.char[realm]) do
						count = count + 1
					end

					if count == 0 then
						db.filter.char[realm] = nil
					end
				end,
			}

			optOrder = optOrder + 5
		end

		return options
	end

	if appName == "Broker_RestFu-Purge" then
		local options = {
			type = "group",
			name = L["Purge"],
			args = {
				brfupdesc = {
					type = "description",
					order = 0,
					name = L["Purge characters or realms"],
				},
				purgerealm = {
					name = L["Purge Realm"],
					desc = L["Select a realm to purge"],
					type = "select",
					style = "radio",
					order = 100,
					confirm = function(info, value)
						return (L["Are you sure you wish to delete '%s'?"]):format(value)
					end,
					values = function()
						local t = {}

						for realm, _ in pairs(Broker_RestFu.db.global) do
							t[realm] = realm
						end

						return t
					end,
					set = function(info, value)
						Broker_RestFu.db.global[value] = nil
						purged = true
					end,
				},
			},
		}
		-- Generate character purge options
		local optOrder = 200
		for realm, _ in pairs(Broker_RestFu.db.global) do
			options.args["purgechar"..realm] = {
				name = (L["Purge Character from %s"]):format(realm),
				desc = L["Select a character to purge"],
				type = "select",
				style = "radio",
				order = optOrder,
				confirm = function(info, value)
					return (L["Are you sure you wish to delete '%s'?"]):format(value)
				end,
				values = function()
					local t = {}

					for char, _ in pairs(Broker_RestFu.db.global[realm]) do
						t[char] = char
					end

					return t
				end,
				set = function(info, value)
					Broker_RestFu.db.global[realm][value] = nil

					-- Check if we also need to purge the realm
					local count = 0
					for _ in pairs(Broker_RestFu.db.global[realm]) do
						count = count + 1
					end

					if count == 0 then
						Broker_RestFu.db.global[realm] = nil
					end

					purged = true
				end,
			}

			optOrder = optOrder + 5
		end

		return options
	end
end

local function OpenOptions()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(addonOptionsFrameName)
    else
		InterfaceOptionsFrame_OpenToCategory(addonOptionsFrameName)
    end
end

function Broker_RestFu:OnInitialize()
    local _
	self.db = LibStub("AceDB-3.0"):New("Broker_RestFuDB", defaults, true)
	db = self.db.profile

	-- Minimap Icon
	icon:Register("Broker_RestFu", dataobj, db.minimap)

	-- Options
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Broker_RestFu-General", GetOptions)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Broker_RestFu-Filter", GetOptions)
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Broker_RestFu-Purge", GetOptions)

	_, addonOptionsFrameName = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_RestFu-General", ADDON_TITLE)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_RestFu-Filter", L["Filter"], ADDON_TITLE)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_RestFu-Purge", L["Purge"], ADDON_TITLE)
end

function Broker_RestFu:OnEnable()
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Save")
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "Save")
	self:RegisterEvent("PLAYER_XP_UPDATE", "Save")
	self:RegisterEvent("TIME_PLAYED_MSG")
	self:RegisterEvent("ZONE_CHANGED", "Save")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "Save")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Save")

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

local FILTER_REALM = 1
local FILTER_CHAR = 2
function Broker_RestFu:IsFiltered(type, realm, char)
	if type == FILTER_REALM then
		if self.db.profile.filter.realm[realm] then
			return true
		end

		return false
	end

	if type == FILTER_CHAR then
		if self.db.profile.filter.char[realm] then
			if self.db.profile.filter.char[realm][char] then
				return true
			end
		end

		return false
	end

	return false
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
	-- Don't show if we're in combat.
	if InCombatLockdown() then
		return
	end

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

	local now = time()
	local totalTimePlayed = 0
	local currentRealm = GetRealmName()
	local currentChar = UnitName("player")

	-- Header
	tooltip:AddHeader(nil, nil, nil, ADDON_TITLE)
	tooltip:AddLine(" ")

	-- Generate a list of realms and chars the first time we build the tooltip
	if not realms or purged == true then
		purged = false
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
		if not self:IsFiltered(FILTER_REALM, realm) then
			-- Ensure there is a blank line between each realm
			if realmCount ~= 1 then
				tooltip:AddLine(" ")
			end

			tooltip:AddHeader(
                realm,
                L["Time Played"],
                L["Last Played"],
                L["Time to Rest"],
                L["Current XP"],
                L["Rest XP"],
                L["Zone"]
            )

			for _, char in ipairs(chars[realm]) do
				if not self:IsFiltered(FILTER_CHAR, realm, char) then
					self:UpdateRestXPData(realm, char)
					local t = self.db.global[realm][char]
					local classColor = RAID_CLASS_COLORS[t.localclass].colorStr

					local lastPlayed
					if realm == currentRealm and char == currentChar then
						lastPlayed = ("|cff00ff00%s|r"):format(GUILD_ONLINE_LABEL)
					elseif t.lastPlayed then
						lastPlayed = ("%s |cffffffff%s|r"):format(
							abacus:FormatDurationCondensed(now - t.lastPlayed, true, true),
							L["ago"]
						)
					else
						lastPlayed = "-"
					end

					local factionText = ""
					if t.faction == "Horde" then
						factionText = " |cffcf0000(H)|r"
					elseif t.faction == "Alliance" then
						factionText = " |cff0000cf(A)|r"
					end

					local playedTime
					if realm == currentRealm and char == currentChar and self.timePlayed then
						playedTime = self.timePlayed + time() - self.timePlayedMsgTime
					else
						playedTime = t.timePlayed or 0
					end
					totalTimePlayed = totalTimePlayed + playedTime

					local charInfo = ("|c%s%s|r [|cffffffff%d|r]%s"):format(classColor, char, t.level or 0, factionText)
					local playedTimeText = abacus:FormatDurationCondensed(playedTime, true, true)

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

						tooltip:AddLine(
							charInfo,
							playedTimeText,
							lastPlayed,
							timeToMax > 0 and abacus:FormatDurationCondensed(timeToMax, true, true) or ("|cff00ff00%s|r"):format(L["Fully rested"]),
							("%.0f%%"):format(t.currXP / t.nextXP * 100),
							("|cff%02x%02x%02x(%+.0f%%)|r"):format(r * 255, g * 255, b * 255, t.restXP / t.nextXP * 100),
							("|cffffffff%s|r"):format(t.zone or L["Unknown"])
						)
					else
						tooltip:AddLine(
							charInfo,
							playedTimeText,
							lastPlayed,
							nil,
							nil,
							nil,
							("|cffffffff%s|r"):format(t.zone or L["Unknown"])
						)
					end
				end
			end
		end
	end

	tooltip:AddLine(" ")
	tooltip:AddLine(
		("|cffffffff%s|r"):format(L["Total time played"]),
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

-- Handled by the AutoHide
--function dataobj:OnLeave()
--	LQT:Release(tooltip)
--	tooltip = nil
--end

function dataobj:OnClick(button)
	if button == "RightButton" then
        OpenOptions()
	end
end
