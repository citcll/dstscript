#!/bin/bash
#===============================================================================
#    System Required: Ubuntu12+/Debian7+
#    Description: Install and manager the Don't Starve Together Dedicated Server
#    Version: 2.0.0 2018-06-01 23:35:46
#    Author: Ariwori
#    Blog: https://blog.wqlin.com/dstscript.html
#===============================================================================
# 变量
fileversion="2.0.0"
rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
selfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
dstscriptdir="${rootdir}/dstscript"
steamcmddir="${rootdir}/steamcmd"
serverfiles="${rootdir}/dstserver"
tmpdir="${dstscriptdir}/tmp"
luadir="${dstscriptdir}/lua"
configdir="${dstscriptdir}/config"
logdir="${dstscriptdir}/log"
clusterdir="${rootdir}/.klei/DoNotStarveTogether"
DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer"
update_address="https://raw.githubusercontent.com/ariwori/ariwori/master/dst"
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"
Separator="————————————————————————"
separate(){ echo "${Separator}${Separator}"; }
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
    configmodify firstuse false
}
# 脚本更新
Update_file(){
    if [! -f ${rootdir}/$1 ]; then
        cur_ver=$(grep "^fileversion=" ${rootdir}/$1|cut -d '"' -f2)
    else
        cur_ver=000
    fi
    info "当前 $1 版本为 [ ${cur_ver} ]，开始检测最新版本..."
    new_ver=$(wget --no-check-certificate -qO- ${update_address}/$1 |cut -d '"' -f2)
    [[ -z ${new_ver} ]] && tip "$1 检测最新版本失败 !" && new_ver=$cur_ver
    if [[ ${new_ver} != ${cur_ver} ]]; then
        info "$1 发现新版本[ ${new_ver} ]，更新中..."
        wget ${update_address}/$1 -O ${rootdir}/$1
        info "$1 已更新为最新版本[ ${new_ver} ] !"
        if [[ $1 == "dst.sh" ]]; then chmod +x dst.sh; fi 
    else
        info "$1 当前已是最新版本[ ${new_ver} ] !"
    fi
}
# 脚本更新
Update_Shell(){
    Update_file dst.sh
    check_script_files
}
# first run
first_run_check(){
    if [[ $(configget firstuse) == "true" ]; then
        info "首次使用脚本，安装必要依赖及软件..."
        Install_dependency;
        Install_DST
        configmodify firstuse false
    fi
}
# 检查脚本文件
check_script_files(){
    check_dir
    if [[ $selfname == "dst.sh" ]]; then rm -rf $selfname; Update_file dst.sh; fi
    filelist=("config/dstscript.conf" "config/wordlevel.conf" "lua/modconf.lua")
    for file in $filelist; do
        if [[ ! -f $file ]]; then Update_file $file; fi
    done
}
# 目录
check_dir(){
    dirlist=("${configdir}" "${tmpdir}" "${luadir}" "${logdir}" "${clusterdir}")
    for dir in $dirlist; do
        if [[ ! -d $dir ]]; then mkdir -p ${dir}; fi
    done
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
    cd "${steamcmddir}" || exit 1
    ./steamcmd.sh +login "anonymous" +force_install_dir "${serverfiles}" +app_update "343050" +quit
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
# 获取dstscript.conf的值
configget(){
    grep "^$1" ${configdir}/dstscript.conf)|cut -d "=" -f2
}
# 修改dstscript.conf的值
configmodify(){
    if [[  $(configget $1) != "$2" ]]; then
        linenum=$(grep -n "$1" ${configdir}/dstscript.conf|cut -d ":" -f1)
        sed -i "$linenum{s/$(configget $1)/$2/g}" ${configdir}/dstscript.conf
    fi
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
    settings_num=$(jq '.[0].num' ${configdir}/word_level.conf)
    while(true); do
        separate
        echo -e "          ${Yellow_font_prefix}$word_type 世界配置${Font_color_suffix}"
        separate
        for index in {1..$settings_num}; do
            type=$(jq ".[$index].type" ${configdir}/word_level.conf)
            shard=$(jq ".[$index].shard" ${configdir}/word_level.conf)
            name=$(jq ".[$index].cn_str" ${configdir}/word_level.conf)
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
        name=$(jq ".[$num].cn_str" ${configdir}/word_level.conf)
        echo "更改${Yellow_font_prefix}$name${Font_color_suffix}为："
        opnum=$(jq ".[$num].options[0].num" ${configdir}/word_level.conf)
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
        echo -e "  ${Green_font_prefix}1.${Font_color_suffix} 更新游戏服务端        ${Green_font_prefix}2.${Font_color_suffix} 更新MODS"
        separate
        echo -e "  ${Green_font_prefix}3.${Font_color_suffix} 显示当前世界详情      ${Green_font_prefix}4.${Font_color_suffix} 控制台"
        separate
        echo -e "  ${Green_font_prefix}5.${Font_color_suffix} 存档管理              ${Green_font_prefix}6.${Font_color_suffix} 配置令牌"
        echo -e "  ${Green_font_prefix}7.${Font_color_suffix} 启停MODS              ${Green_font_prefix}8.${Font_color_suffix} 管理特殊名单"
        separate
        echo -e "  ${Green_font_prefix}9.${Font_color_suffix} 启动游戏服务器       ${Green_font_prefix}10.${Font_color_suffix} 关闭游戏服务器"
        echo -e " ${Green_font_prefix}11.${Font_color_suffix} 重启游戏服务器       ${Green_font_prefix}12.${Font_color_suffix} 测试游戏服务器"
        separate
        echo -e " ${Green_font_prefix}13.${Font_color_suffix} 更多功能             ${Green_font_prefix}14.${Font_color_suffix} 升级脚本"
        separate
        echo && stty erase '^H' && read -p "请输入数字 [1-15]：" num
        case "$num" in
            1)
            Update_DST
            ;;
            2)
            Update_MODS
            ;;
            3)
            View_word_detail
            ;;
            4)
            Console
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
            More_functions
            ;;
            14)
            Update_Shell
            ;;
            *)
            error "请输入正确的数字 [1-15]"
            ;;
        esac
    done
}
check_sys
check_script_files
first_run_check
Main

