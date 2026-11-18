local _, ns = ...

--------------------------------------------------
-- COMPAT
-- Which game FlareUI runs on (WoW: Forever or Retail), and which modules and settings pages are
-- ready there. Loads right after LoadCheck.lua and needs nothing else. Forever keeps every module;
-- on Retail a module starts only once it has been ported and tested in game.
--------------------------------------------------
local Compat = {}
ns.Compat = Compat

Compat.FOREVER = "FOREVER"
Compat.RETAIL = "RETAIL"
Compat.CLASSIC = "CLASSIC"

-- Interface numbers: Forever is 16xxx, Retail 110000 and up (Classic flavours sit below 60000)
local FOREVER_TOC_MIN, FOREVER_TOC_MAX = 16000, 17000
local RETAIL_TOC_MIN = 110000

-- The game from the client's project ID and interface number. Forever is checked first: its
-- engine is a modern one and its project ID may match Retail's.
function Compat.DetectFlavor(projectID, mainlineID, tocVersion)
    local toc = tonumber(tocVersion)
    if toc and toc >= FOREVER_TOC_MIN and toc < FOREVER_TOC_MAX then return Compat.FOREVER end
    if projectID ~= nil and projectID == mainlineID then return Compat.RETAIL end
    if toc and toc >= RETAIL_TOC_MIN then return Compat.RETAIL end
    return Compat.CLASSIC
end

-- Modules (ns.modules names) and settings pages (S:Module keys) ready on each game; a game
-- without a list has everything. Add a name only after testing it in game on that client.
local READY = {
    RETAIL = {
        -- Minimap (mm) and UnitFrames (uf): switched on for the in-game Retail test, not confirmed yet
        modules = { Chat = true, Tooltips = true, DamageMeter = true, Visibility = true,
            Minimap = true, UnitFrames = true },
        pages = { about = true, adv = true, language = true, ch = true, tt = true, dm = true,
            mm = true, uf = true },
    },
}

local tocVersion = select(4, GetBuildInfo())
Compat.flavor = Compat.DetectFlavor(WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, tocVersion)
Compat.isForever = Compat.flavor == Compat.FOREVER
Compat.isRetail = Compat.flavor == Compat.RETAIL

local ready = READY[Compat.flavor]

function Compat.SupportsModule(name)
    return ready == nil or ready.modules[name] == true
end

function Compat.SupportsPage(key)
    return ready == nil or ready.pages[key] == true
end
