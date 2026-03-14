-- Platoon shared core
Platoon = Platoon or {}

-- Список фракций
Platoon.Factions = {
    ["combine"] = {
        name = "Альянс",
        models = {
            default = "models/combine_soldier.mdl",
            crew = "models/combine_super_soldier.mdl",
            infantry = "models/combine_soldier.mdl",
            engineer = "models/combine_engineer.mdl"
        },
        weapons = {
            crew = {"weapon_physcannon", "weapon_pistol"},
            infantry = {"weapon_shotgun", "weapon_smg1"},
            engineer = {"weapon_pistol", "weapon_physcannon"}
        },
        vehicles = {
            tier0 = {"prop_vehicle_jeep"},
            tier1 = {"prop_vehicle_airboat"}
        },
        spawnpoints = {}
    },
    ["rebels"] = {
        name = "Повстанцы",
        models = {
            default = "models/player/Group03/male_07.mdl",
            crew = "models/player/Group03/male_09.mdl",
            infantry = "models/player/Group03/male_07.mdl",
            engineer = "models/player/Group03/male_06.mdl"
        },
        weapons = {
            crew = {"weapon_pistol"},
            infantry = {"weapon_ar2", "weapon_rpg"},
            engineer = {"weapon_pistol", "weapon_frag"}
        },
        vehicles = {
            tier0 = {"prop_vehicle_jeep"},
            tier1 = {}
        },
        spawnpoints = {}
    }
}

-- Роли
Platoon.Roles = {"crew", "infantry", "engineer"}

-- Состояния игры
Platoon.PHASE = {
    WAITING       = 1,  -- ожидание игроков
    SIDE_VOTE     = 2,  -- голосование за сторону
    FACTION_VOTE_A = 3, -- голосование за фракцию для команды А
    FACTION_VOTE_B = 4, -- голосование за фракцию для команды Б
    PREPARATION   = 5,  -- подготовка (выбор роли)
    BATTLE        = 6   -- бой
}
Platoon.Phase = Platoon.PHASE.WAITING

-- Команды
Platoon.TEAM = {
    NONE = 0,
    A    = 1,
    B    = 2
}

-- Глобальные переменные состояния
Platoon.Players      = {}          -- таблица игроков с данными
Platoon.TeamAScore   = 0
Platoon.TeamBScore   = 0
Platoon.TeamAFaction = nil
Platoon.TeamBFaction = nil
Platoon.Votes        = {}          -- для голосований

-- Точки спавна (задайте свои координаты)
Platoon.TeamASpawn = Vector(0, 0, 200)
Platoon.TeamBSpawn = Vector(200, 0, 200)

-- Функции для работы с данными игрока
function Platoon.GetPlayerData(ply)
    return Platoon.Players[ply]
end

function Platoon.SetPlayerData(ply, key, value)
    if not Platoon.Players[ply] then
        Platoon.Players[ply] = {}
    end
    Platoon.Players[ply][key] = value
end