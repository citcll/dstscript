-- script_ver="1.2.5"
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
    if modid ~= nil then
        if modid == "DONOTDELETE" then
            name = "一定不要删这个，不然MOD增删功能会出错导致服务器无法运行"
        end
        f:write(modid)
    end
    if name ~= nil then
        name = trim(name)
        name = LuaReomve(name, "\n")
        f:write(":", name, "\n")
    end
    f:close()
end

function writein()
    local f = assert(io.open("modconfwrite.lua", 'w'))
    if name ~= nil then
        name = trim(name)
        name = LuaReomve(name, "\n")
        f:write("--", name, "\n")
    end
    if configuration_options ~= nil and #configuration_options > 0 then
        f:write('["', modid, '"]={\n')
        f:write("    configuration_options={\n")
        for i, j in pairs(configuration_options) do
            if j.default ~= nil then
                if type(j.default) == "string" then
                    f:write('        ["', j.name, '"]="', string.format("%s", j.default), '"')
                else
                    if type(j.default) == "table" then
                        f:write('        ["', j.name, '"]= {\n')
                        for m, n in pairs(j.default) do
                            if type(n) == "table" then
                                f:write('            {')
                                for g, h in pairs(n) do
                                    if type(h) == "string" then
                                        f:write('"', string.format("%s", h), '"')
                                    else
                                        f:write(string.format("%s", h))
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
                        f:write('        }')
                    else
                        f:write('        ["', j.name, '"]=', string.format("%s", j.default))
                    end
                end
                if i ~= #configuration_options then
                    f:write(',')
                end
                if j.options ~= nil and #j.options > 0 then
                    f:write("     --[[ ", j.label or j.name, ": ")
                    for k, v in pairs(j.options) do
                        if type(v.data) ~= "table" then
                            f:write(string.format("%s", v.data), "(", v.description, ") ")
                        end
                    end
                    f:write("]]\n")
                else
                    f:write("     --[[ ", j.label or j.name, " ]]\n")
                end
            else
                f:write('        ["', j.name, '"]=""')
                if i ~= #configuration_options then
                    f:write(',')
                end
                f:write("     --[[ ", j.label or j.name, " ]]\n")
            end
        end
        f:write("    },\n")
        f:write('    ["enabled"]=true\n')
        f:write("},\n")
    else
        f:write('["', modid, '"]={ configuration_options={ }, ["enabled"]=true },\n')
    end
    f:close()
end
function getver()
    print(version)
end
if fuc == "list" then
    list()
elseif fuc == "getver" then
    getver()
elseif fuc == "writein" then
    writein()
end