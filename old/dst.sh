#!/bin/bash
#===============================================================================
#    System Required: Ubuntu12+/Debian7+
#    Description: Install and manager the Don't Starve Together Dedicated Server
#    Version: 2.0.0 2018-06-01 23:35:46
#    Author: Ariwori
#    Blog: https://blog.wqlin.com/dstscript.html
#===============================================================================
# 变量
version="2.0.0"
configfile_version="2.0.0"
rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
logdir="${rootdir}/log"
dstscriptdir="${rootdir}/dstscript"
steamcmddir="${rootdir}/steamcmd"
serverfiles="${rootdir}/dstserver"
tmpdir="${dstscriptdir}/tmp"
luadir="${dstscriptdir}/lua"
configdir="${dstscriptdir}/config"
clusterdir="${rootdir}/.klei/DoNotStarveTogether"
DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer"
update_address="http://p8wicvrbk.bkt.clouddn.com/dst"
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"
separate(){ echo "————————————————————————————————————————————————"; }
info(){ echo -e "${Info} $1"; }
tip(){ echo -e "${Tip} $1"; }
error(){ echo -e "${Error} $1"; }
# 获取系统信息用于安装依赖判断
check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    bit=`uname -m`
}
# 获取外网IP
Get_IP(){
    ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
    if [[ -z "${ip}" ]]; then
        ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
        if [[ -z "${ip}" ]]; then
            ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
            if [[ -z "${ip}" ]]; then
                ip="VPS_IP"
            fi
        fi
    fi
}
# 安装依赖
Install_dependency(){
    info "首次使用脚本，安装必要依赖及软件..."
    if [[ ${bit} == "x86_64" ]]; then
        if [[ ${release} == "debian" || ${release} == "ubuntu" ]]; then
            sudo dpkg --add-architecture i386;
            sudo apt update;
            sudo apt install -y wget tmux lua5.2 lib32gcc1 libstdc++6 libstdc++6:i386 libcurl4-gnutls-dev:i386
        elif [[ ${release} == "centos" ]]; then
            error "暂不支持当前系统！" && exit 1
        elif [[ ${release} == "fedora" ]]; then
            error "暂不支持当前系统！" && exit 1
        else
            error "暂不支持当前系统！" && exit 1
        fi
    elif [[ ${bit} == "x86" ]]; then
        if [[ ${release} == "debian" || ${release} == "ubuntu" ]]; then
            sudo apt install -y wget tmux lua5.2 libstdc++6 libcurl4-gnutls-dev
        elif [[ ${release} == "centos" ]]; then
            error "暂不支持当前系统！" && exit 1
        elif [[ ${release} == "dnf" ]]; then
            error "暂不支持当前系统！" && exit 1
        else
            error "暂不支持当前系统！" && exit 1
        fi
    else
        error "暂不支持当前系统！" && exit 1
    fi
    jsonmodify firstuse false
}
# 脚本更新
Update_Shell(){
    info "当前版本为 [ ${sh_ver} ]，开始检测最新版本..."
    sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ariwori/ariwori/master/shell/dst.sh" |grep '^version=' |awk -F "=" '{print $NF}' |sed 's/\"//g' |head -1)
    [[ -z ${sh_new_ver} ]] && tip "检测最新版本失败 !" && exit 0
    if [[ ${sh_new_ver} != ${sh_ver} ]]; then
        info "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
        stty erase '^H' && read -p "(默认: y):" yn
        [[ -z "${yn}" ]] && yn="y"
        if [[ ${yn} == [Yy] ]]; then
            wget -N --no-check-certificate https://raw.githubusercontent.com/ariwori/ariwori/master/shell/dst.sh && chmod +x dst.sh
            info "脚本已更新为最新版本[ ${sh_new_ver} ] !"
        else
            tip "已取消..."
        fi
    else
        info "当前已是最新版本[ ${sh_new_ver} ] !"
    fi
}
# 重置配置文件
reset_files(){
    create_dstconf
    create_wordconf
}
# 检查必要配置文件，缺失则创建默认配置文件
check_files(){
    if [[ ! -d ${configdir} ]]; then mkdir -p ${configdir}; fi
    if [[ ! -f ${configdir}/dstscript.json ]]; then create_dstconf; fi
    if [[ ! -f ${configdir}/cave_level.json || ! -f ${configdir}/forest_level.json || ! -f ${configdir}/world_level_options.json ]]; then create_wordconf; fi
    if [ ! -d ${luadir} ]; then mkdir -p ${luadir}; fi
    if [ ! -f ${luadir}/modconf.lua ]; then create_lua; fi
    if [[ $(jq '.configfiles_version' ${configdir}/dstscript.json) != ${configfiles_version} ]; then reset_files; fi
    if [[ $(jq '.firstuse' ${configdir}/dstscript.json) == true ]]; then Install_dependency; fi
}
# 创建LUA脚本用于写MOD详细配置
create_lua(){
    cat > ${luadir}/modconf.lua<<-EOF
require "modinfo"

function list()
    local f = assert(io.open("modconfstr.lua", 'a'))
    if modid ~= nil then
        f:write(modid)
    end
    if name ~= nil then
        if name == "UNKNOWN" then
            f:write("---------", name, "\n")
        else
            if modid ~= 1115709310 and modid ~= 1084023218 then
                f:write("---------", name, "\n")
            else
                f:write("---------", name)
            end
         end
    end
    f:close()
end

function writein()
    local f = assert(io.open("modconfstr.lua", 'w'))
    if name == "UNKNOWN" then
        f:write("    --", name, "\n")
    else
        if modid ~= 1115709310 and modid ~= 1084023218 then
            f:write("    --", name, "\n")
        else
            f:write("    --", name)
        end
    end
    if configuration_options ~= nil and #configuration_options > 0 then
        f:write('    ["workshop-', modid, '"]={\n')
        f:write("        configuration_options={\n")
        for i, j in pairs(configuration_options) do
            if j.default ~= nil then
                if type(j.default) == "string" then
                    f:write('            ["', j.name, '"]="', string.format("%s", j.default), '"')
                else
                    if type(j.default) == "table" then
                        f:write('            ["', j.name, '"]= {\n')
                        for m, n in pairs(j.default) do
                            if type(n) == "table" then
                                f:write('                {')
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
                        f:write('            }')
                    else
                        f:write('            ["', j.name, '"]=', string.format("%s", j.default))
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
                f:write('            ["', j.name, '"]=""')
                    if i ~= #configuration_options then
                        f:write(',')
                    end
                    f:write("     --[[ ", j.label or j.name, " ]]\n")
                end
            end
            f:write("        },\n")
            f:write("        enabled=true\n")
            f:write("    },\n")
        else
            f:write('    ["workshop-', modid, '"]={ configuration_options={ }, enabled=true },\n')
        end
        f:close()
end

if fuc == "list" then
    list()
else
    writein()
end
EOF
}
Cluster_manager(){
    if [ ! -d ${clusterdir} ]; then mkdir -p ${clusterdir}; fi
    echo -e "${Separator}
  DST Dedicated Server 存档管理面板
${Separator}
  ${Green_font_prefix}1.${Font_color_suffix} 新建存档      ${Green_font_prefix}2.${Font_color_suffix} 更改已有存档      ${Green_font_prefix}3.${Font_color_suffix} 删除已有存档
${Separator}"
    echo && stty erase '^H' && read -p "请输入数字 [1-3]：" num
    case "$num" in
        1)
        new_cluster
        ;;
        1)
        modify_cluster
        ;;
        3)
        delete_cluster
        ;;
        *)
        error "请输入正确的数字[1-3]"
        ;;
    esac
}
# 新建存档
new_cluster(){
    info "请输入存档名称（不要包含中文、特殊字符和空格）"
    read cluster
    if [[ "$cluster" != "" ]]; then
        mkdir -p ${clusterdir}/${cluster}
        set_cluster
        set_serverini
    else
        error "输入无效，已退出！"
    fi
}
# 修改已有存档
modify_cluster(){
    list_cluster
    info "输入你要修改的存档编号："
    red num
    cluster=$clusterarr[$num]
    set_cluster
}
# 删除存档
delete_cluster(){
    list_cluster
    info "输入你要删除的存档编号："
    red num
    cluster=$clusterarr[$num]
    rm -rf ${clusterdir}/${cluster}
    info "存档【$cluster】已删除！"
}
# Get shard num
getshardnum(){
   forestnum=$(ls -l ${clusterdir}/${cluster}|grep -c Forest)
   cavesnum=$(ls -l ${clusterdir}/${cluster}|grep -c Caves)
   shardnum=$[$forestnum + $cavesnum] 
}
# server.ini
set_serverini(){
    while(true); do
        clear
        echo -e "\e[33m===================================世界设置===================================\e[0m"
        echo -e "\e[92m     当前存档：$cluster\e[0m"
        echo -e "\e[92m  无论是多服务器还是单服务器，请保证有且只有一个主世界，地上洞穴无所谓\e[0m"
        echo -e "\e[92m     [1] 增加一个地上世界    [2] 删除一个地上世界\e[0m"
        echo -e "\e[92m     [3] 增加一个洞穴世界    [4] 删除一个洞穴世界\e[0m"
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：\e[0m\c"
        read cmd
        if [ $cmd -ne 0 ]; then
            tip "是否增加一个主世界[y/n]"
            read ismaster
            if [[ $ismaster = [Yy] ]]; then
                is_master="true"
            else
                is_master="false"
            fi
            getshardnum
            id=$[$shardnum + 1]
            server_port=$[1110 + $id]
            master_server_port=$[27010 + $id]
            authentication_port=$[8760 + $id]
        else
            break
        fi
        case $cmd in
            1)
            word_type="Forest"
            addshard
            ;;
            2)
            word_type="Forest"
            delshard
            ;;
            3)
            word_type="Caves"
            addshard
            ;;
            4)
            word_type="Caves"
            delshard
            ;;
            *)
            error "请输入正确的数字[1-4]"
            ;;
        esac
    done
}
# Word settings override
word_settings(){
    line=3
    settings_num=$(jq '.[0].num' ${configdir}/word_level.json)
    while(true); do
        separate
        echo -e "          ${Yellow_font_prefix}$word_type 世界配置${Font_color_suffix}"
        separate
        for index in {1..$settings_num}; do
            type=$(jq ".[$index].type" ${configdir}/word_level.json)
            shard=$(jq ".[$index].shard" ${configdir}/word_level.json)
            name=$(jq ".[$index].cn_str" ${configdir}/word_level.json)
            if [ $line -gt $index ]; then
                char="\c"
            else
                $line=$[$line + 3]
            fi
            if [[ $shard != $notshard ]]; then
                echo -e "    ${Yellow_font_prefix}$index. $name${Font_color_suffix}${char}"
            fi
        done
        separate
        echo && stty erase '^H' && read -p "请输入数字 [1-15]：" num
        name=$(jq ".[$num].cn_str" ${configdir}/word_level.json)
        echo "更改${Yellow_font_prefix}$name${Font_color_suffix}为："
        opnum=$(jq ".[$num].options[0].num" ${configdir}/word_level.json)
        for i in {1..$opnum}; do
             
}
# Add shard
addshard(){
    if [[ $word_type == "Forest" ]]; then
        num=$[$forestnum + 1]
        notshard="caves"
    else
        num=$[$cavesnum + 1]
        notshard="forest"
    fi
    mkdir -p ${clusterdir}/${cluster}/${word_type}_${num}
    write_serverini
    word_settings
}
# Delete shard
delshard(){
    if [ $shardnum -eq 1 ]; then
        error "无可用世界！"
    else
        echo ${Separator}
        info "已有世界："
        ls -l|grep $wordtype|awk '{print $9}'
        read delnum
        info "请输入你要删除的$word_type编号："
        rm -rf ${clusterdir}/${cluster}/${word_type}_{$delnum}
        info "存档【${cluster}】世界${word_type}_{$delnum}已删除！"
    fi
}
# Write server.ini
write_serverini(){
    echo "[NETWORK]
server_port = ${server_port}


[SHARD]
is_master = ${is_master}
name = ${word_type}_${num}
id = $id


[ACCOUNT]
encode_user_path = true


[STEAM]
master_server_port = $master_server_port
authentication_port = $authentication_port" > "${clusterdir}/${cluster}/${word_type}_${num}/server.ini" 
}
# cluster.ini
set_cluster(){
    steam_group_admins="false"
    steam_group_id=0
    steam_group_only="false"
    game_mode="survival"
    max_player=6
    pvp="false"
    pause_when_empty="true"
    vote_enabled="true"
    cluster_intention="cooperative"
    cluster_description="The Server is created by Ariwori's Script!"
    cluster_name="Ariwori's World"
    cluster_password=""
    whitelist_slots=0
    master_ip=127.0.0.1
    while :
    do
    clear
    echo -e "\e[33m===================================服务器设置===================================\e[0m"
    echo -e "\e[92m     当前存档：$cluster\e[0m"
    echo -e "\e[92m     [1] 房间名称：$cluster_name\e[0m"
    echo -e "\e[92m     [2] 房间简介：$cluster_description\e[0m"
    echo -e "\e[92m     [3] 游戏风格：$cluster_intention\e[0m"
    echo -e "\e[92m     [4] 游戏模式：$game_mode\e[0m"
    echo -e "\e[92m     [5] 群组ID：$steam_group_id\e[0m"
    echo -e "\e[92m     [6] 官员设为管理员：$steam_group_admins\e[0m"
    echo -e "\e[92m     [7] 仅组员可进：$steam_group_only\e[0m"
    echo -e "\e[92m     [8] 无人暂停：$pause_when_empty \e[0m"
    echo -e "\e[92m     [9] 开启投票：$vote_enabled\e[0m"
    echo -e "\e[92m     [10] 开启PVP：$pvp\e[0m"
    echo -e "\e[92m     [11] 预留房间位置个数：$whitelist_slots\e[0m"
    echo -e "\e[92m     [12] 主世界IP(多服务器必须修改此项)：$master_ip\e[0m"
    echo -e "\e[92m     [13] 房间密码：$cluster_password\e[0m"
    echo -e "\e[92m     [14] 最大玩家人数：$max_player\e[0m"
    echo -e "\e[33m================================================================================\e[0m"
    echo -e "\e[92m请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：\e[0m\c"
    read cmd
    case $cmd in
        0)
        writecluster
        break
        ;;
        1)
        echo -e "\e[92m请输入服务器名字：\e[0m\c"
        read cluster_name
        ;;
        2)
        echo -e "\e[92m请输入服务器介：\e[0m\c"
        read cluster_description
        ;;
        3)
        echo -e "\e[92m请选择游戏风格？1.休闲 2.合作 3.竞赛 4.疯狂：\e[0m\c"
        read intent
        case $intent in
            1)
            cluster_intention="social"
            ;;
            2)
            cluster_intention="cooperative"
            ;;
            3)
            cluster_intention="competitive"
            ;;
            4)
            cluster_intention="madness"
            ;;
        esac
        ;;
        4)
        echo -e "\e[92m请选择游戏模式？1.无尽 2.生存 3.荒野：\e[0m\c"
        read choosemode
        case $choosemode in
            1)
            game_mode="endless"
            ;;
            2)
            game_mode="survival"
            ;;
            3)
            game_mode="wilderness"
            ;;
        esac
        ;;
        5)
        echo -e "\e[92m请输入Steam群组ID:\e[0m\c"
        read steam_group_id
        ;;
        6)
        echo -e "\e[92m群组官员是否设为管理员?1.是 2.否：\e[0m\c"
        read isadmin
        case $isadmin in
            1)
            steam_group_admins="true"
            ;;
            2)
            steam_group_admins="false"
            ;;
        esac
        ;;
        7)
        echo -e "\e[92m服务器是否设为仅Steam群组成员可进？1.是 2.否：\e[0m\c"
        read isonly
        case $isonly in
            1)
            steam_group_only="true"
            ;;
            2)
            steam_group_only="false"
            ;;
        esac
        ;;
        8)
        echo -e "\e[92m是否开启无人暂停？1.是 2.否：\e[0m\c"
        read if
        case $if in
            1)
            pause_when_empty="true"
            ;;
            2)
            pause_when_empty="false"
            ;;
        esac
        ;;
        9)
        echo -e "\e[92m是否开启投票？1.是 2.否：\e[0m\c"
        read if
        case $if in
            1)
            vote_enabled="true"
            ;;
            2)
            vote_enabled="false"
            ;;
        esac
        ;;
        10)
        echo -e "\e[92m是否开启PVP？1.是 2.否：\e[0m\c"
        read if
        case $if in
            1)
            pvp="true"
            ;;
            2)
            pvp="false"
            ;;
        esac
        ;;
        11)
        echo -e "\e[92m请输入预留的服务器玩家位置个数(设置后请在后续步骤添加白名单，否则无效):\e[0m\c"
        read whitelist_slots
        ;;
        12)
        echo -e "\e[92m请输入主世界IP：\e[0m\c"
        read master_ip
        ;;
        13)
        echo -e "\e[92m请输入房间密码：\e[0m\c"
        read cluster_password
        ;;
        14)
        echo -e "\e[92m请输入最大玩家人数：\e[0m\c"
        read max_player
        ;;
    esac
    done
}
# 写入cluster.ini
writecluster(){
    echo "[STEAM]
steam_group_admins = $steam_group_admins
steam_group_id = $steam_group_id
steam_group_only = $steam_group_only


[GAMEPLAY]
game_mode = $game_mode
max_players = $max_player
pvp = $pvp
pause_when_empty = $pause_when_empty
vote_enabled = $vote_enabled


[NETWORK]
lan_only_cluster = false
cluster_intention = $cluster_intention
cluster_description = $cluster_description
cluster_name = $cluster_name
offline_cluster = false
cluster_password = $cluster_password
whitelist_slots = $whitelist_slots
autosaver_enabled = true
tick_rate = 15


[MISC]
max_snapshots = 6
console_enabled = true


[SHARD]
shard_enabled = true
bind_ip = 0.0.0.0
master_ip = $master_ip
master_port = 10888
cluster_key = Ariwori


" > ${clusterdir}/$cluster/cluster.ini
    clear
    info "服务器设置已写入存档【$cluster】！"
}
# 列出已有的有效存档
list_cluster(){
    echo ${Separator}
    info "已有存档："
    if [[ $(ls -l ${clusterdir}|grep ^d|awk '{print $9}') != "" ]]; then
        index=1
        for clustername in $(ls -l ${clusterdir}|grep ^d|awk '{print $9}')
        do
            if [[ -f ${clusterdir}/$clustername/cluster.ini ]]; then
                word_name=$(cat ${clusterdir}/$clustername/cluster.ini|grep "^cluster_name="| cut -d"=" -f2)
            else
                word_name="存档无效"
            fi
            echo -e "${Green_font_prefix}$index.${Font_color_suffix} $clustername $word_name"
            index=$[$index + 1]
        done
    else
        tip "没有存档！"
    fi
}

# 写入脚本配置文件
create_dstconf(){
    cat > ${configdir}/dstscript.json<<-EOF
{
    "configfiles_version":"2.0.0",
    "firstuse":true,
    "gamebranch":""
}
EOF
}
# 写入世界设置默认选项
create_wordconf(){
    cat > ${configdir}/word_level.json<<-EOF
[
    {"num":75},
    {"shard":"forest","name":"autumn","value":"default","type":"environment","cn_str":"秋天",
        "options":[
            {"num":7},
            {"value":"noseason","cn_str":"无"},
            {"value":"veryshortseason","cn_str":"很短"},
            {"value":"shortseason","cn_str":"短"},
            {"value":"longseason","cn_str":"长"},
            {"value":"verylongseason","cn_str":"很长"},
            {"value":"random","cn_str":"随机"},
            {"value":"default","cn_str":"默认"}
        ]
    },
    {"shard":"all","name":"boons","value":"default","type":"environment","cn_str":"前辈遗迹",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"branching","value":"default","type":"environment","cn_str":"岔路地形",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"day","value":"default","type":"environment","cn_str":"昼夜长短",
        "options":[
            {"num":9},
            {"value":"longday","cn_str":"长白昼"},
            {"value":"longdusk","cn_str":"长黄昏"},
            {"value":"longnight","cn_str":"长夜晚"},
            {"value":"noday","cn_str":"无白昼"},
            {"value":"nodusk","cn_str":"无黄昏"},
            {"value":"nonight","cn_str":"无夜晚"},
            {"value":"onlyday","cn_str":"仅白昼"},
            {"value":"onlydusk","cn_str":"仅黄昏"},
            {"value":"onlynight","cn_str":"仅夜晚"}
        ]
    },
    {"shard":"all","name":"disease_delay","value":"default","type":"environment","cn_str":"作物患病",
        "options":[
            {"num":5},
            {"value":"default","cn_str":"默认"},
            {"value":"none","cn_str":"无"},
            {"value":"random","cn_str":"随机"},
            {"value":"long","cn_str":"慢"},
            {"value":"short","cn_str":"快"}
        ]
    },
    {"shard":"forest","name":"frograin","value":"default","type":"environment","cn_str":"青蛙雨",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"lightning","value":"default","type":"environment","cn_str":"闪电",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"loop","value":"default","type":"environment","cn_str":"环状地形",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"petrification","value":"default","type":"environment","cn_str":"石化速率",
        "options":[
            {"num":5},
            {"value":"default","cn_str":"默认"},
            {"value":"none","cn_str":"无"},
            {"value":"few","cn_str":"慢"},
            {"value":"many","cn_str":"快"},
            {"value":"max","cn_str":"极快"}
        ]
    },
    {"shard":"all","name":"regrowth","value":"default","type":"environment","cn_str":"资源再生",
        "options":[
            {"num":5},
            {"value":"veryslow","cn_str":"极慢"},
            {"value":"slow","cn_str":"慢"},
            {"value":"default","cn_str":"默认"},
            {"value":"fast","cn_str":"快"},
            {"value":"veryfast","cn_str":"极快"}
        ]
    },
    {"shard":"forest","name":"season_start","value":"default","type":"environment","cn_str":"初始季节",
        "options":[
            {"num":7},
            {"value":"default","cn_str":"秋季"},
            {"value":"winter","cn_str":"冬季"},
            {"value":"spring","cn_str":"春季"},
            {"value":"summer","cn_str":"夏季"},
            {"value":"autumnorspring","cn_str":"秋或春"},
            {"value":"winterorsummer","cn_str":"冬或夏"},
            {"value":"random","cn_str":"随机"}
        ]
    },
    {"shard":"forest","name":"specialevent","value":"default","type":"environment","cn_str":"节日活动",
        "options":[
            {"num":6},
            {"value":"none","cn_str":"无"},
            {"value":"default","cn_str":"自动"},
            {"value":"hallowed_nights","cn_str":"万圣夜"},
            {"value":"winters_feast","cn_str":"冬季盛宴"},
            {"value":"winters_feast","cn_str":"鸡年活动"},
            {"value":"winters_feast","cn_str":"狗年活动"}
        ]
    },
    {"shard":"forest","name":"spring","value":"default","type":"environment","cn_str":"春天",
        "options":[
            {"num":7},
            {"value":"noseason","cn_str":"无"},
            {"value":"veryshortseason","cn_str":"很短"},
            {"value":"shortseason","cn_str":"短"},
            {"value":"longseason","cn_str":"长"},
            {"value":"verylongseason","cn_str":"很长"},
            {"value":"random","cn_str":"随机"},
            {"value":"default","cn_str":"默认"}
        ]
    },
    {"shard":"all","name":"start_location","value":"default","type":"environment","cn_str":"初始环境",
        "options":[
            {"num":3},
            {"value":"default","cn_str":"默认"},
            {"value":"plus","cn_str":"三箱"},
            {"value":"darkness","cn_str":"永夜"}
        ]
    },
    {"shard":"forest","name":"summer","value":"default","type":"environment","cn_str":"夏天",
        "options":[
            {"num":7},
            {"value":"noseason","cn_str":"无"},
            {"value":"veryshortseason","cn_str":"很短"},
            {"value":"shortseason","cn_str":"短"},
            {"value":"longseason","cn_str":"长"},
            {"value":"verylongseason","cn_str":"很长"},
            {"value":"random","cn_str":"随机"},
            {"value":"default","cn_str":"默认"}
        ]
    },
    {"shard":"all","name":"touchstone","value":"default","type":"environment","cn_str":"猪头祭坛",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"weather","value":"default","type":"environment","cn_str":"雨",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"wildfires","value":"default","type":"environment","cn_str":"自燃",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"winter","value":"default","type":"environment","cn_str":"冬天",
        "options":[
            {"num":7},
            {"value":"noseason","cn_str":"无"},
            {"value":"veryshortseason","cn_str":"很短"},
            {"value":"shortseason","cn_str":"短"},
            {"value":"longseason","cn_str":"长"},
            {"value":"verylongseason","cn_str":"很长"},
            {"value":"random","cn_str":"随机"},
            {"value":"default","cn_str":"默认"}
        ]
    },
    {"shard":"all","name":"world_size","value":"default","type":"environment","cn_str":"地图大小",
        "world_size_options":[
            {"num":4},
            {"value":"small","cn_str":"小型"},
            {"value":"medium","cn_str":"中等"},
            {"value":"default","cn_str":"大型"},
            {"value":"huge","cn_str":"巨型"}
        ]
    },
    {"shard":"all","name":"prefabswaps_start","value":"default","type":"environment","cn_str":"初始多样性",
        "prefabswaps_start":[
            {"num":3},
            {"value":"classic","cn_str":"经典"},
            {"value":"highlyrandom","cn_str":"高度随机"},
            {"value":"default","cn_str":"默认"}
        ]
    },
    {"shard":"all","name":"roads","value":"default","type":"environment","cn_str":"道路",
        "options":[
            {"num":2},
            {"value":"never","cn_str":"无"},
            {"value":"default","cn_str":"有"}
        ]
    },
    {"shard":"all","name":"task_set","value":"default","type":"environment","cn_str":"生物群落",
        "task_set_option":[
            {"num":3},
            {"value":"classic","cn_str":"没有巨人"},
            {"value":"default","cn_str":"联机"},
            {"value":"cave","cn_str":"洞穴选这个"}
        ]
    },
    {"shard":"all","name":"berrybush","value":"default","type":"food","cn_str":"浆果丛",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"cactus","value":"default","type":"food","cn_str":"仙人掌",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"carrot","value":"default","type":"food","cn_str":"胡萝卜",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"mushroom","value":"default","type":"food","cn_str":"蘑菇",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"angrybees","value":"default","type":"animal","cn_str":"杀人蜂",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"beefalo","value":"default","type":"animal","cn_str":"皮费罗牛",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"bees","value":"default","type":"animal","cn_str":"蜜蜂",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"birds","value":"default","type":"animal","cn_str":"鸟",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"butterfly","value":"default","type":"animal","cn_str":"蝴蝶",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"buzzard","value":"default","type":"animal","cn_str":"秃鹫",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"catcoon","value":"default","type":"animal","cn_str":"浣猫",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"hunt","value":"default","type":"animal","cn_str":"狼/羊/象",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"lightninggoat","value":"default","type":"animal","cn_str":"电羊",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"moles","value":"default","type":"animal","cn_str":"鼹鼠",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"penguins","value":"default","type":"animal","cn_str":"企鹅",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"perd","value":"default","type":"animal","cn_str":"火鸡",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"pigs","value":"default","type":"animal","cn_str":"猪人",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"rabbits","value":"default","type":"animal","cn_str":"兔子",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"tallbirds","value":"default","type":"animal","cn_str":"高脚鸟",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"beefaloheat","value":"default","type":"animal","cn_str":"牛发情频率",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"antliontribute","value":"default","type":"monster","cn_str":"蚁狮事件",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"bearger","value":"rare","type":"monster","cn_str":"熊",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"chess","value":"default","type":"monster","cn_str":"齿轮怪",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"deciduousmonster","value":"default","type":"monster","cn_str":"桦树精",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"deerclops","value":"default","type":"monster","cn_str":"独眼巨鹿",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"dragonfly","value":"default","type":"monster","cn_str":"龙蝇",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"goosemoose","value":"default","type":"monster","cn_str":"鹿角鹅",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"houndmound","value":"default","type":"monster","cn_str":"猎犬丘",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"hounds","value":"default","type":"monster","cn_str":"猎犬袭击",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"krampus","value":"default","type":"monster","cn_str":"坎普斯",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"liefs","value":"default","type":"monster","cn_str":"树精",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"lureplants","value":"default","type":"monster","cn_str":"食人花",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"merm","value":"default","type":"monster","cn_str":"鱼人",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"spiders","value":"default","type":"monster","cn_str":"蜘蛛",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"all","name":"tentacles","value":"default","type":"monster","cn_str":"触手怪",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"forest","name":"walrus","value":"default","type":"monster","cn_str":"海象",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"cavelight","value":"default","type":"environment","cn_str":"洞穴光照",
        "cavelight_options":[
            {"num":5},
            {"value":"veryslow","cn_str":"极慢"},
            {"value":"slow","cn_str":"慢"},
            {"value":"default","cn_str":"默认"},
            {"value":"fast","cn_str":"快"},
            {"value":"veryfast","cn_str":"极快"}
        ]
    },
    {"shard":"caves","name":"earthquakes","value":"default","type":"environment","cn_str":"地震频率",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"wormlights","value":"default","type":"environment","cn_str":"发光浆果",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"banana","value":"default","type":"food","cn_str":"香蕉",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"lichen","value":"default","type":"food","cn_str":"苔藓",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"bunnymen","value":"default","type":"animal","cn_str":"兔人",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"cave_ponds","value":"default","type":"animal","cn_str":"洞穴池塘",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"monkey","value":"default","type":"animal","cn_str":"猴子",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"rocky","value":"default","type":"animal","cn_str":"石虾",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"slurper","value":"default","type":"animal","cn_str":"啜食者",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"slurtles","value":"default","type":"animal","cn_str":"蜗牛",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"bats","value":"default","type":"monster","cn_str":"蝙蝠",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"cave_spiders","value":"default","type":"monster","cn_str":"洞穴蜘蛛",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"fissure","value":"default","type":"monster","cn_str":"影怪裂缝",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"wormattacks","value":"default","type":"monster","cn_str":"蠕虫袭击",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    },
    {"shard":"caves","name":"worms","value":"default","type":"monster","cn_str":"蠕虫",
        "options":[
            {"num":5},
            {"value":"never","cn_str":"无"},
            {"value":"rare","cn_str":"较少"},
            {"value":"default","cn_str":"默认"},
            {"value":"often","cn_str":"较多"},
            {"value":"always","cn_str":"大量"}
        ]
    }
]
EOF
}
# 更新游戏服务器
Update_DST(){
    appmanifestfile=$(find "${serverfiles}" -type f -name "appmanifest_343050.acf")
    currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)
    cd "${steamcmddir}" || exit
    availablebuild=$(./steamcmd.sh +login "anonymous" +app_info_update 1 +app_info_print 343050 +app_info_print 343050 +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
    if [ "${currentbuild}" != "${availablebuild}" ]; then
        info "更新可用！即将执行更新..."
        install_dst
    else
        tip "无可用更新！"
    fi
}
# 安装游戏服务器
Install_DST(){
    check_steamcmd
    install_dst
    fix_steamcmd
    fix_dst
}
# 修复SteamCMD [S_API FAIL] SteamAPI_Init() failed;
fix_steamcmd(){
    mkdir -pv "${HOME}/.steam/sdk32"
    cp -v "${steamcmddir}/linux32/steamclient.so" "${HOME}/.steam/sdk32/steamclient.so"
}
# 修复CentOS依赖库
fix_dst(){
    if [ ${release} == "centos" ] && [ ! -f "${serverfiles}/bin/lib32/libcurl-gnutls.so.4" ]; then
        ln -s "/usr/lib/libcurl.so.4" "${serverfiles}/bin/lib32/libcurl-gnutls.so.4"
    fi
}
# 游戏服务端
install_dst(){
    if [ ! -d "${serverfiles}" ]; then
        mkdir -p ${serverfiles}
    fi
    cd "${steamcmddir}" || exit
    branch=$(jq '.gamebranch' ${configdir}/dstscript.json)
    ./steamcmd.sh +login "anonymous" +force_install_dir "${serverfiles}" +app_update "343050" ${branch} +quit
}
# SteamCMD
check_steamcmd(){
    if [ ! -d "${steamcmddir}" ]; then
        mkdir -pv "${steamcmddir}"
    fi
    if [ ! -f "${steamcmddir}/steamcmd.sh" ]; then
        wget "http://media.steampowered.com/client/steamcmd_linux.tar.gz"
        tar -xzvf steamcmd_linux.tar.gz -C ${steamcmddir}
        mv steamcmd_linux.tar.gz ${tmpdir}
        chmod +x "${steamcmddir}/steamcmd.sh"
    fi
}
# 修改dstscript.json的元素值
jsonmodify(){
    if [[ $(jq ".$1" ${configdir}/dstscript.json) != "$2" ]]; then
        linenum=$(grep -n "$1" ${configdir}/dstscript.json|cut -d ":" -f1)
        sed -i "$linenum{s/$1/$2/g}" ${configdir}/dstscript.json
    fi
}
# 暂时未做的功能
notyet(){
    tip "功能未完成，请等待作者更新！"
}
# 令牌配置
Config_token(){
    if [ ! -f ${configdir}/cluster_token.txt ]; then
        tip "================================="
        sleep 0.5
        tip "必须设置服务器令牌才能开启在线服务器"
        tip "如果你不知道怎么获取，可以访问我的博客获取帮助"
        tip "https://blog.wqlin.com/dstscript.html"
        write_token="true"
    else
        tip "服务器令牌已存在，是否更换新的令牌？[y/n]"
        read new_token
        if [[ ${new_token} = [Yy] ]]; then
            write_token="true"
        else
            write_token="false"
        fi
    fi
    if [ "${write_token}" == "true" ]; then
        info "请输入你的服务器令牌："
        read -r token
        echo "${token}" > "${configdir}/cluster_token.txt"
        if [ -f "${configdir}/cluster_token.txt" ]; then
            info "令牌配置已更新！"
        fi
    else
        tip "令牌未更新，将继续使用久令牌！"
    fi
    unset write_token
}
# 令牌检查
check_token(){
    if [ ! -f ${configdir}/cluster_token.txt ]; then
        error "令牌不可用，请配置令牌！"
        mysleep
        Main
    fi
}
# 服务器开启命令
command_start_dst(){
    tmux new-session -s "DST_$Shard" -d "$DST_bin_cmd -cluster $cluster -shard $Shard"
}
# 开启服务器
Start_DST(){
    list_cluster
    info "请选择你要开启的存档编号："
    read index
    cluster=$(ls -l ${clusterdir}|grep ^d|awk '{print $9}'|head -n $index|tail -n 1)
    cp ${configdir}/cluster_token.txt ${clusterdir}/${cluster}
    cd $serverfiles/bin
    for Shard in $(ls -l ${clusterdir}/${cluster}|grep ^d|awk '{print $9}'); do
        command_start_dst
    done
}
# 关闭服务器(暂时使用粗暴方法)
Stop_DST(){
    tmux list-sessions | awk 'BEGIN{FS=":"}{print $1}' | xargs -n 1 tmux kill-session -t
}
# 主菜单
Main(){
    while(true); do
        sleep 1
        clear
        separate
        echo -e "  DST Dedicated Server 一键管理脚本 ${Red_font_prefix}[v${version}]${Font_color_suffix}"
        echo -e "  -- Ariwori | blog.wqlin.com/dstscript.html --"
        separate
        echo -e "  ${Green_font_prefix}1.${Font_color_suffix} 安装游戏服务端        ${Green_font_prefix}2.${Font_color_suffix} 更新游戏服务端"
        separate
        echo -e "  ${Green_font_prefix}3.${Font_color_suffix} 查看具体世界设置      ${Green_font_prefix}4.${Font_color_suffix} 显示当前世界详情"
        separate
        echo -e "  ${Green_font_prefix}5.${Font_color_suffix} 存档管理              ${Green_font_prefix}6.${Font_color_suffix} 配置令牌"
        echo -e "  ${Green_font_prefix}7.${Font_color_suffix} 启停MODS              ${Green_font_prefix}8.${Font_color_suffix} 管理特殊名单"
        separate
        echo -e "  ${Green_font_prefix}9.${Font_color_suffix} 启动游戏服务器       ${Green_font_prefix}10.${Font_color_suffix} 关闭游戏服务器"
        echo -e " ${Green_font_prefix}11.${Font_color_suffix} 重启游戏服务器       ${Green_font_prefix}12.${Font_color_suffix} 测试游戏服务器"
        echo -e " ${Green_font_prefix}13.${Font_color_suffix} 跳转到游戏后台"
        separate
        echo -e " ${Green_font_prefix}14.${Font_color_suffix} 更多功能             ${Green_font_prefix}15.${Font_color_suffix} 升级脚本"
        separate
        echo && stty erase '^H' && read -p "请输入数字 [1-15]：" num
        case "$num" in
            1)
            Install_DST
            ;;
            2)
            Update_DST
            ;;
            3)
            Show_word_settings
            ;;
            4)
            Show_word_detail
            ;;
            5)
            Cluster_manager
            ;;
            6)
            Config_token
            ;;
            7)
            Mods_settings
            ;;
            8)
            Special_list_manager
            ;;
            9)
            Start_DST
            ;;
            10)
            Stop_DST
            ;;
            11)
            Restart_DST
            ;;
            12)
            Debug_DST
            ;;
            13)
            DST_console
            ;;
            14)
            More_functions
            ;;
            15)
            Update_Shell
            ;;
            *)
            error "请输入正确的数字 [1-15]"
            ;;
        esac
    done
}
check_sys
check_files
Main

