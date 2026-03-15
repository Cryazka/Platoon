-- Platoon client logic
include("modules/sh_core.lua")
-- include("modules/client/ui/.lua")

print("Client Init")

-- Переменные для HUD
Platoon.WaitingCount = 0
Platoon.CurrentPhase = Platoon.PHASE.WAITING

-- создаёт простое окно голосования
local function CreateVotePanel(title, options, callback)
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 300)
    frame:Center()
    frame:SetTitle(title)
    frame:SetVisible(true)
    frame:MakePopup()

    local list = vgui.Create("DPanelList", frame)
    list:SetPos(10, 30)
    list:SetSize(380, 230)
    list:SetSpacing(5)
    list:EnableHorizontal(false)

    for _, opt in ipairs(options) do
        local btn = vgui.Create("DButton")
        btn:SetText(opt.name or opt)
        btn.DoClick = function()
            callback(opt.id or opt)
            frame:Close()
        end
        list:AddItem(btn)
    end
    return frame
end

-- HUD
hook.Add("HUDPaint", "Platoon_HUD", function()
    local phaseNames = {
        [Platoon.PHASE.WAITING] = "Ожидание игроков",
        [Platoon.PHASE.SIDE_VOTE] = "Голосование за сторону",
        [Platoon.PHASE.FACTION_VOTE_A] = "Голосование за фракцию (команда А)",
        [Platoon.PHASE.FACTION_VOTE_B] = "Голосование за фракцию (команда Б)",
        [Platoon.PHASE.PREPARATION] = "Подготовка",
        [Platoon.PHASE.BATTLE] = "Бой"
    }
    local phaseText = phaseNames[Platoon.CurrentPhase] or "Неизвестная фаза"
    draw.SimpleText(phaseText, "TargetID", 10, 10, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    if Platoon.CurrentPhase == Platoon.PHASE.WAITING then
        draw.SimpleText("Игроков: " .. Platoon.WaitingCount .. "/4", "TargetID", 10, 40, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end)

-- Сетевые обработчики

-- 
net.Receive("Platoon_UpdateWaiting", function()
    local count = net.ReadInt(8)
    Platoon.WaitingCount = count
    chat.AddText("Ожидание игроков: " .. count .. "/4")
end)

net.Receive("Platoon_OpenSideVote", function()
    Platoon.CurrentPhase = Platoon.PHASE.SIDE_VOTE
    CreateVotePanel("Выберите сторону",
        {{id = Platoon.TEAM.A, name = "Команда А"}, {id = Platoon.TEAM.B, name = "Команда Б"}},
        function(choice)
            net.Start("Platoon_VoteSide")
            net.WriteInt(choice, 2)
            net.SendToServer()
        end
    )
end)

net.Receive("Platoon_OpenFactionVote", function()
    local factions = net.ReadTable()
    -- -- Определяем фазу
    -- if string.find(net.GetName() or "", "A") then -- грубовато, лучше передавать фазу отдельно, но для простоты:
    --     Platoon.CurrentPhase = Platoon.PHASE.FACTION_VOTE_A
    -- else
    --     Platoon.CurrentPhase = Platoon.PHASE.FACTION_VOTE_B
    -- end
    CreateVotePanel("Выберите фракцию", factions,
        function(choice)
            net.Start("Platoon_VoteFaction")
            net.WriteString(choice)
            net.SendToServer()
        end
    )
end)

net.Receive("Platoon_OpenRoleMenu", function()
    Platoon.CurrentPhase = Platoon.PHASE.PREPARATION
    local roles = {
        {id = "crew", name = "Экипаж"},
        {id = "infantry", name = "Пехотинец"},
        {id = "engineer", name = "Инженер"}
    }
    CreateVotePanel("Выберите роль", roles,
        function(choice)
            net.Start("Platoon_ChooseRole")
            net.WriteString(choice)
            net.SendToServer()
        end
    )
end)

net.Receive("Platoon_OpenWeaponMenu", function()
    local role = net.ReadString()
    local weapons = net.ReadTable()
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 400)
    frame:Center()
    frame:SetTitle("Выберите оружие для " .. role)
    frame:SetVisible(true)
    frame:MakePopup()

    local list = vgui.Create("DPanelList", frame)
    list:SetPos(10, 30)
    list:SetSize(380, 320)
    list:SetSpacing(5)

    local checkboxes = {}
    for _, wpn in ipairs(weapons) do
        local cb = vgui.Create("DCheckBoxLabel")
        cb:SetText(wpn)
        cb:SetValue(false)
        cb:SizeToContents()
        list:AddItem(cb)
        checkboxes[wpn] = cb
    end

    local btn = vgui.Create("DButton")
    btn:SetText("Подтвердить")
    btn.DoClick = function()
        local selected = {}
        for wpn, cb in pairs(checkboxes) do
            if cb:GetChecked() then
                table.insert(selected, wpn)
            end
        end
        net.Start("Platoon_ChooseWeapons")
        net.WriteTable(selected)
        net.SendToServer()
        frame:Close()
    end
    list:AddItem(btn)
end)

net.Receive("Platoon_PlayerDied", function()
    -- Открываем меню выбора роли для возрождения
    local roles = {
        {id = "crew", name = "Экипаж"},
        {id = "infantry", name = "Пехотинец"},
        {id = "engineer", name = "Инженер"}
    }
    CreateVotePanel("Выберите роль (возрождение)", roles,
        function(choice)
            net.Start("Platoon_ChooseRole")
            net.WriteString(choice)
            net.SendToServer()
        end
    )
end)

net.Receive("Platoon_StartBattle", function()
    Platoon.CurrentPhase = Platoon.PHASE.BATTLE
    -- Закрываем все возможные окна
    for _, v in ipairs(vgui.GetAll()) do
        -- if v:GetClass() == "DFrame" 
        -- then v:Close() 
        -- end
    end
    chat.AddText(Color(0,255,0), "Бой начался!")
end)

-- Обновление фазы (если понадобится)
net.Receive("Platoon_UpdatePhase", function()
    local phase = net.ReadInt(8)
    Platoon.CurrentPhase = phase
end)