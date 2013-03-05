local addonName, addon = ...

local L = setmetatable({}, {
    __index = function(self, key)
        if key ~= nil then
            rawset(self, key, tostring(key))
        end
        return tostring(key)
    end,
})
addon.L = L

------------------------ enUS ------------------------
L["BATTLE_PET_TEAM"] = "Battle Pet Teams"
L["BATTLE_PET_TEAM_INFO"] = "Pet Teams"
L["BATTLE_PET_TEAM_USE_MACRO"] = "Enable macros"
L["BATTLE_PET_TEAM_USE_MACRO_DESCRIPTION"] = "If checked, saves team information to your global macros."
-- Dailies
L["Grand Master Trixxy"] = true
L["Lydia Accoste"] = true
L["Grand Master Antari"] = true
L["Grand Master Payne"] = true
L["Grand Master Hyuna"] = true
L["Grand Master Mo'ruk"] = true
L["Grand Master Nishi"] = true
L["Grand Master Yon"] = true
L["Grand Master Shu"] = true
L["Grand Master Aki"] = true
L["Grand Master Obalis"] = true
L["Grand Master Zusshi"] = true
L["Darkmoon Pet Battle!"] = true
L["Burning Pandaren Spirit"] = true
L["Flowing Pandaren Spirit"] = true
L["Whispering Pandaren Spirit"] = true
L["Thundering Pandaren Spirit"] = true
L["Beasts of Fable"] = true

-- Replace remaining true values by their key
for k,v in pairs(L) do if v == true then L[k] = k end end