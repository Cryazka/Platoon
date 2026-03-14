-- shared.lua

-- Подключаем наши модули (если они есть)
include( "modules/sh_core.lua" )

-- Информация о гейммоде
GM.Name 	= "Platoon"
GM.Author 	= "Твоё имя"
GM.Email 	= ""
GM.Website	= ""
GM.TeamBased = true  -- у нас командная игра

--[[---------------------------------------------------------
   Создание команд (обязательно shared)
-----------------------------------------------------------]]
function GM:CreateTeams()
    -- Регистрируем команды для встроенной системы (можно и не использовать, но полезно)
    TEAM_A = 1
    team.SetUp( TEAM_A, "Команда А", Color( 0, 0, 255 ) )
    team.SetSpawnPoint( TEAM_A, "info_player_start" ) -- можно заменить на свои точки

    TEAM_B = 2
    team.SetUp( TEAM_B, "Команда Б", Color( 255, 150, 0 ) )
    team.SetSpawnPoint( TEAM_B, "info_player_start" )
end

-- Здесь можно добавить другие общие хуки, если нужно
-- Например:
function GM:PlayerInitialSpawn( ply, transition )
    -- будет вызван и на сервере, и на клиенте? Нет, этот хук только серверный.
    -- В shared лучше не вешать специфичные хуки.
end