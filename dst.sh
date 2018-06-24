#!/bin/bash
#===============================================================================
#    System Required: Ubuntu12+/Debian7+
#    Description: Install and manager the Don't Starve Together Dedicated Server
#    Author: Ariwori
#    Blog: https://blog.wqlin.com/dstscript.html
#===============================================================================
# 变量
rootdir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
selfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
dstscriptdir="${rootdir}/dstscript"
steamcmddir="${rootdir}/steamcmd"
serverfiles="${rootdir}/dstserver"
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
info(){ echo -e "${Info} $1"|tee -a ${dstscriptdir}/run.log; }
tip(){ echo -e "${Tip} $1"|tee -a ${dstscriptdir}/run.log; }
error(){ echo -e "${Error} $1"|tee -a ${dstscriptdir}/run.log; }
# 第一次运行
first_run_check(){
    if [ ! -f ${dstscriptdir}/version.json ]; then
        info "检测到你是首次运行脚本，需要进行必要的配置，大概一个小时 ..."
        check_sys
        mkdstdir
        Install_Dependency
        info "拉取必要配置文件 ..."
        update_file;
        info "文件拉取完毕！继续 ..."
        Install_Steamcmd
        info "安装游戏服务端 ..."
        Install_Game
        fix_steamcmd
        info "首次运行配置完毕，如果无任何异常，你就可以创建新的世界了。"
    fi
}
# 拉取/更新文件
update_file(){
    filelist=$(curl -s ${update_address}/filelist.txt)
    for file in $filelist; do
        cur_ver=$(jq ".\"$file\"" ${dstscriptdir}/version.json|cut -d '"' -f2)
        [[ -z $cur_ver ]] && cur_ver=000
        info "当前 $file 版本为 [ ${cur_ver} ]，开始检测最新版本..."
        new_ver=$(wget --no-check-certificate -qO- ${update_address}/dstscript/version.json| jq ".\"$file\""| cut -d '"' -f2)
        [[ -z ${new_ver} ]] && tip "$file 检测最新版本失败 !" && new_ver=$cur_ver
        if [[ ${new_ver} != ${cur_ver} ]]; then
            info "$file 发现新版本[ ${new_ver} ]，更新中..."
            if [[ $file == "dst.sh" ]]; then
                wget ${update_address}/$file -O ${rootdir}/$file
                chmod +x ${rootdir}/$file
            else
                wget ${update_address}/dstscript/$file -O ${dstscriptdir}/$file
            fi
            info "$file 已更新为最新版本[ ${new_ver} ] !"
        else
            info "$file 当前已是最新版本[ ${new_ver} ] !"
        fi
    done
}
# 创建文件夹
mkdstdir(){
    dirlist="${dstscriptdir} ${steamcmddir} ${serverfiles} ${clusterdir}"
    for dir in $dirlist; do mkdir -pv $dir; done
}
# 检查当前系统信息
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
    if [[ $release != "ubuntu" && $release != "debian" ]]; then
        error "很遗憾！本脚本暂时只支持Debian7+和Ubuntu12+的系统！" && exit 1
    fi
    bit=`uname -m`
}
# 安装依赖库和必要软件
Install_Dependency(){
    info "安装DST所需依赖库 ..."
    if [[ ${bit} = "x86_64" ]]; then
		sudo dpkg --add-architecture i386;
        sudo apt update;
        sudo apt install -y lib32gcc1 libstdc++6 libstdc++6:i386 libcurl4-gnutls-dev:i386
	else
	    sudo apt install -y libstdc++6 libcurl4-gnutls-dev
	fi
    info "安装脚本所需软件 ..."
    sudo apt install -y jq lua5.2 tmux nginx
}
# Install steamcmd
Install_Steamcmd(){
    wget "http://media.steampowered.com/client/steamcmd_linux.tar.gz" 
    tar -xzvf steamcmd_linux.tar.gz -C ${steamcmddir}
    chmod +x "${steamcmddir}/steamcmd.sh"
    rm steamcmd_linux.tar.gz
}
# Install DST Dedicated Server
Install_Game(){
    cd "${steamcmddir}" || exit 1
    ./steamcmd.sh +login "anonymous" +force_install_dir "${serverfiles}" +app_update "343050" validate +quit
}
# 修复SteamCMD [S_API FAIL] SteamAPI_Init() failed;
fix_steamcmd(){
    info "修复Steamcmd可能存在的依赖问题 ..."
    mkdir -pv "${HOME}/.steam/sdk32"
    cp -v "${steamcmddir}/linux32/steamclient.so" "${HOME}/.steam/sdk32/steamclient.so"
}
first_run_check
##########################################################################
# 更新游戏服务端
Update_DST(){
    appmanifestfile=$(find "${serverfiles}" -type f -name "appmanifest_343050.acf")
    currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)
    cd "${steamcmddir}" || exit
    availablebuild=$(./steamcmd.sh +login "anonymous" +app_info_update 1 +app_info_print 343050 +app_info_print 343050 +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
    if [ "${currentbuild}" != "${availablebuild}" ]; then
        info "更新可用(${currentbuild}===>${availablebuild}！即将执行更新..."
        install_dst
    else
        tip "无可用更新！"
    fi
}
# 存档管理
Cluster_manager(){
    echo -e "${Separator}
  DST Dedicated Server 存档管理面板
${Separator}
  ${Green_font_prefix}1.${Font_color_suffix} 新建存档      ${Green_font_prefix}2.${Font_color_suffix} 更改已有存档      ${Green_font_prefix}3.${Font_color_suffix} 删除已有存档
${Separator}"
    echo && stty erase '^H' && read -p "请输入数字 [1-3]：(输入 0 返回主菜单)" num
    case "$num" in
        0)
        Main
        ;;
        1)
        new_cluster
        ;;
        2)
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
    [[ -z ${cluster} ]] && error "输入无效！" && Cluster_manager
    mkdir -p ${clusterdir}/${cluster}
    set_cluster
    set_serverini
}
# Cluster.ini
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
    master_ip="127.0.0.1"
    while(true); do
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
Main