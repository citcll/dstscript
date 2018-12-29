#!/bin/bash
#===============================================================================
#    System Required: Ubuntu12+/Debian7+/CentOS7+
#    Description: Install and manager the Don't Starve Together Dedicated Server
#    Author: Ariwori
#    Blog: https://wqlin.com
#===============================================================================
script_ver="2.3.1.3.8.1"
dst_conf_dirname="DoNotStarveTogether"
dst_conf_basedir="${HOME}/.klei"
dst_base_dir="${dst_conf_basedir}/${dst_conf_dirname}"
dst_server_dir="${HOME}/DSTServer"
dst_bin_cmd="./dontstarve_dedicated_server_nullrenderer"
data_dir="${HOME}/.dstscript"
dst_token_file="${data_dir}/clustertoken.txt"
server_conf_file="${data_dir}/server.conf"
dst_cluster_file="${data_dir}/clusterdata.txt"
log_arr_str="${data_dir}/logarr.txt"
feedback_link="https://blog.wqlin.com/dstscript.html"
my_api_link="https://api.wqlin.com/dst"
update_link="${my_api_link}/dstscript"
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[提示]${Font_color_suffix}"
info(){
    echo -e "${Info} $1"
}
tip(){
    echo -e "${Tip} $1"
}
error(){
    echo -e "${Error} $1"
}
# Main menu
Menu(){
    while (true)
    do
        echo -e "\e[33m==============欢迎使用饥荒联机版独立服务器脚本[Linux-Steam](${script_ver})==============\e[0m"
        echo -e "\e[33m作者：Ariwori        Bug反馈：${feedback_link}\e[0m"
        echo -e "\e[33m本脚本一切权利归作者所有。未经许可禁止使用本脚本进行任何的商业活动！\e[0m"
        echo -e "\e[31m游戏服务端安装目录：${dst_server_dir} (Version: $(cat ${dst_server_dir}/version.txt))\e[33m【${dst_need_update_str}】\e[0m"
        echo -e "\e[35m公告：$(cat "${data_dir}/announce.txt" | grep -v script_ver)\e[0m"
        echo -e "\e[92m[1]启动服务器           [2]关闭服务器           [3]重启服务器\e[0m"
        echo -e "\e[92m[4]修改房间设置         [5]添加或移除MOD        [6]设置管理员和黑名单\e[0m"
        echo -e "\e[92m[7]游戏服务端控制台     [8]自动更新及异常维护   [9]退出本脚本\e[0m"
        echo -e "\e[92m[10]删除存档            [11]更新游戏服务端      [12]更新MOD\e[0m"
        Simple_server_status
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m（如需中断任何操作请直接按Ctrl+C）请输入命令代号：\e[0m\c"
        read cmd
        case ${cmd} in
            1)
            Start_server
            ;;
            2)
            Close_server
            Exit_auto_update
            ;;
            3)
            Reboot_server
            ;;
            4)
            Change_cluster
            ;;
            5)
            MOD_manager
            ;;
            6)
            List_manager
            ;;
            7)
            Server_console
            ;;
            8)
            Auto_update
            ;;
            9)
            exit
            ;;
            10)
            Cluster_manager
            ;;
            11)
            Force_update
            ;;
            12)
            Update_MOD
            ;;
            *)
            error "输入有误！！！"
            ;;
        esac
    done
}
Change_cluster(){
    Get_current_cluster
    Set_cluster
}
Server_console(){
    Get_single_shard
    if tmux has-session -t DST_${shard} > /dev/null 2>&1
    then
        info "即将跳转${shard}世界后台。。。退出请按Ctrl + B松开再按D，否则服务器将停止运行！！！"
        sleep 3
        tmux attach-session -t DST_${shard}
    else
        tip "${shard}世界未开启或已异常退出！！！"
    fi
}
Get_shard_array(){
    Get_current_cluster
    [ $cluster != "无" ] && shardarray=$(ls -l $dst_base_dir/${cluster} | grep ^d | awk '{print $9}')
}
Get_single_shard(){
    Get_current_cluster
    [ $cluster != "无" ] && shard=$(ls -l $dst_base_dir/${cluster} | grep ^d | awk '{print $9}' | head -n 1)
}
Get_current_cluster(){
    [ -f ${server_conf_file} ] && cluster=$(cat ${server_conf_file} | grep "^cluster" | cut -d "=" -f2)
}
Get_server_status(){
    [ -f ${server_conf_file} ] && serveropen=$(grep "serveropen" ${server_conf_file} | cut -d "=" -f2)
}
MOD_manager(){
    Get_current_cluster
    Default_mod
    echo -e "\e[92m【存档：${cluster}】 你要 1.添加mod  2.删除mod：\e[0m\c"
    read mc
    case ${mc} in
        1)
        Listallmod
        Addmod;;
        2)
        Listusedmod
        Delmod;;
        *)
        break;;
    esac
    Removelastcomma
}
MOD_conf(){
    echo "fuc = \"${fuc}\"
modid = \"${moddir}\"
used = \"${used}\"" > "${data_dir}/modinfo.lua"
    if [[ -f "${dst_server_dir}/mods/${moddir}/modinfo.lua" ]]
    then
        cat "${dst_server_dir}/mods/${moddir}/modinfo.lua" >> "${data_dir}/modinfo.lua"
    else
        needdownloadid=$(echo ${moddir} | cut -d "-" -f2)
        echo "ServerModSetup(\"$needdownloadid\")" > ${dst_server_dir}/mods/dedicated_server_mods_setup.lua
        if [[ ${fuc} == "writein" ]]
        then
            Download_MOD
        fi
        if [[ -f "${dst_server_dir}/mods/${moddir}/modinfo.lua" ]]
        then
            cat "${dst_server_dir}/mods/${moddir}/modinfo.lua" >> "${data_dir}/modinfo.lua"
        else
            echo "name = \"UNKNOWN\"" >> "${data_dir}/modinfo.lua"
        fi
    fi
    cd ${data_dir}
    lua ${data_dir}/modconf.lua > /dev/null 2>&1
    cd ${HOME}
}
Listallmod(){
    if [ ! -f ${data_dir}/mods_setup.lua ]
    then
        touch ${data_dir}/mods_setup.lua
    fi
    rm -f ${data_dir}/modconflist.lua
    touch ${data_dir}/modconflist.lua
    Get_single_shard
    for moddir in $(ls -F "${dst_server_dir}/mods" | grep "/$" | cut -d '/' -f1)
    do
        if [ $(grep "${moddir}" -c "${dst_base_dir}/${cluster}/${shard}/modoverrides.lua") -gt 0 ]
        then
            used="true"
        else
            used="false"
        fi
        if [[ "${moddir}" != "" ]]
        then
            fuc="list"
            MOD_conf
        fi
    done
    grep -n "^" ${data_dir}/modconflist.lua
}
Listusedmod(){
    rm -f ${data_dir}/modconflist.lua
    touch ${data_dir}/modconflist.lua
    Get_single_shard
    for moddir in $(grep "^  \[" "${dst_base_dir}/${cluster}/${shard}/modoverrides.lua" | cut -d '"' -f2)
    do
        if [[ "${moddir}" != "" ]]
        then
            fuc="list"
            used="true"
            MOD_conf
        fi
    done
    grep -n "^" ${data_dir}/modconflist.lua
}
Addmod(){
    info "请从以上列表选择你要启用的MOD${Red_font_prefix}[编号]${Font_color_suffix}，不存在的直接输入MODID"
    info "具体配置已写入 modoverride.lua, shell下修改太麻烦，可打开配置文件手动修改"
    info "添加完毕要退出请输入数字 0 ！"
    while (true)
    do
        read modid
        if [[ "${modid}" == "0" ]]
        then
            info "添加完毕 ！"
            break
        else
            Addmodfunc
        fi
    done
    info "要修改具体参数配置请手动打开***更改："
    info "${dst_base_dir}/${cluster}/***/modoverrides.lua"
    sleep 3
    clear
}
Addmodtoshard(){
    Get_shard_array
    for shard in ${shardarray}
    do
        if [ -f ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua ]
        then
            if [[ $(grep "${moddir}" "${dst_base_dir}/${cluster}/${shard}/modoverrides.lua") > 0 ]]
            then
                info "${shard}世界该Mod(${moddir})已添加"
            else
                sed -i '1d' ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua
                cat ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua > ${data_dir}/modconftemp.txt
                echo "return {" > ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua
                cat ${data_dir}/modconfwrite.lua >> ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua
                cat ${data_dir}/modconftemp.txt >> ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua
                info "${shard}世界Mod(${moddir})添加完成"
            fi
        else
            tip "${shard} MOD配置文件未由脚本初始化，无法操作！如你已自行配置请忽略本提示！"
        fi
    done
}
Truemodid(){
    if [ ${modid} -lt 1000 ]
    then
        moddir=$(sed -n ${modid}p ${data_dir}/modconflist.lua | cut -d ':' -f2)
    else
        moddir="workshop-${modid}"
    fi
}
Addmodfunc(){
    Truemodid
    fuc="writein"
    MOD_conf
    Addmodtoshard
}
Delmodfromshard(){
    for shard in ${shardarray}
    do
        if [ -f ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua ]
        then
            if [[ $(grep "${moddir}" -c "${dst_base_dir}/${cluster}/${shard}/modoverrides.lua") > 0 ]]
            then
                grep -n "^  \[" "${dst_base_dir}/${cluster}/${shard}/modoverrides.lua" > ${data_dir}/modidlist.txt
                lastmodlinenum=$(cat ${data_dir}/modidlist.txt | tail -n 1 | cut -d ":" -f1)
                up=$(grep "${moddir}" "${data_dir}/modidlist.txt" | cut -d ":" -f1)
                if [ ${lastmodlinenum} -eq ${up} ]
                then
                    down=$(grep "^" -n ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua | tail -n 1 | cut -d ":" -f1)
                else
                    down=$(grep -A 1 "${moddir}" "${data_dir}/modidlist.txt" | tail -1 |cut -d ":" -f1)
                fi
                upnum=${up}
                downnum=$((${down} - 1))
                sed -i "${upnum},${downnum}d" "${dst_base_dir}/${cluster}/${shard}/modoverrides.lua"
                info "${shard}世界该Mod(${moddir})已停用！"
            else
                info "${shard}世界该Mod(${moddir})未启用！"
            fi
        else
            tip "${shard} MOD配置文件未由脚本初始化，无法操作！如你已自行配置请忽略本提示！"
        fi
    done
}
# 保证最后一个MOD配置结尾不含逗号
Removelastcomma(){
    for shard in ${shardarray}
    do
        if [ -f ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua ]
        then
            checklinenum=$(grep "^" -n ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua | tail -n 2 | head -n 1 | cut -d ":" -f1)
            sed -i "${checklinenum}s/,//g" ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua
        fi
    done
}
Delmod(){
    info "请从以上列表选择你要停用的MOD${Red_font_prefix}[编号]${Font_color_suffix},完毕请输数字 0 ！"
    while (true)
    do
        read modid
        if [[ "${modid}" == "0" ]]
        then
            info "MOD删除完毕！"
            break
        else
            Truemodid
            Delmodfromshard
        fi
    done
}
List_manager(){
    echo -e "\e[92m你要设置：1.管理员  2.黑名单  3.白名单 ? \e[0m\c"
    read list
    case ${list} in
        1)
        listfile="alist.txt"
        listname="管理员"
        ;;
        2)
        listfile="blist.txt"
        listname="黑名单"
        ;;
        3)
        listfile="wlist.txt"
        listname="白名单"
        ;;
        *)
        error "输入有误，请输入数字[1-3]"
        ;;
    esac
    echo -e "\e[92m你要：1.添加${listname} 2.移除${listname} ? \e[0m\c"
    read addordel
    case ${addordel} in
        1)
        Addlist
        ;;
        2)
        Dellist
        ;;
    esac
}
Addlist(){
    echo -e "\e[92m请输入你要添加的KLEIID（KU_XXXXXXX）：(添加完毕请输入数字 0 )\e[0m"
    while (true)
    do
        read kleiid
        if [[ "${kleiid}" == "0" ]]
        then
            info "添加完毕！"
            break
        else
            if [[ $(grep "${kleiid}" -c "${data_dir}/${listfile}") > 0 ]]
            then
                info "名单${kleiid}已经存在！"
            else
                echo "${kleiid}" >> ${data_dir}/${listfile}
                info "名单${kleiid}已添加！"
            fi
        fi
    done
}
Dellist()
{
    while (ture)
    do
        echo "=========================================================================="
        grep -n "KU" "${data_dir}/${listfile}"
        echo -e "\e[92m请输入你要移除的KLEIID${Red_font_prefix}[编号]${Font_color_suffix}，删除完毕请输入数字 0 \e[0m"
        read kleiid
        if [[ "${kleiid}" == "0" ]]
        then
            info "移除完毕！"
            break
        else
            sed -i "${kleid}d" ${dst_base_dir}/${listfile}
            info "名单已移除！"
        fi
    done
}
Cluster_manager(){
    cluster_str="删除"
    Choose_exit_cluster
    rm -rf ${dst_base_dir}/${cluster}
    info "存档 ${cluster} 已删除！"
}
Auto_update(){
    if tmux has-session -t Auto_update > /dev/null 2>&1
    then
        info "自动更新进程已在运行，即将跳转。。。退出请按Ctrl + B松开再按D！"
        tmux attach-session -t Auto_update
        sleep 1
    else
        tmux new-session -s Auto_update -d "bash $HOME/dstserver.sh au"
        info "自动更新已开启！即将跳转。。。退出请按Ctrl + B松开再按D!"
        sleep 1
        tmux attach-session -t Auto_update
    fi
}
Update_DST_Check(){
    # data from klei forums
    info "正在检查游戏服务端是否有更新 。。。 请稍后 。。。"
    currentbuild=$(cat ${dst_server_dir}/version.txt)
    availablebuild=$(curl -s "${my_api_link}/" | sed 's/[ \t]*$//g' | tr -cd [0-9])
    if [[ "${currentbuild}" != "${availablebuild}" && "${availablebuild}" != "" ]]
    then
        dst_need_update=true
        dst_need_update_str="需要更新"
    else
        dst_need_update=false
        dst_need_update_str="无需更新"
    fi
}
Force_update(){
    echo -e "\e[92m是否强制更新游戏服务端：1.是  2.否 ? \e[0m\c"
    read force
    case $force in
        1)
        Get_server_status
        cur_serveropen=${serveropen}
        Reboot_announce
        Close_server
        Install_Game
        if [[ ${cur_serveropen} == "true" ]]
        then
            Run_server
        fi
        ;;
        *)
        Update_DST
        ;;
    esac
}
Update_DST(){
    Get_server_status
    cur_serveropen=${serveropen}
    Update_DST_Check
    if [[ ${dst_need_update} == "true" ]]
    then
        info "更新可用(${currentbuild}===>${availablebuild})！即将执行更新..."
        Reboot_announce
        Close_server
        Install_Game
    else
        tip "无可用更新！当前版本（${availablebuild}）"
    fi
    if [[ ${cur_serveropen} == "true" && ${dst_need_update} == "true" ]]
    then
        Run_server
    fi
}
###################################################################
Reboot_server(){
    info "服务器重启中。。。请稍候。。。"
    Reboot_announce
    Close_server
    Run_server
}
exchangestatus(){
    if [ ! -f ${server_conf_file} ]
    then
        touch ${server_conf_file}
    fi
    if [ $(grep "serveropen" -c ${server_conf_file}) -eq 0 ]
    then
        echo "serveropen=$1" >> ${server_conf_file}
    else
        str=$(grep "serveropen" ${server_conf_file})
        sed -i "s/${str}/serveropen=$1/g" ${server_conf_file}
    fi
}
Run_server(){
    Get_current_cluster
    Get_shard_array
    exchangestatus true
    Default_mod
    Set_list
    Start_shard
    info "服务器开启中。。。请稍候。。。"
    sleep 10
    Start_check
}
Reboot_announce(){
    Get_shard_array
    for shard in ${shardarray}
    do
        if tmux has-session -t DST_${shard} > /dev/null 2>&1
        then
            tmux send-keys -t DST_${shard} "c_announce(\"${shard}世界服务器因改动或更新需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
        fi
        sleep 5
    done
}
Start_server(){
    info "本操作将会关闭已开启的服务器 ..."
    Close_server
    Exit_auto_update
    echo -e "\e[92m是否新建存档: [y|n] (默认: y): \e[0m\c"
    read yn
    [[ -z "${yn}" ]] && yn="y"
    new_cluster=""
    if [[ ${yn} == [Yy] ]]
    then
        echo -e "\e[92m请输入新建存档名称：（不要包含中文、符号和空格）\e[0m"
        read cluster
        if [ -d "${dst_base_dir}/${cluster}" ]
        then
            tip "${cluster}存档已存在！是否删除已有存档：1.是  2.否？ "
            read ifdel
            if [[ $ifdel == "2" ]]
            then
                rm -rf ${dst_base_dir}/${cluster}
            else
                rm -rf ${dst_base_dir}/${cluster}/cluster.ini
            fi
        fi
        mkdir -p ${dst_base_dir}/${cluster}
        Set_cluster
        Set_token
        new_cluster="true"
    else
        cluster_str="开启"
        Choose_exit_cluster
    fi
    echo "cluster=${cluster}" > ${server_conf_file}
    echo "shardarray=${shardarray}" >> ${server_conf_file}
    if [[ ${new_cluster} == "true" ]]
    then
        Addshard
    fi
    Import_cluster
    Run_server
}
Addshard(){
    while (true)
    do
        echo -e "\e[92m请选择要添加的世界：1.地面世界  2.洞穴世界  3.添加完成选我? \e[0m\c"
        read shardop
        case ${shardop} in
            1)
            Addforest;;
            2)
            Addcaves;;
            3)
            break;;
            *)
            error "输入有误，请输入[1-3]！！！";;
        esac
    done
}
Shardconfig(){
    info "已创建${shardtype}[$sharddir]，这是一个：1. 主世界   2. 附从世界？ "
    read ismaster
    if [ ${ismaster} -eq 1 ]
    then
        shardmaster="true"
		shardid=1
    else
        shardmaster="false"
		# 非主世界采用随机数，防止冲突
		shardid=$RANDOM
    fi
    cat > ${dst_base_dir}/${cluster}/$sharddir/server.ini<<-EOF
[NETWORK]
server_port = $[ 10997 + $idnum ]


[SHARD]
is_master = $shardmaster
name = ${shardname}${idnum}
id = $shardid


[ACCOUNT]
encode_user_path = true


[STEAM]
master_server_port = $[ 27016 + $idnum ]
authentication_port = $[ 8766 + $idnum ]
EOF
}
Getidnum(){
    idnum=$[ $(ls -l ${dst_base_dir}/${cluster} | grep ^d | awk '{print $9}' | grep -c ^) + 1 ]
}
Createsharddir(){
    sharddir="${shardname}${idnum}"
    mkdir -p ${dst_base_dir}/${cluster}/$sharddir
}
Addcaves(){
    shardtype="洞穴世界"
    shardname="Caves"
    Getidnum
    Createsharddir
    Shardconfig
    Set_world
}
Addforest(){
    shardtype="地面世界"
    shardname="Forest"
    Getidnum
    Createsharddir
    Shardconfig
    Set_world
}
# 导入存档
Import_cluster(){
    Default_mod
    if [ ! -f ${dst_base_dir}/${cluster}/cluster_token.txt ]
    then
        Set_token
    fi
}
Choose_exit_cluster(){
    echo -e "\e[92m已有存档：\e[0m"
    ls -l ${dst_base_dir} | awk '/^d/ {print $NF}' | grep -v downloadmod > /tmp/dirlist.txt
    index=1
    for dirlist in $(cat /tmp/dirlist.txt)
    do
        if [ -f ${dst_base_dir}/${dirlist}/cluster.ini ]
        then
            cluster_name_str=$(cat ${dst_base_dir}/${dirlist}/cluster.ini | grep ^cluster_name= | cut -d "=" -f2)
        fi
        if [[ $cluster_name_str == "" ]]
        then
            cluster_name_str="不完整或已损坏的存档"
        fi
        echo "${index}. ${dirlist}：${cluster_name_str}"
        let index++
    done
    echo -e "\e[92m请输入你要${cluster_str}的存档${Red_font_prefix}[编号]${Font_color_suffix}：\e[0m\c"
    read listnum
    cluster=$(cat /tmp/dirlist.txt | head -n ${listnum} | tail -n 1)
}
Close_server(){
    tip "正在关闭已开启的服务器（有的话） ..."
    for shard in ${shardarray}
    do
        if tmux has-session -t DST_${shard} > /dev/null 2>&1
        then
            tmux send-keys -t DST_${shard} "c_shutdown(true)" C-m
            sleep 10
            info "${shard}世界服务器已关闭！"
            exchangestatus false
        else
            info "${shard}世界服务器未开启！"
        fi
    done
    for shard in ${shardarray}
    do
        tmux kill-session -t DST_${shard} > /dev/null 2>&1
    done
}
Exit_auto_update(){
    if tmux has-session -t Auto_update > /dev/null 2>&1
    then
        tmux kill-session -t Auto_update > /dev/null 2>&1
    fi
    info "自动更新进程已停止运行 ..."
}
Set_cluster(){
    if [ -f ${dst_base_dir}/${cluster}/cluster.ini ]
    then
        rm -rf ${dst_base_dir}/${cluster}/cluster.ini
    fi
    while (true)
    do
        clear
        echo -e "\e[92m=============【存档槽：${cluster}】===============\e[0m"
        index=1
        cat ${dst_cluster_file} | grep -v "script_ver" | while read line
        do
            ss=(${line})
            if [ "${ss[4]}" != "readonly" ]
            then
                if [ "${ss[4]}" == "choose" ]
                then
                    for ((i=5;i<${#ss[*]};i++))
                    do
                        if [ "${ss[$i]}" == "${ss[1]}" ]
                        then
                            value=${ss[$i+1]}
                        fi
                    done
                else
                    # 处理替代空格的#号
                    value=$(echo ${ss[1]} | sed 's/#/ /g')
                fi
                echo -e "\e[33m[${index}] ${ss[2]}：${value}\e[0m"
            fi
            index=$[${index} + 1]
        done
        echo -e "\e[92m===============================================\e[0m"
        cmd=""
        while (true)
        do
            if [[ ${cmd} == "" ]]
            then
                echo -e "\e[92m请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：\e[0m\c"
                read cmd
            else
                break
            fi
        done
        case ${cmd} in
            0)
            info "更改已保存！"
               break
               ;;
            *)
            changelist=($(sed -n "${cmd}p" ${dst_cluster_file}))
            if [ "${changelist[4]}" = "choose" ]
            then
                echo -e "\e[92m请选择${changelist[2]}： \e[0m\c"
                index=1
                for ((i=5;i<${#changelist[*]};i=$i+2))
                do
                    echo -e "\e[92m${index}.${changelist[$[$i + 1]]}\e[0m\c"
                    index=$[${index} + 1]
                done
                echo -e "\e[92m: \e[0m\c"
                read changelistindex
                listnum=$[${changelistindex} - 1]*2
                changelist[1]=${changelist[$[$listnum + 5]]}
            else
                echo -e "\e[92m请输入${changelist[2]}：\e[0m\c"
                read changestr
                # 处理空格
                changestr=$(echo ${changestr} | sed 's/ /#/g')
                changelist[1]=${changestr}
            fi
            changestr="${changelist[@]}"
            sed -i "${cmd}c ${changestr}" ${dst_cluster_file}
            ;;
        esac
    done
    type=([GAMEPLAY] [NETWORK] [MISC] [SHARD])
    for ((i=0;i<${#type[*]};i++))
    do
        echo "${type[i]}" >> ${dst_base_dir}/${cluster}/cluster.ini
        cat ${dst_cluster_file} | grep -v "script_ver" | while read lc
        do
            lcstr=($lc)
            if [ "${lcstr[3]}" == "${type[i]}" ]
            then
                if [ "${lcstr[1]}" == "无" ]
                then
                    lcstr[1]=""
                fi
                # 还原空格
                value_str=$(echo ${lcstr[1]} | sed 's/#/ /g')
                echo "${lcstr[0]}=${value_str}" >> ${dst_base_dir}/${cluster}/cluster.ini
            fi
        done
        echo "" >> ${dst_base_dir}/${cluster}/cluster.ini
    done
}
Set_token(){
    if [ -f ${dst_token_file} ]
    then
        default_token=$(cat ${dst_token_file})
    else
        default_token="pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE="
    fi
    info "当前预设的服务器令牌：\n ${default_token}"
    echo -e "\e[92m是否更改？ 1.是  2.否 : \e[0m\c"
    read ch
    if [ $ch -eq 1 ]
    then
        tip "请输入或粘贴你的令牌到此处："
        read mytoken
        mytoken=$(echo ${mytoken} | sed 's/ //g')
        echo ${mytoken} > ${dst_token_file}
        info "已更改服务器默认令牌！"
    else
        echo ${default_token} >${dst_token_file}
    fi
    cat ${dst_token_file} > ${dst_base_dir}/${cluster}/cluster_token.txt
}
Set_list(){
    if [ ! -f ${data_dir}/alist.txt ]
    then
        touch ${data_dir}/alist.txt
    fi
    if [ ! -f ${data_dir}/blist.txt ]
    then
        touch ${data_dir}/blist.txt
    fi
    if [ ! -f ${data_dir}/wlist.txt ]
    then
        touch ${data_dir}/wlist.txt
    fi
    cat ${data_dir}/alist.txt > ${dst_base_dir}/${cluster}/adminlist.txt
    cat ${data_dir}/blist.txt > ${dst_base_dir}/${cluster}/blocklist.txt
    cat ${data_dir}/wlist.txt > ${dst_base_dir}/${cluster}/whitelist.txt
}
Set_world(){
    game_mode=$(cat ${dst_base_dir}/${cluster}/cluster.ini | grep ^game_mode= | cut -d "=" -f2)
    if [[ ${game_mode} != "lavaarena" ]]
    then
        info "是否修改${shardtype}[${sharddir}]配置？：1.是 2.否（默认为上次配置）"
        read wc
        configure_file="${data_dir}/${shardname}leveldata.txt"
        data_file="${dst_base_dir}/${cluster}/${sharddir}/leveldataoverride.lua"
        if [ ${wc} -ne 2 ]
        then
            Set_world_config
        fi
        Write_in ${shardname}
    else
        cat ${data_dir}/lavaarena.lua > ${dst_base_dir}/${cluster}/${sharddir}/leveldataoverride.lua
        info "熔炉世界配置已写入！"
        info "正在检查熔炉MOD是否已下载安装 。。。"
        if [ -f ${dst_server_dir}/mods/workshop-1531169447/modinfo.lua ]
        then
            info "熔炉MOD已安装 。。。"
        else
            tip "熔炉MOD未安装 。。。即将下载 。。。"
            echo "ServerModSetup(\"1531169447\")" > ${dst_server_dir}/mods/dedicated_server_mods_setup.lua
            Download_MOD
        fi
        if [ -f ${dst_server_dir}/mods/workshop-1531169447/modinfo.lua ]
        then
            Default_mod
            modid='1531169447'
            Get_shard_array
            Addmodfunc
            info "熔炉MOD已启用 。。。"
        else
            tip "熔炉MOD启用失败，请自行检查原因或反馈 。。。"
        fi
    fi
}
Set_world_config(){
    while (true)
    do
        clear
        index=1
        linenum=1
        list=(environment source food animal monster)
        liststr=(
        ================================世界环境================================
        ==================================资源==================================
        ==================================食物==================================
        ==================================动物==================================
        ==================================怪物==================================
        )
        for ((j=0;j<${#list[*]};j++))
        do
            echo -e "\n\e[92m${liststr[$j]}\e[0m"
            cat ${configure_file} | grep -v "script_ver" | while read line
            do
                ss=(${line})
                if [ ${#ss[@]} -gt 4 ]
                then
                    if [ ${index} -gt 3 ]
                    then
                        printf "\n"
                        index=1
                    fi
                    for ((i=4;i<${#ss[*]};i++))
                    do
                        if [ "${ss[$i]}" == "${ss[1]}" ]
                        then
                            value=${ss[$i+1]}
                        fi
                    done
                    if [ "${list[$j]}" == "${ss[2]}" ]
                    then
                        printf "%-21s\t" "[${linenum}]${ss[3]}: ${value}"
                        index=$[${index} + 1]
                    fi
                fi
                linenum=$[${linenum} + 1]
            done
        done
        printf "\n"
        cmd=""
        while (true)
        do
            if [[ ${cmd} == "" ]]
            then
                echo -e "\e[92m请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)： \e[0m\c"
                read cmd
            else
                break
            fi
        done
        case ${cmd} in
            0)
            info "更改已保存！"
            break
            ;;
            *)
            changelist=($(sed -n "${cmd}p" ${configure_file}))
               echo -e "\e[92m请选择${changelist[3]}： \e[0m\c"
               index=1
               for ((i=4;i<${#changelist[*]};i=$i+2))
               do
                   echo -e "\e[92m${index}.${changelist[$[$i + 1]]}\e[0m\c"
                   index=$[${index} + 1]
               done
               echo -e "\e[92m: \e[0m\c"
               read changelistindex
               listnum=$[${changelistindex} - 1]*2
               changelist[1]=${changelist[$[$listnum + 4]]}
               changestr="${changelist[@]}"
               sed -i "${cmd}c ${changestr}" ${configure_file};;
        esac
    done
}
Write_in(){
    data_num=$[$(grep -n "^" ${configure_file} | tail -n 1 | cut -d : -f1) - 1]
    cat "${data_dir}/${1}start.lua" > ${data_file}
    index=1
    cat ${configure_file} | grep -v "script_ver" | while read line
    do
        ss=(${line})
        if [ ${index} -lt ${data_num} ]
        then
            char=","
        else
            char=""
        fi
        index=$[${index} + 1]
        if [[ ${ss[1]} == "highlyrandom" ]]
        then
            str="${ss[0]}=\"highly random\"${char}"
        else
            str="[\"${ss[0]}\"]=\"${ss[1]}\"${char}"
        fi
        echo "    ${str}" >> ${data_file}
    done
    cat "${data_dir}/${1}end.lua" >> ${data_file}
}
Default_mod(){
    Get_shard_array
    for shard in ${shardarray}
    do
        if [ ! -f ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua ]
        then
            echo 'return {
}' > ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua
        fi
    done
}
Setup_mod(){
    if [ -f ${data_dir}/mods_setup.lua ]
    then
        rm -rf ${data_dir}/mods_setup.lua
    fi
    touch ${data_dir}/mods_setup.lua
    Get_single_shard
    dir=$(cat ${dst_base_dir}/${cluster}/${shard}/modoverrides.lua | grep "workshop" | cut -f2 -d '"' | cut -d "-" -f2)
    for moddir in ${dir}
    do
        if [[ $(grep "${moddir}" -c "${data_dir}/mods_setup.lua") = 0 ]]
        then
            echo "ServerModSetup(\"${moddir}\")" >> "${data_dir}/mods_setup.lua"
        fi
    done
    cp "${data_dir}/mods_setup.lua" "${dst_server_dir}/mods/dedicated_server_mods_setup.lua"
}
Start_shard(){
    Setup_mod
    cd "${dst_server_dir}/bin"
    for shard in ${shardarray}
    do
        unset TMUX
        tmux new-session -s DST_${shard} -d "${dst_bin_cmd} -cluster ${cluster} -shard ${shard}"
    done
}
Start_check(){
    Get_single_shard
    log_file=${dst_base_dir}/${cluster}/${shard}/server_log.txt
    if [ -f $log_file ]
    then
        RES=`flock -x -n $log_file -c "echo ok"`
        log_index=1
        old_line1=""
        while [ "$RES" = "ok" ]
        do
            line1=$(sed -n ${log_index}p $log_file)
            if [[ $line1 != $old_line1 ]]
            then
                log_index=$[$log_index + 1]
                old_line1=$line1
            fi
            cat ${log_arr_str} | grep -v script_ver | while read line
            do
                line_1=$(echo $line | cut -d '@' -f1)
                line_2=$(echo $line | cut -d '@' -f2)
                if [[ $line1 =~ $line_1 ]]
                then
                    info $line_2
                    break
                fi
            done
            if [[ $line_2 == "世界连接成功。。。服务器开启成功！" || $line_2 == "令牌缺失。。。服务器开启失败！" ]]
            then
                break 2
            fi
        done
    fi
    #     while (true)
    #     do
    #         if tmux has-session -t DST_${shard} > /dev/null 2>&1
    #         then
    #             if [[ $(grep "Sim paused" -c "${serverlog_path}") > 0 ]]
    #             then
    #                 newshardarray="${newshardarray}${shard}"
    #                 break
    #             fi
    #             if [[ $(grep "Your Server Will Not Start" -c "${serverlog_path}") > 0 ]]
    #             then
    #                 newshardarray="TOKENINVALID"
    #                 break
    #             fi
    #         else
    #             current_time=$(date "+%s")
    #             check_time=$[ $current_time - $start_time ]
    #             # 一分钟超时 MOD bug 或者设置问题
    #             if [ ${check_time} > 60 ]
    #             then
    #                 newshardarray="BREAK"
    #                 break
    #             fi
    #         fi
    #         current_time=$(date "+%s")
    #         check_time=$[ ${current_time} - ${start_time} ]
    #         # 十分钟超时 MOD下载超时或端口占用
    #         if [ ${check_time} -gt 600 ]
    #         then
    #             newshardarray="TIME_OUT"
    #             break
    #         fi
    #     done
    # done
    # shardarray=$(echo ${shardarray} | sed 's/ //g')
    # if [[ ${shardarray} == ${newshardarray} ]]
    # then
    #     info "服务器开启成功，和小伙伴尽情玩耍吧！"
    # else
    #     if [[ ${newshardarray} == "TIME_OUT" ]]
    #     then
    #         error "MOD下载超时或端口占用, 请自行检查服务器日志处理问题后重试！"
    #     elif [[ ${newshardarray} == "BREAK" ]]
    #     then
    #         error "开启的MOD存在bug或设置存在问题, 请自行检查服务器日志处理问题后重试！"
    #     elif [[ ${newshardarray} == "TOKENINVALID" ]]
    #     then
    #         error "服务器令牌无效或未设置！！！请自行检查处理问题后重试！"
    #     else
    #         error "未知错误！！！请反顾给作者！！！谢谢！"
    #     fi
    # fi
}
#############################################################################
First_run_check(){
    if [ ! -f ${dst_server_dir}/version.txt ]
    then
        info "检测到你是首次运行脚本，需要进行必要的配置，所需时间由服务器带宽决定，大概一个小时 ..."
        Open_swap
        Mkdstdir
        Install_Dependency
        Install_Steamcmd
        info "安装游戏服务端 ..."
        Install_Game
        Fix_steamcmd
        if [ ! -f ${dst_server_dir}/version.txt ]
        then
            error "安装失败，请重试！多次重试仍无效请反馈!" && exit 1
        fi
        info "首次运行配置完毕，你可以创建新的世界了。"
    fi
}
# open swap
Open_swap(){
    info "创建并开启虚拟内存 ..."
    sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo mkswap /swapfile
    sudo chmod 0600 /swapfile
    sudo swapon /swapfile
    sudo chmod 0666 /etc/fstab
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    sudo chmod 0644 /etc/fstab
    info "虚拟内存已开启！"
}
# 创建文件夹
Mkdstdir(){
    mkdir -p ${HOME}/steamcmd
    mkdir -p ${dst_server_dir}
    mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}
    mkdir -p ${data_dir}
}
# 检查当前系统信息
Check_sys(){
    if [[ -f /etc/redhat-release ]]
    then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"
    then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"
    then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"
    then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"
    then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"
    then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"
    then
        release="centos"
    fi
    if [[ ${release} != "ubuntu" && ${release} != "debian" && ${release} != "centos" ]]
    then
        error "很遗憾！本脚本暂时只支持Debian7+和Ubuntu12+和CentOS7+的系统！" && exit 1
    fi
    bit=`uname -m`
}
# 安装依赖库和必要软件
Install_Dependency(){
    info "安装DST所需依赖库及软件 ..."
    if [[ ${release} != "centos" ]]
    then
        if [[ ${bit} = "x86_64" ]]
        then
            sudo dpkg --add-architecture i386
                sudo apt update
                sudo apt install -y lib32gcc1 libstdc++6 libstdc++6:i386 libcurl4-gnutls-dev:i386 tmux wget lua5.2 git openssl libssl-dev
        else
            sudo apt update
            sudo apt install -y libstdc++6 libcurl4-gnutls-dev tmux wget lua5.2 git openssl libssl-dev
        fi
    else
        if [[ ${bit} = "x86_64" ]]
        then
            sudo yum install -y tmux glibc.i686 libstdc++ libstdc++.i686 libcurl.i686 wget lua5.2 git openssl openssl-devel
        else
            sudo yum install -y wget tmux libstdc++ libcurl lua5.2 git openssl openssl-devel
        fi
     fi
}
# Install steamcmd
Install_Steamcmd(){
    wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
    tar -xzvf steamcmd_linux.tar.gz -C ${HOME}/steamcmd
    chmod +x ${HOME}/steamcmd/steamcmd.sh
    rm steamcmd_linux.tar.gz
}
# Install DST Dedicated Server
Install_Game(){
    cd ${HOME}/steamcmd || exit 1
    ./steamcmd.sh +login "anonymous" +force_install_dir "${dst_server_dir}" +app_update "343050" validate +quit
}
# 修复SteamCMD [S_API FAIL] SteamAPI_Init() failed;
Fix_steamcmd(){
    info "修复Steamcmd可能存在的依赖问题 ..."
    mkdir -p "${HOME}/.steam/sdk32"
    cp -v ${HOME}/steamcmd/linux32/steamclient.so "${HOME}/.steam/sdk32/steamclient.so"
    # fix lib for centos
    if [[ ${release} == "centos" ]] && [ ! -f "${dst_server_dir}/bin/lib32/libcurl-gnutls.so.4" ]
    then
        info "libcurl-gnutls.so.4 missing ... create a lib link."
        ln -s "/usr/lib/libcurl.so.4" "${dst_server_dir}/bin/lib32/libcurl-gnutls.so.4"
    fi
}
##########################################################################
# Show change log
Show_changelog(){
    echo -e "\e[33m==============================脚本更新说明======================================\e[0m"
    #cat /tmp/dstscript/.dstscript/changelog.txt > /tmp/changelog.txt
    wget ${update_link}/.dstscript/changelog.txt -O /tmp/changelog.txt > /dev/null 2>&1
    datelog=$(cat /tmp/changelog.txt | head -n 1)
    cat /tmp/changelog.txt | grep -A 20 "更新日志 ${datelog}"
    echo -e "\e[33m================================================================================\e[0m"
    sleep 3
}
# 脚本更新
Update_script(){
    info "正在检查脚本是否有更新 。。。 请稍后 。。。"
    wget ${update_link}/.dstscript/filelist.txt -O /tmp/filelist.txt > /dev/null 2>&1
    for file in $(cat /tmp/filelist.txt | cut -d ":" -f1)
    do
        new_ver=$(cat /tmp/filelist.txt | grep "${file}" | cut -d ":" -f2)
        if [[ "${file}" != "dstserver.sh" ]]
        then
            truefile=".dstscript/${file}"
        else
            truefile=${file}
        fi
        if [ -f ${HOME}/${truefile} ]
        then
            cur_ver=$(cat ${HOME}/${truefile} | grep "script_ver=" | head -n 1 | cut -d '"' -f2)
        else
            cur_ver="000"
        fi
        [[ -z ${new_ver} ]] && new_ver=${cur_ver}
        if [[ ${new_ver} != ${cur_ver} ]]
        then
            info "${file} 发现新版本[ ${new_ver} ]，更新中..."
            wget ${update_link}/${truefile} -O ${HOME}/${truefile} > /dev/null 2>&1
            chmod +x ${HOME}/dstserver.sh
            info "${file} 已更新为最新版本[ ${new_ver} ] !"
            if [[ "${file}" == "dstserver.sh" ]]
            then
                need_exit="true"
            fi
            if [[ ${file} == "updatelib.txt" ]]
            then
                tip "本次更新需要更新依赖 。。。请稍候 。。。"
                Install_Dependency >/dev/null 2>&1
            fi
            need_update="true"
        fi
    done
    if [[ "${need_update}" == "true" ]]
    then
        Show_changelog
    fi
    if [[ "${need_exit}" == "true" ]]
    then
        tmux kill-session -t Auto_update > /dev/null 2>&1
        tip "因脚本已更新，自动更新进程已退出，如需要请重新开启！"
        exit 0
    fi
}
# MOD update check
Update_DST_MOD_Check(){
    info "检查启用的创意工坊MOD是否有更新 ..."
    MOD_update="false"
    for modid in $(cat ${data_dir}/mods_setup.lua | grep "ServerModSetup" | cut -d '"' -f2)
    do
        mod_new_ver=$(curl -s "${my_api_link}/?type=mod&modid=${modid}" | sed 's/[ \t]*$//g')
        if [ -f ${dst_server_dir}/mods/workshop-${modid}/modinfo.lua ]
        then
            echo "fuc=\"getver\"" > ${data_dir}/modinfo.lua
            cat ${dst_server_dir}/mods/workshop-${modid}/modinfo.lua >> ${data_dir}/modinfo.lua
            cd ${data_dir}
            mod_cur_ver=$(lua modconf.lua)
        else
            mod_cur_ver=000
        fi
        if [[ ${mod_new_ver} != "" && ${mod_new_ver} != "" && ${mod_new_ver} != "nil" && ${mod_new_ver} != ${mod_new_ver} ]]
        then
            info "MOD 有更新(${modid}[${mod_new_ver} ==> ${mod_new_ver}])，即将重启更新 ..."
            MOD_update="true"
            break
        else
            info "MOD (${modid}) 无更新！"
        fi
    done
}
Status_keep(){
    Get_shard_array
    for shard in $shardarray
    do
        if ! tmux has-session -t DST_${shard} > /dev/null 2>&1
        then
            server_alive=false
            break
        else
            server_alive=true
        fi
    done
    if [[ $(grep "serveropen" ${server_conf_file} | cut -d "=" -f2) == "true" &&  ${server_alive} == "false" ]]
    then
        tip "服务器异常退出，即将重启 ..."
        Reboot_server
    fi
}
Simple_server_status(){
    cluster="无"
    server_on=""
    Get_current_cluster
    Get_shard_array
    for shard in ${shardarray}
    do
        if tmux has-session -t DST_${shard} > /dev/null 2>&1
        then
            server_on="${server_on}${shard}"
        fi
    done
    if tmux has-session -t Auto_update > /dev/null 2>&1
    then
        auto_on="开启"
    else
        auto_on="关闭"
    fi
    cluster_name="无"
    if [[ ${server_on} == "" ]]
    then
        server_on="无"
    fi
    [ -f ${dst_base_dir}/${cluster}/cluster.ini ] && cluster_name=$(cat ${dst_base_dir}/${cluster}/cluster.ini | grep "^cluster_name" | cut -d "=" -f2)
    echo -e "\e[33m存档: ${cluster}   开启的世界：${server_on}   名称: ${cluster_name}\e[0m"
    echo -e "\e[33m自动更新维护：${auto_on}\e[0m"
}
Fix_Net_hosts(){
    sudo chmod 666 /etc/hosts
    if ! grep steamusercontent-a.akamaihd.net /etc/hosts > /dev/null 2>&1
    then
        echo "72.246.103.17 steamusercontent-a.akamaihd.net" >> /etc/hosts
    fi
    if ! grep s3.amazonaws.com /etc/hosts > /dev/null 2>&1
    then
        echo "52.216.136.5 s3.amazonaws.com" >> /etc/hosts
    fi
    if ! grep steamcommunity.com /etc/hosts > /dev/null 2>&1
    then
        echo "23.222.167.249 steamcommunity.com" >> /etc/hosts
    fi
    sudo chmod 644 /etc/hosts
}
Update_MOD(){
    Get_current_cluster
    Setup_mod
    Update_DST_MOD_Check
    if [[ ${MOD_update} == "true" ]]
    then
        Download_MOD
    fi
}
Download_MOD(){
    info "正在安装/更新新添加的MOD，请稍候 。。。"
    if [ ! -d ${dst_base_dir}/downloadmod/Master ]
    then
        mkdir -p ${dst_base_dir}/downloadmod/Master
    fi
    if tmux has-session -t DST_MODUPDATE > /dev/null 2>&1
    then
        tmux kill-session -t DST_MODUPDATE
    fi
    cd ${dst_server_dir}/bin || exit 1
    tmux new-session -s DST_MODUPDATE -d "${dst_bin_cmd} -cluster downloadmod -shard Master"
    sleep 5
    while (true)
    do
        if tmux has-session -t DST_MODUPDATE > /dev/null 2>&1
        then
            if [[ $(grep "Your Server Will Not Start" -c "${dst_base_dir}/downloadmod/Master/server_log.txt") > 0 ]]
            then
                info "新MOD安装/更新完毕！"
                tmux kill-session -t DST_MODUPDATE
                break
            fi
        fi
    done
}
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
		fi
	fi
}
Post_ipmd5(){
    Get_IP
    send_str=$(echo -n ${ip} | openssl md5 | cut -d " " -f2)
    curl -s "${my_api_link}/?type=tongji&ipmd5string=${send_str}" > /dev/null 2>&1
    echo "$(date +%s)" > ${data_dir}/ipmd5.txt
}
# 仅发送md5值做统计，尊重隐私，周期内只发送一次，保证流畅性
Send_md5_ip(){
    if [ ! -f ${data_dir}/ipmd5.txt ]
    then
        Post_ipmd5
    else
        cur_time=$(date +%s)
        old_time=$(cat ${data_dir}/ipmd5.txt)
        cycle=$[ ${cur_time} - ${old_time} ]
        # 周期为七天
        if [ $cycle -gt 604800 ]
        then
            Post_ipmd5
        fi
    fi
}
####################################################################################
if [[ $1 == "au" ]]; then
    while (true)
    do
        clear
        echo -e "\e[33m===========饥荒联机版独立服务器脚本自动更新及异常维护进程[Linux-Steam](${script_ver})===========\e[0m"
        Update_DST
        Update_DST_MOD_Check
        if [[ ${MOD_update} == "true" ]]
        then
            Reboot_server
        fi
        Status_keep
        info "$(date) [退出请按Ctrl + B松开再按D]"
        info "每半小时进行一次更新检测。。。"
        sleep 1800
    done
fi
# 移动根目录到隐藏目录
if [ -d ${HOME}/dstscript ]
then
    mv ${HOME}/dstscript ${HOME}/.dstscript
fi
# 卸载重装
if [ ! -d ${data_dir} ]
then
    mkdir -p ${data_dir}
fi
# Run from here
Check_sys
First_run_check
Fix_Net_hosts
Update_script
Update_DST_Check
Send_md5_ip
clear
Menu
