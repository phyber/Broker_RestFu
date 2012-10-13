local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LQT = LibStub("LibQTip-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Broker_RestFu")
local dataobj = LDB:NewDataObject("Broker_RestFu", {
	type = "data source",
	text = "RestFu",
	icon = "Interface\\AddOns\\Broker_RestFu\\icon.tga",
})
local icon = LibStub("LibDBIcon-1.0")

local pairs = pairs
local ipairs = ipairs
local string_format = string.format
local table_insert = table.insert
local table_sort = table.sort

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
	char = {},
	realm = {},
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
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Broker_MoneyFu-General", GetAddOnMetadata("Broker_RestFu", "Title"))
end

function Broker_RestFu:OnEnable()
	self:RegisterEvent("PLAYER_UPDATE_RESTING", "Save")
	self:RegisterEvent("PLAYER_XP_UPDATE", "Save")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "Save")
	self:RegisterEvent("TIME_PLAYED_MSG")

	timerSched.TimePlayed = self:ScheduleRepeatingTimer("OnUpdate_TimePlayed", 1)

	self:Save()
end

function Broker_RestFu:ReIndex()
	if not timerSched.OnUpdate then
		timerSched.OnUpdate = self:ScheduleRepeatingTimer("OnUpdate", 3)
		timerSched.UpdateTooltip = self:ScheduleRepeatingTimer("UpdateTooltip", 60)
	end
end

function Broker_RestFu:Save()
	local zone = GetRealZoneText()
	if zone == nil or zone == "" then
		self:ScheduleTimer("Save", 5)
	elseif UnitLevel("player") ~= 0 then
		if not self.myData then
			self:ReIndex()
		end

		local t = self.char
		t.level = UnitLevel("player")
		t.class, t.localclass = UnitClass("player")
		t.currXP = UnitXP("player")
		t.nextXP = UnitXPMax("player")
		t.restXP = GetXPExhaustion() or 0
		t.isResting = IsResting() and true or false
		t.zone = zone

		if self.timePlayed then
			t.timePlayed = self.timePlayed + time() - self.timePlayedMsgTime
		elseif not t.timePlayed then
			t.timePlayed = 0
		end

		t.faction = UnitFactionGroup("player")
		t.realm = GetRealmName()
		t.time = time()
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

local sortChars_realm
local function sortChars(alpha, bravo)
end
local function sortRealms(alpha, bravo)
end

-- LDB functions
function dataobj:OnEnter()
	if not LQT:IsAcquired("Broker_RestFu") then
		tooltip = LQT:Acquire("Broker_RestFuTip",
			-- Columns
			7,
			-- Alignments
			"LEFT", "CENTER", "CENTER", "CENTER", "CENTER", "CENTER", "RIGHT"
		)
	end
	tooltip:Clear()
	tooltip:SmartAnchorTo(dataobj)
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
