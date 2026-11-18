-- Run from the repository root with LuaJIT: luajit tools/tests/compat-flavor.lua
-- Compat.lua tells Forever from Retail, keeps every module on Forever and only the ported ones
-- on Retail; every name in its ready lists must be a real module or settings page.
local H = dofile("tools/tests/perf-helpers.lua")

local MAINLINE = 1

-- templates: the XML template names the mocked game has (C_XMLUtil.GetTemplateInfo answers for them)
local function loadCompat(projectID, tocVersion, templates)
    local chunk = assert(loadfile("Compat.lua"))
    local env = setmetatable({
        GetBuildInfo = function() return "x", "1", "date", tocVersion end,
        WOW_PROJECT_ID = projectID,
        WOW_PROJECT_MAINLINE = MAINLINE,
        C_XMLUtil = templates and {
            GetTemplateInfo = function(name) return templates[name] and { type = "Frame" } or nil end,
        },
    }, { __index = _G })
    setfenv(chunk, env)
    local ns = {}
    chunk("FlareUI", ns)
    return ns.Compat
end

local function check(actual, expected, label)
    assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

-- flavour detection
local C = loadCompat(MAINLINE, 120100)
check(C.DetectFlavor(MAINLINE, MAINLINE, 16001), C.FOREVER, "Forever with Retail's project ID")
check(C.DetectFlavor(99, MAINLINE, 16001), C.FOREVER, "Forever with its own project ID")
check(C.DetectFlavor(MAINLINE, MAINLINE, 120100), C.RETAIL, "Retail")
check(C.DetectFlavor(nil, nil, 120100), C.RETAIL, "Retail without project constants")
check(C.DetectFlavor(2, MAINLINE, 11508), C.CLASSIC, "Classic Era")
check(C.DetectFlavor(19, MAINLINE, 50503), C.CLASSIC, "Mists Classic")

-- Forever keeps everything
local forever = loadCompat(MAINLINE, 16001)
check(forever.isForever, true, "Forever flag")
check(forever.SupportsModule("UnitFrames"), true, "Forever keeps Unit Frames")
check(forever.SupportsPage("uf"), true, "Forever keeps the Unit Frames page")
check(forever.SupportsModule("ActionBars"), true, "Forever keeps Action Bars")
check(forever.SupportsPage("ab"), true, "Forever keeps the Action Bars page")

-- Retail only what is ported
local retail = loadCompat(MAINLINE, 120100)
check(retail.isRetail, true, "Retail flag")
check(retail.SupportsModule("Chat"), true, "Retail runs Chat")
check(retail.SupportsModule("ActionBars"), false, "Retail skips Action Bars")
check(retail.SupportsPage("ch"), true, "Retail shows the Chat page")
check(retail.SupportsPage("ab"), false, "Retail marks the Action Bars page")
check(retail.SupportsPage("about"), true, "Retail shows About")

-- every ready name exists in the code (a typo would silently keep a module off)
local modules, pages = {}, {}
local files = assert(io.popen('git ls-files -- "Modules/*.lua" "Settings/Pages/*.lua"'))
for path in files:lines() do
    local source = H.read(path)
    for name in source:gmatch('ns%.modules%["([%w_]+)"%]') do modules[name] = true end
    for key in source:gmatch('S:Module{%s*key%s*=%s*"([%w_]+)"') do pages[key] = true end
end
files:close()
local compatSource = H.read("Compat.lua")
local readyBlock = assert(compatSource:match("RETAIL = (%b{})"), "RETAIL ready list")
local modulesBlock = assert(readyBlock:match("modules = (%b{})"))
local pagesBlock = assert(readyBlock:match("pages = (%b{})"))
for name in modulesBlock:gmatch("([%w_]+) = true") do
    assert(modules[name], "Compat.lua lists an unknown module: " .. name)
end
for key in pagesBlock:gmatch("([%w_]+) = true") do
    assert(pages[key], "Compat.lua lists an unknown settings page: " .. key)
end

-- Blizzard templates: Retail asks the game, Forever always has them (even when the game says no)
local retailGame = loadCompat(MAINLINE, 120105, { EyeTemplate = true, BackdropTemplate = true })
check(retailGame.HasTemplate("BackdropTemplate"), true, "Retail has a template the game knows")
check(retailGame.HasTemplate("PetFrameHappinessTemplate"), false, "Retail lacks pet happiness")
check(retailGame.EYE_TEMPLATE, "EyeTemplate", "Retail's queue eye template")
local foreverGame = loadCompat(MAINLINE, 16001, { BackdropTemplate = true })
check(foreverGame.HasTemplate("PetFrameHappinessTemplate"), true, "Forever keeps pet happiness")
check(foreverGame.EYE_TEMPLATE, "LFGEyeTemplate", "Forever's queue eye template")
local retailNoUtil = loadCompat(MAINLINE, 120105)
check(retailNoUtil.HasTemplate("PetFrameHappinessTemplate"), true, "no C_XMLUtil: assume the template exists")

-- every template Compat.EYE_TEMPLATE names must be one the eye code expects to pass to CreateFrame
assert(H.read("Modules/MinimapEye.lua"):find("ns.Compat.EYE_TEMPLATE", 1, true), "MinimapEye uses Compat.EYE_TEMPLATE")

print("PASS: compat flavour detection, ready lists and Blizzard templates")
