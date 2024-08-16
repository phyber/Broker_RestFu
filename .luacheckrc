-- vim:ft=lua:
std = "lua51"

-- Show codes for warnings
codes = true

-- Disable colour output
color = false

-- Suppress reports for files without warnings
quiet = 1

-- Disable max line length check
max_line_length = false

-- We don't want to check externals Libs or this config file
exclude_files = {
    ".release/",
    "Libs/",
    ".luacheckrc",
}

-- Ignored warnings
ignore = {
    "212/event",     -- Used in TIME_PLAYED_MSG
    "212/info",      -- Used in GetOptions
    "212/leveltime", -- Used in TIME_PLAYED_MSG
    "212/self",      -- Used in dataobj:OnClick
    "212/uiName",    -- Used in GetOptions
    "212/uiType",    -- Used in GetOptions
}

-- Globals that we read/write
globals = {
    "Broker_RestFu",
    "Broker_RestFu_Tooltip_Font",
}

-- Globals that we only read
read_globals = {
    -- Libraries
    "LibStub",

    -- Lua globals
    "time",

    -- C modules
    "C_AddOns",

    -- API Functions
    "CreateFont",
    "GetMaxLevelForPlayerExpansion",
    "GetRealmName",
    "GetRealZoneText",
    "GetXPExhaustion",
    "InCombatLockdown",
    "InterfaceOptionsFrame_OpenToCategory",
    "IsResting",
    "RequestTimePlayed",
    "UnitClass",
    "UnitFactionGroup",
    "UnitLevel",
    "UnitName",
    "UnitRace",
    "UnitXP",
    "UnitXPMax",

    -- FrameXML Globals
    "GUILD_ONLINE_LABEL",
    "NORMAL_FONT_COLOR",
    "RAID_CLASS_COLORS",

    -- Frames
    "Settings",
}
