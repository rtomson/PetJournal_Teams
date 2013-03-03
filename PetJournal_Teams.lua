--===========================================================================--
-- Addon Initialization
--===========================================================================--

local addonName, addon = ...
local L = addon.L

local _G = _G
local C_PetJournal = C_PetJournal
local PetJournal = PetJournal

local ICON_QUESTIONMARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local MACRO_NAME = "~PetTeams"
local MAX_ACCOUNT_MACROS = MAX_ACCOUNT_MACROS or 36
local MAX_ACTIVE_PETS = 3
local MAX_ACTIVE_ABILITIES = 3
local MAX_PET_ABILITIES = 6
local PETJOURNAL_DEFAULT_WIDTH = PetJournal:GetWidth()
local PETJOURNAL_EXPANDED_WIDTH = PETJOURNAL_DEFAULT_WIDTH + 202
local BATTLE_PET_TEAM = "Battle Pet Teams"

DAILY_BATTLE_PET_QUESTS = {
    {31909, "Grand Master Trixxy"},
    {31916, "Grand Master Lydia Accoste"},
    {31926, "Grand Master Antari"},
    {31935, "Grand Master Payne"},
    {31953, "Grand Master Hyuna"},
    {31954, "Grand Master Mo'ruk"},
    {31955, "Grand Master Nishi"},
    {31956, "Grand Master Yon"},
    {31957, "Grand Master Shu"},
    {31958, "Grand Master Aki"},
    {31971, "Grand Master Obalis"},
    {31991, "Grand Master Zusshi"},
    {32175, "Darkmoon Pet Battle!"},
    {32434, "Burning Pandaren Spirit"},
    {32439, "Flowing Pandaren Spirit"},
    {32440, "Whispering Pandaren Spirit"},
    {32441, "Thundering Pandaren Spirit"},
    {32604, "Beasts of Fable"},
}
setmetatable(DAILY_BATTLE_PET_QUESTS, {
    __index = function (self, key)
        if (not tonumber(key)) or (key < 1) or (key ~= math.floor(key)) then
            return nil
        end
        for _, quest in ipairs(self) do
            if key == quest[1] then
                return quest[2]
            end
        end
        return nil
    end
})

StaticPopupDialogs["PET_BATTLE_TEAMS_SET_NAME"] = {
    text = "Enter desired name of team:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 16,
    OnAccept = function(self)
        local text = self.editBox:GetText()
        PetBattleTeams_SetTeamName(text, self.data)
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local text = parent.editBox:GetText()
        PetBattleTeams_SetTeamName(text, self.data)
        parent:Hide()
    end,
    OnShow = function(self)
        self.editBox:SetFocus()
    end,
    OnHide = function(self)
        ChatEdit_FocusActiveWindow()
        self.editBox:SetText("")
    end,
    exclusive = 1,
    hideOnEscape = 1,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
    timeout = 0,
}

StaticPopupDialogs["PET_BATTLE_TEAMS_DELETE"] = {
    text = "Do you really want to delete this team?",
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(self)
        PetBattleTeams_DeleteCurrentTeam()
    end,
    timeout = 0,
    whileDead = 1,
    exclusive = 1,
    hideOnEscape = 1
}

function PetBattleTeams_DeleteCurrentTeam()
    table.remove(PetBattleTeamsDB.teams, PetBattleTeams.selectedIndex)
    PetBattleTeams_Update()
    if PetBattleTeamsDB.useMacros then
        PetBattleTeams_SaveMacro()
    end
end

function PetBattleTeams_SetTeamName(teamName, newTeam)
    if teamName:len() > 0 then
        if newTeam then
            local team = {
                name = teamName,
                icon = nil,
                pets = {},
                quest = 0
            }
            for i=1, MAX_ACTIVE_PETS do
                local petGUID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(i)
                if petGUID then
                    tinsert(team.pets, {petGUID, ability1, ability2, ability3})
                    if not team.icon then
                        team.icon = select(9, C_PetJournal.GetPetInfoByPetID(petGUID))
                    end
                end
            end
            tinsert(PetBattleTeamsDB.teams, team)
        else
            local team = PetBattleTeamsDB.teams[PetBattleTeams.selectedIndex]
            print("Renamed: "..team.name.." -> "..teamName)
            team.name = teamName
            team.questID = tonumber(teamName)
        end
        PetBattleTeams_Update()
        if PetBattleTeamsDB.useMacros then
            PetBattleTeams_SaveMacro()
        end
    end
end


--------------------------------------------------
-- Debug
--------------------------------------------------
local function Log(...)
    if PetBattleTeamsDB and PetBattleTeamsDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff7d0aDebug:|r "..tostring(...))
    end
end


--------------------------------------------------
-- PetJournal modifications
--------------------------------------------------
local function PetBattleTeams_ModifyPetJournalFrame()
    if HPetAllInfoButton then
        HPetAllInfoButton:SetPoint("TOPRIGHT", PetJournalParentCloseButton, "TOPLEFT", -6, -6)
    end
    --local rightOffset = PANEL_INSET_LEFT_OFFSET + PetJournal.LeftInset:GetWidth() + 20 + PetJournal.RightInset:GetWidth()
    --PetJournal.AchievementStatus:SetPoint("TOPLEFT", PetJournal, "TOPLEFT", 322, -21)
    --PetJournal.FindBattleButton:SetPoint("BOTTOMRIGHT", PetJournal, "BOTTOMLEFT", rightOffset, PANEL_INSET_BOTTOM_OFFSET)
    --PetJournal.HealPetButton:SetPoint("BOTTOMRIGHT", PetJournal, "TOPLEFT", rightOffset - 36, PANEL_INSET_ATTIC_OFFSET + 1)
    --PetJournal.RightInset:SetPoint("TOPRIGHT", PetJournal, "TOPLEFT", rightOffset, -252)
    --PetJournal.PetCardInset:SetPoint("TOPRIGHT", PetJournal, "TOPLEFT", rightOffset, PANEL_INSET_ATTIC_OFFSET)
end


--- Loads team data from account-wide macros
function PetBattleTeams_LoadMacro()
    local teamData = {}
    local numMacros = GetNumMacros()
    for i=1, numMacros do
        local name, _, body = GetMacroInfo(i)
        if strmatch(name, MACRO_NAME) then
            tinsert(teamData, strtrim(body))
        end
    end
    teamData = table.concat(teamData)
    if not (teamData:len() > 0) then
        return nil
    end
    
    local teams = {}
    for ln in gmatch(teamData, "([^%c]+)") do
        local teamName, p1, a11, a12, a13, p2, a21, a22, a23, p3, a31, a32, a33 = strsplit(":", ln)
        if teamName then
            local team = {
                name = teamName,
                icon = nil, -- Set to the first pet when first used
                pets = {
                    -- API calls are not consistent. Some require numbers, some strings, but
                    -- all will take a 16-digit hex string for the GUID
                    {string.format("0x%016s", p1), tonumber(a11), tonumber(a12), tonumber(a13)},
                    {string.format("0x%016s", p2), tonumber(a21), tonumber(a22), tonumber(a23)},
                    {string.format("0x%016s", p3), tonumber(a31), tonumber(a32), tonumber(a33)}
                },
                questID = tonumber(teamName)
            }
            tinsert(teams, team)
        end
    end
    
    return teams
end

--- Saves team data to account-wide macros
function PetBattleTeams_SaveMacro()
    local teamData = {}
    for i=1, #PetBattleTeamsDB.teams do
        local team = PetBattleTeamsDB.teams[i]
        local teamStr = team.name
        for j=1, #team.pets do
            teamStr = teamStr..string.format(":%x:%i:%i:%i", unpack(team.pets[j]))
        end
        tinsert(teamData, teamStr)
    end
    teamData = table.concat(teamData, "\n")
    
    local macroData = {}
    for i=0, teamData:len() / 255 do
        tinsert(macroData, string.sub(teamData, 1 + i * 255, i * 255 + 255))
    end
    
    local currentPetMacros = 0
    local numMacros = GetNumMacros()
    for i=1, numMacros do
        local name, _, body = GetMacroInfo(i)
        if strmatch(name, MACRO_NAME) then
            currentPetMacros = currentPetMacros + 1
            if currentPetMacros > #macroData then
                DeleteMacro(name)
            end
        end
    end
    
    if (#macroData + numMacros - currentPetMacros) > MAX_ACCOUNT_MACROS then
        DEFAULT_CHAT_FRAME:AddMessage("Cannot save team data; no macro slots available.")
        return
    end
    -- Having the macro frame open causes issues with CreateMacro/EditMacro
    if MacroFrame then
        HideUIPanel(MacroFrame)
    end
    
    for i=1, #macroData do
        local name = MACRO_NAME..i
        local index = GetMacroIndexByName(name)
        if 0 == index then
            CreateMacro(name, "INV_MISC_QUESTIONMARK", macroData[i], nil)
        else
            EditMacro(index, name, "INV_MISC_QUESTIONMARK", macroData[i])
        end
    end
    
end

--------------------------------------------------
-- Other functions
--------------------------------------------------
--- Activates the team at the given index
function PetBattleTeams_ActivateTeam(index)
    index = index or PetBattleTeams.selectedIndex
    if not index then
        Log("No team selected!")
        return
    end
    
    local team = PetBattleTeamsDB.teams[index]
    local setAbilities = 0
    for i=1, MAX_ACTIVE_PETS do
        local pet = team.pets[i]
        local petGUID = pet[1]
        if tonumber(petGUID) > 0 and C_PetJournal.GetPetInfoByPetID(petGUID) then
            if petGUID ~= C_PetJournal.GetPetLoadOutInfo(i) then
                Log(string.format("SetPet: %i %s", i, petGUID))
                C_PetJournal.SetPetLoadOutInfo(i, petGUID)
            end
            
            local ability = 0
            for a=1, MAX_ACTIVE_ABILITIES do
                ability = pet[a + 1]
                if ability ~= select(a + 1, C_PetJournal.GetPetLoadOutInfo(i)) then
                    Log(string.format("Pet: %i, Ability: %i", i, ability))
                    C_PetJournal.SetAbility(i, a, ability)
                else
                    setAbilities = setAbilities + 1
                end
            end
        else
            Log("Invalid GUID: "..petGUID)
        end
    end
    
    -- SetAbility is throttled so we have to wrap it with an OnUpdate event.
    if setAbilities ~= MAX_ACTIVE_PETS * MAX_ACTIVE_ABILITIES then
        PetBattleTeams.needUpdate = true
        --PetBattleTeams:SetScript("OnUpdate", PetBattleTeams_OnUpdate)
    else
        PetBattleTeams.needUpdate = false
        --PetBattleTeams:SetScript("OnUpdate", nil)
    end
    
    if PetJournal_UpdatePetLoadOut then
        PetJournal_UpdatePetLoadOut()
    elseif PetJournal_UpdateAll then
        Log("UpdateAll")
        PetJournal_UpdateAll()
    else
        Log("Fatal error, couldn't update Pet Journal UI!")
    end
end

function PetBattleTeams_OnEvent(self, event, ...)
    local arg1, arg2 = ...
    if "PLAYER_ENTERING_WORLD" == event then
        PetBattleTeamsDB.teams = PetBattleTeams_LoadMacro() or PetBattleTeamsDB.teams
    elseif "QUEST_ACCEPTED" == event then
        local questID = arg2
        if PetBattleTeamsDB.autoQuest then
            local numTeams = #PetBattleTeamsDB.teams
            for i=1, numTeams do
                local team = PetBattleTeamsDB.teams[i]
                if team.questID and (team.questID == questID) then
                    Log("Team "..team.name.." ACTIVATED!")
                    PetBattleTeams.selectedIndex = i
                    PetBattleTeams_ActivateTeam(i)
                    -- Unhealed pet warning
                    for p=1, MAX_ACTIVE_PETS do
                        local health, maxHealth = C_PetJournal.GetPetStats(team.pets[p][1])
                        if not (health == maxHealth) then
                            Log("Warning: Pets are not fully healed!")
                            break
                        end
                    end
                end
            end
        end
    end
end

function PetBattleTeams_OnLoad(self)
    -- Hooks
    --PetJournal:HookScript("OnShow", function()
    --    PetBattleTeams_Update()
    --    PetBattleTeams:Show()
    --)
    --PetJournal:HookScript("OnHide", PetBattleTeams_OnHide)
    
    -- DB settings
    if type(PetBattleTeamsDB) ~= "table" then
        PetBattleTeamsDB = {
            teams = {}
        }
    end
    
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("QUEST_ACCEPTED")
    
    -- Check for a MacroDB
    --PetBattleTeamsDB.teams = MacroDB.Load("_MacroDB") or PetBattleTeamsDB.teams
    
    PetBattleTeams:SetScript("OnUpdate", PetBattleTeams_OnUpdate)
    
    -- Make room for our UI
    PetBattleTeamsUseMacros:SetChecked(PetBattleTeamsDB.useMacros or 0)
    PetBattleTeams_ModifyPetJournalFrame()
    
    PetJournalExpandButton2.collapseTooltip = L["Hide Pet Battle Teams"]
    PetJournalExpandButton2.expandTooltip = L["Show Pet Battle Teams"]
    
    UIDropDownMenu_Initialize(self.optionsMenu, PetBattleTeamsOptionsMenu_Init, "MENU")
end

function PetBattleTeams_OnShow()
    --PetBattleTeams_Update()
    --PetBattleTeams:Show()
end

function PetBattleTeams_OnUpdate(self, elapsed)
    if true == self.needUpdate then
        --self.elapsed = self.elapsed + elapsed
        --if self.elapsed > 0.25 then
        --    self.elapsed = 0
            PetBattleTeams_ActivateTeam()
        --end
    end
end

function PetBattleTeams_Collapse()
    --PetJournalParent:SetWidth(PETJOURNAL_DEFAULT_WIDTH)
    PetJournal.Expanded = false
    PetJournalExpandButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    PetJournalExpandButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    PetJournalExpandButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    
    PetBattleTeams:Hide()
    --CharacterFrameInsetRight:Hide()
    --PaperDollFrame_SetLevel()
end

function PetBattleTeams_Expand()
    if BattlePetTabsTab1 then
        PetBattleTeams:SetPoint("LEFT", PetJournal, "RIGHT", 46, 0)
    end
    
    --PetJournalParent:SetWidth(PETJOURNAL_EXPANDED_WIDTH)
    PetJournal.Expanded = true
    PetJournalExpandButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    PetJournalExpandButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    PetJournalExpandButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    
    PetBattleTeams:Show()
    --CharacterFrameInsetRight:Show()
    --PaperDollFrame_SetLevel()
end

function PetBattleTeams_Update(scrollToSelected)
    local scrollFrame = PetBattleTeamsScrollFrame
    local offset = HybridScrollFrame_GetOffset(scrollFrame)
    local buttons = scrollFrame.buttons
    local buttonHeight = buttons[1]:GetHeight()
    local mouseIsOverScrollFrame = scrollFrame:IsVisible() and scrollFrame:IsMouseOver()
    local numButtons = #buttons
    local numTeams = #PetBattleTeamsDB.teams
    
    if true == scrollToSelected and PetBattleTeams.selectedIndex then
        local button = buttons[PetBattleTeams.selectedIndex - offset]
        if not button or (button:GetTop() > scrollFrame:GetTop()) or (button:GetBottom() < scrollFrame:GetBottom()) then
            local scrollValue = min(((PetBattleTeams.selectedIndex - 1) * buttonHeight), scrollFrame.range)
            if scrollValue ~= scrollFrame.scrollBar:GetValue() then
                scrollFrame.scrollBar:SetValue(scrollValue)
            end
        end
    end
    
    for i=1, numButtons do
        local button = buttons[i]
        local index = i + offset
        
        if index <= numTeams then
            --local teamName, teamIcon, questID = GetBattlePetTeamInfo(index)
            local team = PetBattleTeamsDB.teams[index]
            local teamName, teamIcon, questID = team.name, team.icon, team.questID
            
            if not teamIcon then
                team.icon = select(9, C_PetJournal.GetPetInfoByPetID(team.pets[1][1]))
                teamIcon = team.icon
            end
            
            if questID and type(DAILY_BATTLE_PET_QUESTS[questID]) == "string" then
                teamName = "|TInterface\\GossipFrame\\DailyQuestIcon:0|t "..DAILY_BATTLE_PET_QUESTS[questID]
            end
            
            button.icon:SetTexture(teamIcon or ICON_QUESTIONMARK)
            button.index = index
            button.teamName = teamName
            button.text:SetText(teamName)
            button.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            
            if PetBattleTeams.selectedIndex == index then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
            
            button:Show()
            
            --if mouseIsOverScrollFrame and button:IsMouseOver() then
            --    PetBattleTeam_OnEnter(button)
            --end
        elseif index == numTeams + 1 then
            button.index = nil
            button.teamName = nil
            button.text:SetText("New Team")
            button.text:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
            button.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
            button:UnlockHighlight()
            button:Show()
        else
            button:Hide()
        end    
    end
    HybridScrollFrame_Update(scrollFrame, (numTeams + 1) * buttonHeight, scrollFrame:GetHeight())
end

function PetBattleTeamsOptionsMenu_Init(self, level, menuList)
    level = level or 1
    
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    
    if 1 == level then
        info.text = BATTLE_PET_RENAME
        info.func = function() StaticPopup_Show("PET_BATTLE_TEAMS_SET_NAME", nil, nil, false) end
        UIDropDownMenu_AddButton(info, level)
        
        info.text = DELETE
        info.func = function() StaticPopup_Show("PET_BATTLE_TEAMS_DELETE") end
        UIDropDownMenu_AddButton(info, level)
        
        info.text = "Daily Quests"
        info.hasArrow = true
        info.menuList = "DAILY_BATTLE_PET_QUESTS"
        UIDropDownMenu_AddButton(info, level)
        
        info.text = CANCEL
        info.func = nil
        info.hasArrow = false
        info.menuList = nil
        UIDropDownMenu_AddButton(info, level)
    elseif "DAILY_BATTLE_PET_QUESTS" == menuList then
        for _, quest in ipairs(DAILY_BATTLE_PET_QUESTS) do
            info.text = quest[2]
            info.arg1 = tostring(quest[1])
            info.func = function(self, questID) PetBattleTeams_SetTeamName(questID); HideDropDownMenu(1) end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end


function PetBattleTeamsScrollFrame_OnLoad(self)
    HybridScrollFrame_OnLoad(self)
    self.update = PetBattleTeams_Update
    HybridScrollFrame_CreateButtons(self, "PetBattleTeamTemplate")
end


function PetBattleTeam_OnMouseDown(self)
    self.icon:SetPoint("LEFT", 2, -3)
    --self.name:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 7, -10)
    --self.subName:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -10)
end

function PetBattleTeam_OnMouseUp(self)
    self.icon:SetPoint("LEFT", 1, -2)
    --self.name:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 5, -8)
    --self.subName:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -10)
end

function PetBattleTeam_OnClick(self, button)
    if (UIDropDownMenu_GetCurrentDropDown() == PetBattleTeams.optionsMenu) then
        HideDropDownMenu(1)
    end
    
    PetBattleTeams.selectedIndex = self.index
    if "RightButton" == button then
        -- 'New Team' has no self.index
        if self.index then
            ToggleDropDownMenu(1, nil, PetBattleTeams.optionsMenu, self, 80, 20)
        end
    else
        if not self.index then
            StaticPopup_Show("PET_BATTLE_TEAMS_SET_NAME", nil, nil, true)
        else
            PetBattleTeams_Update()
            PetBattleTeams_ActivateTeam()
        end
    end
end

function PetBattleTeam_OnEnter(self)
    --if self.teamName then
    --    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    --    GameTooltip:SetText(self.teamName)
    --    GameTooltip:Show()
    --end
end
