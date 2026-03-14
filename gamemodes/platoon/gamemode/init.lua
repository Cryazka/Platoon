-- Platoon server logic
include("platoon/sh_core.lua")

-- Регистрация сетевых сообщений
util.AddNetworkString("Platoon_UpdateWaiting")
util.AddNetworkString("Platoon_OpenSideVote")
util.AddNetworkString("Platoon_OpenFactionVote")
util.AddNetworkString("Platoon_OpenRoleMenu")
util.AddNetworkString("Platoon_OpenWeaponMenu")
util.AddNetworkString("Platoon_UpdatePhase")
util.AddNetworkString("Platoon_VoteSide")
util.AddNetworkString("Platoon_VoteFaction")
util.AddNetworkString("Platoon_ChooseRole")
util.AddNetworkString("Platoon_ChooseWeapons")
util.AddNetworkString("Platoon_StartBattle")
util.AddNetworkString("Platoon_PlayerDied")

-- Инициализация
Platoon.Phase = Platoon.PHASE.WAITING

-- Хуки

-- Игрок подключается
hook.Add("PlayerInitialSpawn", "Platoon_PlayerSpawn", function(ply)
    Platoon.SetPlayerData(ply, "team", Platoon.TEAM.NONE)
    Platoon.SetPlayerData(ply, "faction", nil)
    Platoon.SetPlayerData(ply, "role", nil)
    Platoon.SetPlayerData(ply, "weapons", {})
    Platoon.SetPlayerData(ply, "isAlive", false)

    -- Делаем игрока наблюдателем с фиксированной камерой
    ply:KillSilent()                       -- убиваем
    ply:Spectate(OBS_MODE_FIXED)           -- режим фиксированной камеры
    ply:SetObserverMode(OBS_MODE_FIXED)
    -- Устанавливаем позицию камеры (можно задать красивую точку обзора)
    local camPos = Vector(0, 0, 500)       -- измените на свои координаты
    ply:SetPos(camPos)
    ply:Freeze(true)

    -- Обновляем счётчик ожидания
    Platoon.UpdateWaitingPlayers()

    -- Проверяем, не пора ли начать голосование
    Platoon.CheckStartVote()
end)

-- Игрок отключается
hook.Add("PlayerDisconnected", "Platoon_PlayerLeave", function(ply)
    Platoon.Players[ply] = nil
    Platoon.UpdateWaitingPlayers()
    Platoon.CheckStartVote()
end)

-- Игрок умирает (в бою)
hook.Add("DoPlayerDeath", "Platoon_PlayerDeath", function(ply)
    if Platoon.Phase == Platoon.PHASE.BATTLE then
        timer.Simple(5, function()
            if IsValid(ply) then
                Platoon.RespawnPlayer(ply)
            end
        end)
    end
end)

-- Обработка сетевых сообщений

net.Receive("Platoon_VoteSide", function(len, ply)
    local side = net.ReadInt(2)   -- 1 = A, 2 = B
    if Platoon.Phase ~= Platoon.PHASE.SIDE_VOTE then return end
    local data = Platoon.GetPlayerData(ply)
    if not data then return end
    data.sideVote = side
end)

net.Receive("Platoon_VoteFaction", function(len, ply)
    local factionID = net.ReadString()
    if Platoon.Phase ~= Platoon.PHASE.FACTION_VOTE_A and Platoon.Phase ~= Platoon.PHASE.FACTION_VOTE_B then return end
    local data = Platoon.GetPlayerData(ply)
    if not data then return end
    local team = data.team
    if (Platoon.Phase == Platoon.PHASE.FACTION_VOTE_A and team ~= Platoon.TEAM.A) or
       (Platoon.Phase == Platoon.PHASE.FACTION_VOTE_B and team ~= Platoon.TEAM.B) then
        return
    end
    data.factionVote = factionID
end)

net.Receive("Platoon_ChooseRole", function(len, ply)
    local role = net.ReadString()
    local data = Platoon.GetPlayerData(ply)
    if not data then return end
    if Platoon.Phase ~= Platoon.PHASE.PREPARATION and not data.respawning then return end
    if not table.HasValue(Platoon.Roles, role) then return end
    data.role = role
    -- Открываем меню выбора оружия
    net.Start("Platoon_OpenWeaponMenu")
        net.WriteString(role)
        net.WriteTable(Platoon.Factions[data.faction].weapons[role])
    net.Send(ply)
end)

net.Receive("Platoon_ChooseWeapons", function(len, ply)
    local weapons = net.ReadTable()
    local data = Platoon.GetPlayerData(ply)
    if not data then return end
    if Platoon.Phase ~= Platoon.PHASE.PREPARATION and not data.respawning then return end
    -- Проверка доступности оружия
    local allowed = Platoon.Factions[data.faction].weapons[data.role]
    for _, wpn in ipairs(weapons) do
        if not table.HasValue(allowed, wpn) then
            return  -- читерство
        end
    end
    data.weapons = weapons
    -- Если игрок возрождается, сразу выдаём снаряжение и размораживаем
    if data.respawning then
        data.respawning = nil
        ply:UnLock()
        ply:Freeze(false)
        ply:StripWeapons()
        for _, wpn in ipairs(weapons) do
            ply:Give(wpn)
        end
        local model = Platoon.Factions[data.faction].models[data.role] or Platoon.Factions[data.faction].models.default
        ply:SetModel(model)
    end
    -- Если фаза PREPARATION, то просто сохраняем выбор, оружие выдастся после старта боя
end)

-- Функции

function Platoon.UpdateWaitingPlayers()
    local count = table.Count(Platoon.Players)
    net.Start("Platoon_UpdateWaiting")
        net.WriteInt(count, 8)
    net.Broadcast()
end

function Platoon.CheckStartVote()
    if Platoon.Phase ~= Platoon.PHASE.WAITING then return end
    if table.Count(Platoon.Players) >= 4 then
        timer.Create("Platoon_StartSideVote", 5, 1, function()
            if Platoon.Phase == Platoon.PHASE.WAITING and table.Count(Platoon.Players) >= 4 then
                Platoon.StartSideVote()
            end
        end)
    else
        timer.Remove("Platoon_StartSideVote")
    end
end

function Platoon.StartSideVote()
    Platoon.Phase = Platoon.PHASE.SIDE_VOTE
    Platoon.Votes = {}
    net.Start("Platoon_OpenSideVote")
    net.Broadcast()
    timer.Create("Platoon_SideVoteTimer", 30, 1, function()
        Platoon.EndSideVote()
    end)
end

function Platoon.EndSideVote()
    if Platoon.Phase ~= Platoon.PHASE.SIDE_VOTE then return end
    local votesA, votesB = 0, 0
    for ply, data in pairs(Platoon.Players) do
        if data.sideVote == Platoon.TEAM.A then
            votesA = votesA + 1
            data.team = Platoon.TEAM.A
        elseif data.sideVote == Platoon.TEAM.B then
            votesB = votesB + 1
            data.team = Platoon.TEAM.B
        else
            if votesA <= votesB then
                data.team = Platoon.TEAM.A
                votesA = votesA + 1
            else
                data.team = Platoon.TEAM.B
                votesB = votesB + 1
            end
        end
    end
    -- Балансировка, если одна команда пуста
    if votesA == 0 then
        for ply, data in pairs(Platoon.Players) do
            data.team = Platoon.TEAM.A
            break
        end
    elseif votesB == 0 then
        for ply, data in pairs(Platoon.Players) do
            data.team = Platoon.TEAM.B
            break
        end
    end
    Platoon.StartFactionVote(Platoon.TEAM.A)
end

function Platoon.StartFactionVote(team)
    if team == Platoon.TEAM.A then
        Platoon.Phase = Platoon.PHASE.FACTION_VOTE_A
    else
        Platoon.Phase = Platoon.PHASE.FACTION_VOTE_B
    end
    local available = {}
    for id, fac in pairs(Platoon.Factions) do
        if team == Platoon.TEAM.A or (team == Platoon.TEAM.B and id ~= Platoon.TeamAFaction) then
            table.insert(available, {id = id, name = fac.name})
        end
    end
    for ply, data in pairs(Platoon.Players) do
        if data.team == team then
            data.factionVote = nil
        end
    end
    net.Start("Platoon_OpenFactionVote")
        net.WriteTable(available)
    net.Send(Platoon.GetPlayersByTeam(team))
    timer.Create("Platoon_FactionVoteTimer", 30, 1, function()
        Platoon.EndFactionVote(team)
    end)
end

function Platoon.EndFactionVote(team)
    if Platoon.Phase ~= (team == Platoon.TEAM.A and Platoon.PHASE.FACTION_VOTE_A or Platoon.PHASE.FACTION_VOTE_B) then return end
    local votes = {}
    for ply, data in pairs(Platoon.Players) do
        if data.team == team and data.factionVote then
            votes[data.factionVote] = (votes[data.factionVote] or 0) + 1
        end
    end
    local winningFaction, maxVotes = nil, -1
    for fac, count in pairs(votes) do
        if count > maxVotes then
            maxVotes = count
            winningFaction = fac
        end
    end
    if not winningFaction then
        for id, _ in pairs(Platoon.Factions) do
            if team == Platoon.TEAM.A or id ~= Platoon.TeamAFaction then
                winningFaction = id
                break
            end
        end
    end
    if team == Platoon.TEAM.A then
        Platoon.TeamAFaction = winningFaction
    else
        Platoon.TeamBFaction = winningFaction
    end
    if team == Platoon.TEAM.A then
        Platoon.StartFactionVote(Platoon.TEAM.B)
    else
        Platoon.StartPreparation()
    end
end

function Platoon.GetPlayersByTeam(team)
    local tbl = {}
    for ply, data in pairs(Platoon.Players) do
        if data.team == team then
            table.insert(tbl, ply)
        end
    end
    return tbl
end

function Platoon.StartPreparation()
    Platoon.Phase = Platoon.PHASE.PREPARATION
    for ply, data in pairs(Platoon.Players) do
        local faction = data.team == Platoon.TEAM.A and Platoon.TeamAFaction or Platoon.TeamBFaction
        data.faction = faction
        if not data.isAlive then
            ply:Spawn()
        end
        local model = Platoon.Factions[faction].models.default
        ply:SetModel(model)
        local spawnPos = (data.team == Platoon.TEAM.A) and Platoon.TeamASpawn or Platoon.TeamBSpawn
        ply:SetPos(spawnPos)
        ply:Lock()
        ply:Freeze(true)
        data.isAlive = true
    end
    net.Start("Platoon_OpenRoleMenu")
    net.Broadcast()
    timer.Create("Platoon_PreparationTimer", 60, 1, function()
        Platoon.StartBattle()
    end)
end

function Platoon.StartBattle()
    Platoon.Phase = Platoon.PHASE.BATTLE
    for ply, data in pairs(Platoon.Players) do
        ply:UnLock()
        ply:Freeze(false)
        local model = Platoon.Factions[data.faction].models[data.role] or Platoon.Factions[data.faction].models.default
        ply:SetModel(model)
        ply:StripWeapons()
        for _, wpn in ipairs(data.weapons) do
            ply:Give(wpn)
        end
    end
    net.Start("Platoon_StartBattle")
    net.Broadcast()
end

function Platoon.RespawnPlayer(ply)
    if Platoon.Phase ~= Platoon.PHASE.BATTLE then return end
    local data = Platoon.GetPlayerData(ply)
    if not data then return end
    ply:Spawn()
    local spawnPos = (data.team == Platoon.TEAM.A) and Platoon.TeamASpawn or Platoon.TeamBSpawn
    ply:SetPos(spawnPos)
    ply:Lock()
    ply:Freeze(true)
    data.respawning = true
    net.Start("Platoon_PlayerDied")
    net.Send(ply)
end