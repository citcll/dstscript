-- script_ver="1.3.0"
require "modinfo"

-- Addon function
function trim (s) 
    return (string.gsub(s, "^%s*(.-)%s*$", "%1")) 
end

function LuaReomve(str,remove)
    local lcSubStrTab = {}    
    while true do        
        local lcPos = string.find(str,remove)
        if not lcPos then
            lcSubStrTab[#lcSubStrTab+1] =  str                
            break        
        end        
        local lcSubStr  = string.sub(str,1,lcPos-1)        
        lcSubStrTab[#lcSubStrTab+1] = lcSubStr        
        str = string.sub(str,lcPos+1,#str)    
    end    
    local lcMergeStr =""    
    local lci = 1    
    while true do        
        if lcSubStrTab[lci] then            
            lcMergeStr = lcMergeStr .. lcSubStrTab[lci]             
            lci = lci + 1        
        else             
            break        
        end    
    end    
    return lcMergeStr
end
---
function list()
    local f = assert(io.open("modconflist.lua", 'a'))
    if used == "true" then
        f:write("[已启用]:")
    else
        f:write("[未启用]:")
    end
    if modid == nil then
        modid = "unknown"
    end
    if name ~= nil then
        name = trim(name)
        name = LuaReomve(name, "\n")
    else
        name = "Unknown"
    end
    f:write(modid, ":", name, "\n")
    f:close()
end

function writein()
    local f = assert(io.open("modconfwrite.lua", 'w'))
    if name ~= nil then
        name = trim(name)
        name = LuaReomve(name, "\n")
    end
    if configuration_options ~= nil and #configuration_options > 0 then
        f:write('  ["', modid, '"]={    --[[', name, "]]\n")
        f:write("    configuration_options={\n")
        for i, j in pairs(configuration_options) do
            if j.default ~= nil then
                if type(j.default) == "string" then
                    f:write('      ["', j.name, '"]="', j.default, '"')
                else
                    if type(j.default) == "table" then
                        f:write('      ["', j.name, '"]= {\n')
                        for m, n in pairs(j.default) do
                            if type(n) == "table" then
                                f:write('        {')
                                for g, h in pairs(n) do
                                    if type(h) == "string" then
                                        f:write('"', h, '"')
                                    else
                                        f:write(tostring(h))
                                    end
                                    if g ~= #n then
                                        f:write(", ")
                                    end
                                end
                                if m ~= #j.default then
                                    f:write("},\n")
                                else
                                    f:write("}\n")
                                end
                            end
                        end
                        f:write('      }')
                    else
                        f:write('      ["', j.name, '"]=', tostring(j.default))
                    end
                end
                if i ~= #configuration_options then
                    f:write(',')
                end
                if j.options ~= nil and #j.options > 0 then
                    f:write("     --[[ ", j.label or j.name, ": ")
                    for k, v in pairs(j.options) do
                        if type(v.data) ~= "table" then
                            local vd = v.data
                            if type(v.data) ~= "string" then
                                vd = tostring(vd)
                            end    
                            f:write(vd, "(", v.description, ") ")
                        end
                    end
                    f:write("]]\n")
                else
                    f:write("     --[[ ", j.label or j.name, " ]]\n")
                end
            else
                f:write('      ["', j.name, '"]=""')
                if i ~= #configuration_options then
                    f:write(',')
                end
                f:write("     --[[ ", j.label or j.name, " ]]\n")
            end
        end
        f:write("    },\n")
        f:write('    ["enabled"]=true\n')
        f:write("  },\n")
    else
        f:write('  ["', modid, '"]={ ["enabled"]=true },    --[[', name, "]]\n")
    end
    f:close()
end
function getver()
    print(version)
end
function table2json(t)  
    local function serialize(tbl)  
        local tmp = {}  
        for k, v in pairs(tbl) do  
            local k_type = type(k)  
            local v_type = type(v)  
            local key = (k_type == "string" and "\"" .. k .. "\":")  
                or (k_type == "number" and "")  
            local value = (v_type == "table" and serialize(v))  
                or (v_type == "boolean" and tostring(v))  
                or (v_type == "string" and "\"" .. v .. "\"")  
                or (v_type == "number" and v)  
                tmp[#tmp + 1] = key and value and tostring(key) .. tostring(value) or nil  
        end  
        if table.maxn(tbl) == 0 then  
            return "{" .. table.concat(tmp, ",") .. "}"  
        else  
            return "[" .. table.concat(tmp, ",") .. "]"  
        end  
    end  
    assert(type(t) == "table")  
    return serialize(t)  
end
function getname()
    print(name)
end
if fuc == "list" then
    list()
elseif fuc == "getver" then
    getver()
elseif fuc == "getname" then
    getname()
elseif fuc == "writein" then
    writein()
end