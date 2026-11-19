-- Damage Numbers (DaylightUI Plugin)
-- Shows the damage you deal to your target in Daylight UI's combat text
-- (the Right stream by default, next to your heals). Its settings have their
-- own page under Plugins in /dui: each message with a stream, a color and a
-- switch, like Daylight UI's own.
--
-- WoW: Forever keeps the combat log closed, so outgoing hits are read from
-- UNIT_COMBAT on the target. That event reports every hit the target takes,
-- so in a group it includes other players' hits too ("Only when solo" hides
-- the numbers while grouped). The amount can be a secret value: it is only
-- ever handed to the font string, never compared or summed.

local ADDON = ...
local DUI = _G.DaylightUI
local API = DUI and DUI.API
if type(API) ~= "table" or API.major ~= 1 then return end

local NAME = ADDON
local TITLE = "Damage Numbers"   -- what chat lines are signed with
local me = API.For(NAME)

local STREAMS = { heals = "Right stream", hits = "Left stream", notes = "Top stream" }
local STREAM_ORDER = { "heals", "hits", "notes" }

-- UNIT_COMBAT actions that land no damage and get shown as a word.
local NO_DAMAGE = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, ABSORB = true, RESIST = true,
    IMMUNE = true, EVADE = true, DEFLECT = true, REFLECT = true }

local function themeText()
    local ok, colors = pcall(API.Colors)
    local c = ok and type(colors) == "table" and colors.TEXT
    if type(c) == "table" then return { c[1], c[2], c[3] } end
    return { 0.95, 0.93, 0.88 }
end

-- The plugin's messages. fixed = no stream of its own (a crit goes where
-- its hit goes); for crits the switch picks between their own color and
-- their hit's.
local KIND_ORDER = { "melee", "spell", "crit", "miss" }
local KINDS = {
    melee = { label = "Your melee and ranged hits", desc = "Your weapon hits on your target, and your pet's." },
    spell = { label = "Your spell hits",
        desc = "Your spell hits on your target, and your pet's. Colored by school when Color spell hits by school is on (Combat text > Look)." },
    crit = { label = "Your crits in their own color", fixed = true,
        desc = "Crits take this color. When off, a crit keeps its hit's color. Either way it lands bigger, in the stream's crit style." },
    miss = { label = "Your misses", desc = "A word when your attack is dodged, parried, missed, resisted or absorbed." },
}

local DEFAULTS = {
    kinds = {
        melee = { on = true, stream = "heals", color = { 1, 1, 1 } },
        spell = { on = true, stream = "heals", color = { 1, 0.93, 0.75 } },
        crit = { on = true, color = { 1, 0.82, 0.3 } },
        miss = { on = true, stream = "heals", color = themeText() },
    },
    soloOnly = false,
    hideGame = true,
}

DUI:RegisterPlugin(NAME, {
    needs = { 1, 3 },
    icon = "Interface\\AddOns\\DaylightDamageNumbers\\icon.png",
    color = { 1, 0.62, 0.3 },
    short = "Damage",
    blurb = "The damage you deal, in the combat text streams.",
})

local mod

local function default(path)
    local t = DEFAULTS
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

local function get(path)
    local v = API.GetSetting(NAME, path)
    if v == nil then return default(path) end
    return v
end

local function set(path, v) DUI:Set(NAME, path, v) end

local function kindOn(id) return get("kinds." .. id .. ".on") ~= false end

local function streamOf(id)
    local s = get("kinds." .. id .. ".stream")
    return STREAMS[s] and s or "heals"
end

local function colorOf(id)
    local c = get("kinds." .. id .. ".color")
    if type(c) ~= "table" then c = default("kinds." .. id .. ".color") end
    return c[1] or 1, c[2] or 1, c[3] or 1
end

local function plain(v) return not (issecretvalue and issecretvalue(v)) end

local function sctOn() return API.GetSetting("general", "sct.enabled") ~= false end

local function active()
    return mod ~= nil and mod.enabled and sctOn() and (kindOn("melee") or kindOn("spell") or kindOn("miss"))
end

-- Daylight UI's live combat text stage. Not part of the promised API, so
-- every touch is guarded: if a future update changes it, the plugin goes
-- quiet with one line in chat instead of an error per hit.
local broken = false
local pushStats = { noStage = 0, ok = 0 }

local function stage()
    local CT = DUI.CombatText
    if type(CT) ~= "table" or type(CT.Stage) ~= "function" then return nil end
    local ok, s = pcall(CT.Stage)
    if ok and type(s) == "table" and type(s.Add) == "function" then return s end
    return nil
end

local function push(stream, r, g, b, crit, fmt, value)
    if broken then return end
    local s = stage()
    if not s then pushStats.noStage = pushStats.noStage + 1 return end
    local ok, line = pcall(s.Add, s, stream, r, g, b, crit, fmt, value)
    if ok and line ~= nil then
        pushStats.ok = pushStats.ok + 1
    elseif ok then
        pushStats.streamOff = (pushStats.streamOff or 0) + 1   -- that stream is switched off
    else
        broken = true
        pushStats.err = tostring(line)
        print(("|cffff9a1f%s|r: Daylight UI's combat text changed, damage numbers are off until this plugin is updated. (%s)")
            :format(TITLE, tostring(line)))
    end
end

-- Formats an amount in the player's chosen style (Combat text > Numbers).
-- Works on secret values: the game's formatters accept them and return one.
local function formatAmount(v)
    if plain(v) and type(v) ~= "number" then return v end
    local fn = API.GetSetting("general", "sct.numbers") == "short" and AbbreviateNumbers or BreakUpLargeNumbers
    if type(fn) == "function" then
        local ok, s = pcall(fn, v)
        if ok and type(s) ~= "nil" then return s end
    end
    return v
end

local function schoolColor(mask)
    if not plain(mask) or type(mask) ~= "number" or mask <= 1 then return nil end
    local CT = DUI.CombatText
    if type(CT) ~= "table" or type(CT.SchoolColor) ~= "function" then return nil end
    local ok, c = pcall(CT.SchoolColor, mask)
    if ok and type(c) == "table" then return c end
    return nil
end

-- One hit (or miss) on the target. crit, school: plain values or nil.
local function showHit(action, crit, amount, school)
    if action == "WOUND" then
        if plain(amount) and (tonumber(amount) or 0) <= 0 then return end
        local isSpell = plain(school) and type(school) == "number" and school > 1
        local id = isSpell and "spell" or "melee"
        if not kindOn(id) then return end
        local r, g, b
        local sc = isSpell and API.GetSetting("general", "sct.schoolColors") ~= false and schoolColor(school)
        if crit and kindOn("crit") then
            r, g, b = colorOf("crit")
        elseif sc then
            r, g, b = sc[1], sc[2], sc[3]
        else
            r, g, b = colorOf(id)
        end
        local fmt = (crit and API.GetSetting("general", "sct.critMark") == true) and "%s!" or "%s"
        push(streamOf(id), r, g, b, crit, fmt, formatAmount(amount))
    elseif NO_DAMAGE[action] and kindOn("miss") then
        local word = _G[action]
        if type(word) ~= "string" then word = action:sub(1, 1) .. action:sub(2):lower() end
        local r, g, b = colorOf("miss")
        push(streamOf("miss"), r, g, b, false, "%s", word)
    end
end

-- What happened this session, for /dui dmgdebug and the safety checks below.
local stats = { combatAll = 0, combatTarget = 0, friendly = 0, solo = 0, secretUnit = 0,
    targetHealth = 0, fightHealth = 0, fightHits = 0 }
local seenReal = false   -- a real hit on the target reached the stream this session
local blocked = false    -- hiding the game's numbers stopped the hits coming
local syncGame           -- defined further down

local events = CreateFrame("Frame")

local function onCombat(unit, action, flag, amount, school)
    stats.combatAll = stats.combatAll + 1
    -- Registered for every unit (like Daylight UI's own DoT tracker), since a
    -- target-only registration doesn't fire on this client.
    if not plain(unit) then stats.secretUnit = stats.secretUnit + 1 return end
    if unit ~= "target" then return end
    stats.combatTarget = stats.combatTarget + 1
    stats.lastAction = plain(action) and tostring(action) or "<secret>"
    if not plain(action) or type(action) ~= "string" then return end
    -- Only hits on something you can attack, and not on yourself (the Left
    -- stream already shows those).
    if UnitIsUnit("target", "player") or not UnitCanAttack("player", "target") then
        stats.friendly = stats.friendly + 1
        return
    end
    stats.fightHits = stats.fightHits + 1
    if get("soloOnly") and IsInGroup() then stats.solo = stats.solo + 1 return end
    local crit = plain(flag) and flag == "CRITICAL"
    local before = pushStats.ok
    showHit(action, crit, amount, school)
    if pushStats.ok > before and not seenReal then
        seenReal = true
        syncGame()   -- the stream works: now the game's own numbers can go
    end
end

events:SetScript("OnEvent", function(_, event, unit, ...)
    if not active() then return end
    if event == "UNIT_COMBAT" then
        onCombat(unit, ...)
    elseif event == "UNIT_HEALTH" then
        if plain(unit) and unit == "target" then
            stats.targetHealth = stats.targetHealth + 1
            if UnitCanAttack("player", "target") then stats.fightHealth = stats.fightHealth + 1 end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        stats.fightHealth, stats.fightHits = 0, 0
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- A fight where the target's health kept changing but not one hit was
        -- reported: the game stops sending hits while its own numbers are off.
        -- Put them back and keep them for this session.
        if stats.hidden and stats.fightHealth >= 3 and stats.fightHits == 0 and not blocked then
            blocked = true
            syncGame()
            print(("|cffff9a1f%s|r: the game stopped reporting your hits while its own damage numbers were off, so they're back on."):format(TITLE))
        end
    end
end)

-- Samples: /dui dmg, the options button and /dui test.
local SAMPLES = {
    { 412 }, { 538, school = 4 }, { 1386, crit = true }, { 296 }, { miss = "DODGE" },
    { 702, school = 16 }, { 455 }, { 1720, crit = true, school = 32 }, { 388, school = 8 }, { miss = "PARRY" },
}
local sampleN = 0

local function sampleStep()
    sampleN = sampleN % #SAMPLES + 1
    local s = SAMPLES[sampleN]
    if s.miss then showHit(s.miss) else showHit("WOUND", s.crit == true, s[1], s.school) end
end

local function sampleBurst()
    if not active() then
        print(("|cffff9a1f%s|r: turn on Combat text and at least one of your messages first."):format(TITLE))
        return
    end
    for i = 0, #SAMPLES - 1 do C_Timer.After(i * 0.3, sampleStep) end
end

local testTicker
local function syncTest()
    local want = DUI.testMode == true and active()
    if want and not testTicker then
        testTicker = C_Timer.NewTicker(0.7, sampleStep)
    elseif not want and testTicker then
        testTicker:Cancel()
        testTicker = nil
    end
end

-- The game's own damage numbers over the target. While this plugin shows
-- your hits in a stream they'd only double up, so they're switched off
-- (yours and your pet's; healing numbers stay). What the player had before
-- is kept in the plugin's settings and put back when the plugin or
-- "Hide the game's damage numbers" is turned off.
local GAME_CVARS = {
    damage = { "floatingCombatTextCombatDamage_v2" },
    pet = { "floatingCombatTextPetMeleeDamage_v2", "floatingCombatTextPetSpellDamage_v2" },
}

local function cvarOn(name)
    local fn = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, name)
    if not ok or v == nil then return nil end
    return v ~= "0"
end

local function setGame(what, on)
    -- Daylight UI's own switch also slides its Damage numbers page to match.
    local DT = DUI.DamageText
    if type(DT) == "table" and type(DT.SetShown) == "function" and pcall(DT.SetShown, what, on) then return end
    if type(SetCVar) ~= "function" then return end
    for _, name in ipairs(GAME_CVARS[what]) do
        if cvarOn(name) ~= nil then pcall(SetCVar, name, on and "1" or "0") end
    end
end

local waiter = CreateFrame("Frame")

waiter:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    syncGame()
end)

-- The game's numbers only go once a real hit has shown in the stream this
-- session, so a stream that isn't working never leaves you with no numbers.
function syncGame()
    if not (mod and mod.enabled and type(mod.db) == "table") then return end
    if InCombatLockdown and InCombatLockdown() then
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local db = mod.db
    local wanted = active() and get("hideGame") ~= false
    if wanted and seenReal and not blocked then
        if type(db.gameShown) ~= "table" then
            db.gameShown = {}
            for what, list in pairs(GAME_CVARS) do db.gameShown[what] = cvarOn(list[1]) end
        end
        for what, list in pairs(GAME_CVARS) do
            if cvarOn(list[1]) then setGame(what, false) end
        end
        stats.hidden = true
        return
    end
    if type(db.gameShown) == "table" then
        for what, was in pairs(db.gameShown) do
            if was then setGame(what, true) end
        end
        db.gameShown = nil
    elseif wanted and not stats.repaired then
        -- Left off by version 1.1, which hid them without checking the stream
        -- worked and didn't always remember what was there before.
        for what, list in pairs(GAME_CVARS) do
            if cvarOn(list[1]) == false then setGame(what, true) end
        end
    end
    stats.repaired = true
    stats.hidden = false
end

local function listen()
    events:UnregisterAllEvents()
    if active() then
        events:RegisterEvent("UNIT_COMBAT")
        events:RegisterEvent("UNIT_HEALTH")
        events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    syncTest()
    syncGame()
end

-- Settings from 1.0-1.3 (one stream and three colors for everything) move
-- onto the messages.
local function migrate(db)
    if db.stream == nil and db.color == nil and db.critColor == nil and db.missColor == nil
        and db.enabled == nil and db.misses == nil and db.schools == nil then return end
    local k = db.kinds
    if type(k) ~= "table" then return end
    if STREAMS[db.stream] then
        for _, id in ipairs({ "melee", "spell", "miss" }) do k[id].stream = db.stream end
    end
    if type(db.color) == "table" then k.melee.color = db.color end
    if type(db.critColor) == "table" then k.crit.color = db.critColor end
    if type(db.missColor) == "table" then k.miss.color = db.missColor end
    if db.misses == false then k.miss.on = false end
    if db.enabled == false then
        for _, id in ipairs({ "melee", "spell", "miss" }) do k[id].on = false end
    end
    db.stream, db.color, db.critColor, db.missColor, db.enabled, db.misses, db.schools = nil, nil, nil, nil, nil, nil, nil
end

local function yes(v) return v and "|cff66ff66yes|r" or "|cffff6666no|r" end

local function debug()
    local p = function(s) print(("|cffff9a1f%s|r %s"):format(TITLE, s)) end
    local s = stage()
    local on = {}
    for _, id in ipairs(KIND_ORDER) do
        on[#on + 1] = ("%s %s%s"):format(id, yes(kindOn(id)), KINDS[id].fixed and "" or (" > " .. STREAMS[streamOf(id)]))
    end
    p(("plugin on %s, combat text on %s, stage found %s; %s"):format(
        yes(mod and mod.enabled), yes(sctOn()), yes(s ~= nil), table.concat(on, ", ")))
    p(("UNIT_COMBAT seen %d, on target %d (last: %s), friendly/self %d, hidden by solo %d, secret unit %d"):format(
        stats.combatAll, stats.combatTarget, tostring(stats.lastAction), stats.friendly, stats.solo, stats.secretUnit))
    p(("lines added %d, no stage %d, stream off %d, error: %s"):format(
        pushStats.ok, pushStats.noStage, pushStats.streamOff or 0, tostring(pushStats.err or "none")))
    p(("target health updates %d, real hit seen %s, game numbers: yours %s, pet %s, hidden by plugin %s%s"):format(
        stats.targetHealth, yes(seenReal), yes(cvarOn(GAME_CVARS.damage[1])), yes(cvarOn(GAME_CVARS.pet[1])),
        yes(stats.hidden), blocked and " (blocked: game stopped sending hits)" or ""))
end

-- Options: the plugin's own page under Plugins in /dui. Each message row is
-- like Daylight UI's own on Combat text > Messages (a switch with a stream
-- menu and a color beside it). Those controls come from Daylight UI's options
-- widgets, which aren't promised API; if they're missing, each message gets
-- plain stream and color rows instead.

local BESIDE_W, MENU_W = 190, 134

local function streamNames()
    local names = {}
    for id, label in pairs(STREAMS) do
        local L = DUI.L
        names[id] = (type(L) == "table" and type(L[label]) == "string") and L[label] or label
    end
    return names
end

local function widgets()
    local W = DUI.Widgets
    if type(W) == "table" and type(W.Swatch) == "function" and type(W.MenuButton) == "function"
        and type(W.OpenMenu) == "function" then return W end
    return nil
end

local function besideFor(id)
    local base = "kinds." .. id .. "."
    return function(row)
        local W = DUI.Widgets
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(BESIDE_W, W.ROW_HEIGHT or 28)

        local swatch = W.Swatch(holder, row,
            function() return get(base .. "color") end,
            function(c) set(base .. "color", { c[1], c[2], c[3] }) end)
        swatch:SetPoint("RIGHT", holder, "RIGHT", 0, 0)

        local menu, names
        if not KINDS[id].fixed then
            names = streamNames()
            menu = W.MenuButton(holder, "", 24)
            menu:SetWidth(MENU_W)
            menu:SetPoint("RIGHT", swatch, "LEFT", -8, 0)
            menu:SetScript("OnClick", function(self)
                if row.disabled then return end
                W.OpenMenu(self, STREAM_ORDER, names, streamOf(id), function(s) set(base .. "stream", s) end, MENU_W)
            end)
        end

        function holder.Refresh()
            if swatch.Refresh then swatch.Refresh() end
            if menu and menu.SetLabel then menu.SetLabel(names[streamOf(id)] or "", MENU_W) end
            holder:SetAlpha((not row.disabled and kindOn(id)) and 1 or 0.35)
        end
        holder.Refresh()
        return holder
    end
end

local function combatTextOff() return not sctOn() end

local messages = {}
local W = widgets()
for _, id in ipairs(KIND_ORDER) do
    local k, base = KINDS[id], "kinds." .. id .. "."
    messages[#messages + 1] = { type = "toggle", key = base .. "on", label = k.label, desc = k.desc,
        disabled = combatTextOff, beside = W and besideFor(id) or nil }
    if not W then
        local function dim(getter) return not sctOn() or getter(base .. "on") == false end
        if not k.fixed then
            messages[#messages + 1] = { type = "dropdown", key = base .. "stream", label = k.label .. ": stream",
                values = STREAMS, order = STREAM_ORDER, disabled = dim, desc = "Which stream these go in." }
        end
        messages[#messages + 1] = { type = "color", key = base .. "color", label = k.label .. ": color",
            disabled = dim, desc = "Their color." }
    end
end

local OPTIONS = { pages = {
    { id = "main", label = "Damage Numbers",
      desc = "The damage you deal to your target, in Daylight UI's combat text streams.",
      groups = {
          { label = "Messages", wide = true, items = messages },
          { label = "When they show", items = {
              { type = "toggle", key = "soloOnly", label = "Only when solo", disabled = combatTextOff,
                desc = "The game reports every hit your target takes, so in a group other players' hits show too. This hides your messages while you're grouped." },
              { type = "toggle", key = "hideGame", label = "Hide the game's damage numbers", disabled = combatTextOff,
                desc = "Turns off the numbers that pop off your target (yours and your pet's) once the stream has shown your first hit of the session. Turning this off puts back what you had." },
              { type = "text", label = "Needs Daylight UI's combat text on (Combat text page). Number style, crit mark and school colors follow that page's settings." },
          } },
          { label = "Try it", items = {
              { type = "button", label = "Show sample numbers", func = sampleBurst,
                desc = "Sends a few made-up hits through the streams. Same as /dui dmg." },
          } },
      } },
} }

mod = DUI:RegisterModule(NAME, {
    plugin = NAME,
    label = "Damage Numbers",
    defaults = DEFAULTS,
    options = OPTIONS,
    OnEnable = function(self, db)
        mod = self   -- can run inside RegisterModule, before the assignment below
        db = type(db) == "table" and db or self.db
        if type(db) == "table" then pcall(migrate, db) end
        listen()
    end,
})

me.On("SettingChanged", function(scope, path)
    if scope == NAME or (scope == "general" and path == "sct.enabled") then listen() end
end)
me.On("TestModeChanged", syncTest)
me.RegisterCommand("dmg", sampleBurst, "Shows sample damage numbers in the combat text.")
me.RegisterCommand("dmgdebug", debug, "Says what the damage numbers plugin has seen this session.")
