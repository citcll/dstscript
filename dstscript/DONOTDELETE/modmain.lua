-- script_ver="1.0.0"
local _G = GLOBAL
local TheNet = _G.TheNet
local TheSim = _G.TheSim

if TheNet and TheNet:GetIsServer() then
    local SERVER_NAME = TheNet:GetDefaultServerName()
    local SERVER_DESCRIPTION = TheNet:GetDefaultServerDescription()
    local SERVER_MAXPLAYERS = TheNet:GetDefaultMaxPlayers()
    local SERVER_GAMEMODE = TheNet:GetDefaultGameMode()
    local SERVER_DEDICATED = TheNet:GetServerIsDedicated()
    local SERVER_PASSWORDED = TheNet:GetServerHasPassword()
    local SERVER_PVP = TheNet:GetDefaultPvpSetting()
    local SERVER_MODS = TheNet:GetServerModsEnabled()
    local SERVER_CLANID = TheNet:GetServerClanID()
    local SERVER_CLANONLY = TheNet:GetServerClanOnly()
    local SERVER_PASSWORD = TheNet:GetDefaultServerPassword()
    local SERVER_MODSLIST = TheNet:GetServerModNames()
    
    local function GetStatus(inst, source)
        local f = _G.io.open("gifts_info.json","w")
        
        f:write("房间名称：", SERVER_NAME, "\n")
        f:write("房间名称：", SERVER_DESCRIPTION, "\n")
        f:write("房间名称：", SERVER_MAXPLAYERS, "\n")
        f:write("房间名称：", SERVER_GAMEMODE, "\n")
        f:write("房间名称：", SERVER_NAME, "\n")
        f:write("房间名称：", SERVER_NAME, "\n")
        f:write("房间名称：", SERVER_NAME, "\n")
        f:write("房间名称：", SERVER_NAME, "\n")
        f:write("房间名称：", SERVER_NAME, "\n")
        settings["description"] = SERVER_DESCRIPTION
        settings["maxplayers"] = SERVER_MAXPLAYERS
        settings["gamemode"] = SERVER_GAMEMODE
        settings["dedicated"] = SERVER_DEDICATED
        settings["passworded"] = SERVER_PASSWORDED
        settings["pvp"] = SERVER_PVP
        settings["mods"] = SERVER_MODS
        settings["clanid"] = SERVER_CLANID
        settings["clanonly"] = SERVER_CLANONLY
        settings["adminonline"] = TheNet:GetServerHasPresentAdmin()
        settings["session"] = TheNet:GetSessionIdentifier()
        
        if CONFIG_SENDPASSWORD == true then
            settings["password"] = SERVER_PASSWORD
        end
        
        n = 1
        for i, v in ipairs(TheNet:GetClientTable()) do
            players[n] = {}
            players[n]["name"] = v.name
            players[n]["prefab"] = v.prefab
            players[n]["age"] = v.playerage
            
            if v.steamid == nil or v.steamid == '' then
                players[n]["steamid"] = v.netid
            else
                players[n]["steamid"] = v.steamid
            end
            
            players[n]["userid"] = v.userid
            players[n]["admin"] = v.admin
            n = n+1
        end
        
        for k, v in pairs(_G.TheWorld.state) do
            statevars[k] = v
        end
        
        if _G.TheWorld.topology.overrides ~= nil then
            world["overrides"] = {}
        
            if _G.TheWorld.topology.overrides.original.preset ~= nil then
                world["preset"] = _G.TheWorld.topology.overrides.original.preset
            end
            
            if _G.TheWorld.topology.overrides.original.tweak ~= nil then
                for k, v in pairs( _G.TheWorld.topology.overrides.original.tweak ) do
                    world["overrides"][k] = {}
                    for l, b in pairs( v ) do
                        world["overrides"][k][l] = b
                    end
                end
            end
        else
            world = "unknown"
        end
        
        data["settings"] = settings
        data["mods"] = SERVER_MODSLIST
        data["world"] = world
        data["statevars"] = statevars
        data["players"] = players

        local f = _G.io.open("gifts_info.json","w")
        if f ~= nil then
            f:write(_G.json.encode(data))
            f:close()
        end
    end

    AddPrefabPostInit("world", function(inst)
        inst:ListenForEvent("phasechanged", function(inst) GetStatus(inst, "phasechanged") end)
        inst:ListenForEvent("ms_playerjoined", function(inst) GetStatus(inst, "ms_playerjoined") end)
        inst:ListenForEvent("ms_playerleft", function(inst) GetStatus(inst, "ms_playerleft") end)
        inst:DoPeriodicTask(60, function(inst) GetStatus(inst, "schedule") end)
    end)
end
