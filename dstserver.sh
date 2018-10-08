#!/bin/bash
#===============================================================================
#    System Required: Ubuntu12+/Debian7+
#    Description: Install and manager the Don't Starve Together Dedicated Server
#    Author: Ariwori
#    Blog: https://wqlin.com
#===============================================================================
script_ver="1.6.1"
dst_conf_dirname="DoNotStarveTogether"   
dst_conf_basedir="$HOME/.klei"
dst_base_dir="$dst_conf_basedir/$dst_conf_dirname"
dst_server_dir="$HOME/DSTServer"
dst_bin_cmd="./dontstarve_dedicated_server_nullrenderer"
data_dir="$HOME/dstscript"
dst_token_file="$data_dir/clustertoken.txt"
server_conf_file="$data_dir/server.conf"
dst_cluster_file="$data_dir/clusterdata.txt"
feedback_link="https://wqlin.com/dstscript.html"
update_link="https://raw.githubusercontent.com/ariwori/dstscript/master"
mod_api_link="https://wqlin.com/api/dstmod.php"
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[Info]${Font_color_suffix}"
Error="${Red_font_prefix}[Error]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[Tips]${Font_color_suffix}"
info(){ echo -e "${Info} $1"; }
tip(){ echo -e "${Tip} $1"; }
error(){ echo -e "${Error} $1"; }
# Main menu
Menu(){    
    while (true); do
        echo -e "\e[33m==============欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]($script_ver)==============\e[0m"
        echo
        echo -e "\e[33m作者：Ariwori        Bug反馈：${feedback_link}\e[0m"
        echo -e "\e[33m本脚本一切权利归作者所有。未经许可禁止使用本脚本进行任何的商业活动！\e[0m"
        echo -e "\e[31m游戏服务端安装目录：$dst_server_dir (Version: $(cat $dst_server_dir/version.txt))\e[33m【$dst_need_update_str】\e[0m"
        echo
        echo -e "\e[92m[1]启动服务器           [2]关闭服务器           [3]重启服务器\e[0m"  
        echo -e "\e[92m[4]查看服务器状态       [5]添加或移除MOD        [6]设置管理员和黑名单\e[0m"
        echo -e "\e[92m[7]控制台               [8]自动更新及异常维护   [9]退出本脚本\e[0m"
        echo -e "\e[92m[10]删除存档            [11]更新游戏服务端/MOD  \e[0m"
        echo
        Simple_server_status
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m\c"
        read cmd  
        case $cmd in
            1)
            Start_server;;
            2)
            Close_server
            Exit_auto_update;;
            3)
            Reboot_server;;
            4)
            Server_detail;;
            5)
            MOD_manager;;
            6)
            List_manager;;
            7)
            Server_console;;
            8)
            Auto_update;;
            9)
            exit;;	
            10)
            Cluster_manager;;
            11)
            Update_DST;;
        esac
    done
}
###################################################################
Not_work_now(){
    info "功能尚未完成，请等待作者更新！"
}
###################################################################
Server_detail(){
    Not_work_now
}
Server_console(){
    Not_work_now
}
MOD_manager(){
    [ -z $cluster ] && cluster=$(cat $server_conf_file | grep "^cluster" | cut -d "=" -f2)
    read -p "你要 1.添加mod  2.删除mod 【存档：$cluster】:" mc
    case $mc in
        1)
        Listallmod
        Addmod;;
        2)
        Listusedmod
        Delmod;;
        *)
        break;;
    esac
}
MOD_conf(){
    echo "fuc = \"$fuc\"
modid = \"$moddir\"
used = \"$used\"" > "$data_dir/modinfo.lua"
    if [[ -f "$dst_server_dir/mods/$moddir/modinfo.lua" ]]; then
        cat "${dst_server_dir}/mods/$moddir/modinfo.lua" >> "$data_dir/modinfo.lua"
    else
        echo "name = \"UNKNOWN\"" >> "$data_dir/modinfo.lua"
    fi
    cd $data_dir
    lua $data_dir/modconf.lua
    cd $HOME
}
Listallmod(){
    if [ ! -f $data_dir/mods_setup.lua ]; then
        touch $data_dir/mods_setup.lua
    fi
    rm -f $data_dir/modconflist.lua
    for moddir in $(ls -F "$dst_server_dir/mods" | grep "/$" | cut -d '/' -f1); do
        if [ $(grep "$moddir" -c "$dst_base_dir/$cluster/Master/modoverrides.lua") -gt 0 ]; then
            used="true"
        else
            used="false"
        fi
        if [[ "$moddir" != "" ]]; then
            fuc="list"
            MOD_conf
        fi
    done
    grep -n "^" $data_dir/modconflist.lua
}
Listusedmod(){
    rm -f $data_dir/modconflist.lua
    for moddir in $(grep "^\[" "$dst_base_dir/$cluster/Master/modoverrides.lua" | cut -d '"' -f2); do
        if [[ "$moddir" != "" ]]; then
            fuc="list"
            used="true"
            MOD_conf
        fi
    done
    grep -n "^" $data_dir/modconflist.lua
}
Addmod(){
    echo -e "请从以上列表选择你要启用的MOD${Red_font_prefix}[编号]${Font_color_suffix}，不存在的直接输入MODID"
    echo "具体配置已写入 modoverride.lua, shell下修改太麻烦，可打开配置文件手动修改"
    echo "添加完毕要退出请输入数字 0 ！"
    while (true); do
        read modid
        if [[ "$modid" == "0" ]]; then
            echo "添加完毕 ！"
            break
        else
            Addmodfunc
        fi
    done
    echo "要修改具体参数配置请手动打开***更改："
    echo "$dst_base_dir/$cluster/Master/modoverrides.lua"
    echo "$dst_base_dir/$cluster/Caves/modoverrides.lua"
    sleep 3
    clear
}
Addmodtoshard(){
    if [[ $(grep "$moddir" "$dst_base_dir/$cluster/$shard/modoverrides.lua") > 0 ]]; then
        echo "$shard世界该Mod($moddir)已添加"
    else
        sed -i '1d' $dst_base_dir/$cluster/$shard/modoverrides.lua
        cat $dst_base_dir/$cluster/$shard/modoverrides.lua > $data_dir/modconftemp.txt
        echo "return {" > $dst_base_dir/$cluster/$shard/modoverrides.lua
        cat $data_dir/modconfwrite.lua >> $dst_base_dir/$cluster/$shard/modoverrides.lua
        cat $data_dir/modconftemp.txt >> $dst_base_dir/$cluster/$shard/modoverrides.lua
        echo "$shard世界Mod($moddir)添加完成"
    fi
}
Truemodid(){
    if [ $modid -lt 1000 ]; then
        moddir=$(sed -n ${modid}p $data_dir/modconflist.lua | cut -d ':' -f2)
    else
        moddir="workshop-$modid"
    fi
}
Addmodfunc(){
    Truemodid
    fuc="writein"
    MOD_conf
    for shard in "Master" "Caves"; do Addmodtoshard; done
}
Delmodfromshard(){
    if [[ $(grep "$moddir" -c "$dst_base_dir/$cluster/$shard/modoverrides.lua") > 0 ]]; then
        grep -n "^\[" "$dst_base_dir/$cluster/$shard/modoverrides.lua" > $data_dir/modidlist.txt
        up=$(grep "$moddir" "$data_dir/modidlist.txt" | cut -d ":" -f1)
        down=$(grep -A 1 "$moddir" "$data_dir/modidlist.txt" | tail -1 |cut -d ":" -f1)
        upnum=$(($up - 1))
        downnum=$(($down - 2))
        sed -i "$upnum,${downnum}d" "$dst_base_dir/$cluster/$shard/modoverrides.lua"
        echo "$shard世界该Mod($moddir)已停用！"
    else
        echo "$shard世界该Mod($moddir)未启用！"
    fi
}
Delmod(){
    echo -e "请从以上列表选择你要停用的MOD${Red_font_prefix}[编号]${Font_color_suffix},非脚本添加的MOD不要使用本功能,完毕请输数字 0 ！"
    while (true); do
        read modid
        if [[ "$modid" == "0" ]]; then
            info "MOD删除完毕！"
            break
        else
            Truemodid
            for shard in "Master" "Caves"; do Delmodfromshard; done
        fi
    done
}
List_manager(){
    echo -e "\e[92m你要设置：1.管理员  2.黑名单  3.白名单\e[0m"
    read list
    case $list in
        1)
        listfile="alist.txt"
        listname="管理员";;
        2)
        listfile="blist.txt"
        listname="黑名单";;
        3)
        listfile="wlist.txt"
        listname="白名单";;
        *)
        error "输入有误，请输入数字[1-3]";;
    esac
    echo -e "\e[92m你要：1.添加$listname  2.移除$listname\e[0m"
    read addordel
    case $addordel in
        1)
        Addlist;;
        2)
        Dellist;;
    esac
}
Addlist(){
    echo -e "\e[92m请输入你要添加的KLEIID（KU_XXXXXXX）：(添加完毕请输入数字 0 )\e[0m"
    while (true); do
        read kleiid
        if [[ "$kleiid" == "0" ]]; then
            echo "添加完毕！"
            break
        else
            if [[ $(grep "$kleiid" -c "$data_dir/$listfile") > 0 ]]; then
                echo -e "\e[92m名单$kleiid已经存在！\e[0m"
            else
                echo "$kleiid" >> $data_dir/$listfile
                echo -e "\e[92m名单$kleiid已添加！\e[0m"
            fi
        fi
    done
}
Dellist()
{
    while (ture); do
        echo "=========================================================================="
        grep -n "KU" "$data_dir/$listfile"
        echo -e "\e[92m请输入你要移除的KLEIID${Red_font_prefix}[编号]${Font_color_suffix}，删除完毕请输入数字 0 \e[0m"
        read kleiid
        if [[ "$kleiid" == "0" ]]; then
            echo "移除完毕！"
            break
        else
            sed -i "${kleid}d" $dst_base_dir/$listfile
            echo -e "\e[92m名单已移除！\e[0m"
        fi
    done
}
Cluster_manager(){
    cluster_str="删除"
    Choose_exit_cluster
    rm -rf $dst_base_dir/$cluster
    info "存档 $cluster 已删除！"
}
Auto_update(){
    if tmux has-session -t Auto_update > /dev/null 2>&1; then
        info "自动更新进程已在运行，即将跳转。。。退出请按Ctrl + B松开再按D"
        sleep 3
        tmux attach-session -t Auto_update
    else
        tmux new-session -s Auto_update -d "./dstserver.sh au"
        info "自动更新已开启！"
    fi
}
Update_DST_Check(){
    # data from klei forums
    info "Checking if the game is updated from the klei forums... please wait!"
    currentbuild=$(cat $dst_server_dir/version.txt)
    availablebuild=$(curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep 'data-releaseID=' | cut -d '/' -f6 | cut -d "-" -f1 | sort | tail -n 1)
    if [ "${currentbuild}" != "${availablebuild}" ]; then
        dst_need_update=true
        dst_need_update_str="需要更新"
    else
        dst_need_update=false
        dst_need_update_str="无需更新"
    fi
}
Update_DST(){
    serveropen=$(grep "serveropen" $server_conf_file | cut -d "=" -f2)
    Update_DST_Check
    if [[ $dst_need_update == "true" ]]; then
        info "更新可用(${currentbuild}===>${availablebuild})！即将执行更新..."
        Reboot_announce
        Close_server
        Install_Game
    else
        tip "无可用更新！当前版本（$currentbuild）"
    fi
    if [[ $serveropen == "true" && dst_need_update == "true" ]]; then
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
    if [ ! -f $server_conf_file ]; then touch $server_conf_file; fi
    if [ $(grep "serveropen" -c $server_conf_file) -eq 0 ]; then
        echo "serveropen=$1" >> $server_conf_file
    else
        str=$(grep "serveropen" $server_conf_file)
        sed -i "s/$str/serveropen=$1/g" $server_conf_file
    fi
}
Run_server(){
    cluster=$(cat $server_conf_file | grep "^cluster" | cut -d "=" -f2)
    shard=$(cat $server_conf_file | grep "^shard" | cut -d "=" -f2)
    exchangestatus true
    Start_shard
    info "服务器开启中。。。请稍候。。。"
    sleep 10
    Start_check
}
Reboot_announce(){
    if tmux has-session -t DST_Master > /dev/null 2>&1; then   									        
        tmux send-keys -t DST_Master "c_announce(\"服务器因改动或更新需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
    fi
    if tmux has-session -t DST_Caves > /dev/null 2>&1; then						        
        tmux send-keys -t DST_Caves "c_announce(\"服务器设因改动或更新需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
    fi
    sleep 5
}
Start_server(){
    info "本操作将会关闭已开启的服务器 ..."
    Close_server
    Exit_auto_update
    echo -e "\e[92m是否新建存档: [y|n] (默认: y): \e[0m\c"
    read yn
    [[ -z "${yn}" ]] && yn="y"
    if [[ ${yn} == [Yy] ]]; then
        echo -e "\e[92m请输入新建存档名称：（不要包含中文、符号和空格）\e[0m"
        read cluster
        if [ ! -d "$dst_base_dir/$cluster" ]; then 
            mkdir -p $dst_base_dir/$cluster
            mkdir -p $dst_base_dir/$cluster/Master
            mkdir -p $dst_base_dir/$cluster/Caves
        fi
        Set_cluster
        Set_token
        Set_serverini
        Set_world
    else
        cluster_str="开启"
        Choose_exit_cluster
    fi
    echo "cluster=$cluster" > $server_conf_file
    if [ ! -f $dst_base_dir/$cluster/Master/modoverrides.lua ]; then
        Default_mod
    fi
    Set_list
    echo -e "\e[92m请选择要启动的世界：1.仅地上  2.仅洞穴  3.地上 + 洞穴 ?\e[0m\c"
    read shard 
    case $shard in
        1)		
        shard="Master";;
        2)
        shard="Caves";;
        *)
        shard="Master Caves";;
    esac
    echo "shard=$shard" >> $server_conf_file
    Run_server
}
Choose_exit_cluster(){
    echo -e "\e[92m已有存档：\e[0m"
    ls -l $dst_base_dir | awk '/^d/ {print $NF}' > /tmp/dirlist.txt
    index=1
    for dirlist in $(cat /tmp/dirlist.txt); do
        echo "$index. $dirlist"
        let index++
    done 
    echo -e "\e[92m请输入你要$cluster_str的存档${Red_font_prefix}[编号]${Font_color_suffix}：\e[0m\c"
    read listnum
    cluster=$(cat /tmp/dirlist.txt | head -n $listnum | tail -n 1)
}
Close_server(){
    tip "正在关闭已开启的服务器（有的话） ..."
    if tmux has-session -t DST_Master > /dev/null 2>&1 || tmux has-session -t DST_Caves > /dev/null 2>&1; then
        if tmux has-session -t DST_Master > /dev/null 2>&1; then
            tmux send-keys -t DST_Master "c_shutdown(true)" C-m
        fi
        sleep 3
        if tmux has-session -t DST_Caves > /dev/null 2>&1; then
            tmux send-keys -t DST_Caves "c_shutdown(true)" C-m
        fi
        sleep 5
        info "服务器已关闭！"
    else
        sleep 5
        info "服务器未开启！"
    fi
    exchangestatus false
}
Exit_auto_update(){
    if tmux has-session -t Auto_update > /dev/null 2>&1; then
        tmux kill-session -t Auto_update > /dev/null 2>&1
    fi
    info "自动更新进程已停止运行 ..."
}
Set_cluster(){
    while (true); do
        clear
        echo -e "\e[92m=============【存档槽：$cluster】===============\e[0m"
        index=1
        cat $dst_cluster_file | grep -v "script_ver" | while read line; do
            ss=($line)
            if [ "${ss[4]}" != "readonly" ]; then
                if [ "${ss[4]}" == "choose" ]; then
                    for ((i=5;i<${#ss[*]};i++)); do
                        if [ "${ss[$i]}" == "${ss[1]}" ]; then
                            value=${ss[$i+1]}
                        fi
                    done
                else
                    value=${ss[1]}
                fi
                echo -e "\e[33m[$index] ${ss[2]}：$value\e[0m"
            fi
            index=$[$index + 1]
        done
        echo -e "\e[92m===============================================\e[0m"
        cmd=""
        while (true); do
            if [[ $cmd == "" ]]; then
                read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
            else
                break
            fi
        done
        case $cmd in
            0)
            info "更改已保存！"
               break;;
            *)
            changelist=($(sed -n "${cmd}p" $dst_cluster_file))
               if [ "${changelist[4]}" = "choose" ]; then
                   echo -e "\e[92m请选择${changelist[2]}： \e[0m\c"
                   index=1
                   for ((i=5;i<${#changelist[*]};i=$i+2)); do
                       echo -e "\e[92m$index.${changelist[$[$i + 1]]}\e[0m\c"
                       index=$[$index + 1]
                   done
                   echo -e "\e[92m: \e[0m\c"
                   read changelistindex
                   listnum=$[$changelistindex - 1]*2
                   changelist[1]=${changelist[$[$listnum + 5]]}
               else
                   echo -e "\e[92m请输入${changelist[2]}(请不要输入空格)：\e[0m\c"
                   read changestr
                   changelist[1]=$changestr
               fi
               changestr="${changelist[@]}"
               sed -i "${cmd}c $changestr" $dst_cluster_file;;
        esac
    done
    type=([GAMEPLAY] [NETWORK] [MISC] [SHARD])
    for ((i=0;i<${#type[*]};i++)); do
        echo "${type[i]}" >> $dst_base_dir/$cluster/cluster.ini
        cat $dst_cluster_file | grep -v "script_ver" | while read lc; do
            lcstr=($lc)
            if [ "${lcstr[3]}" == "${type[i]}" ]; then
                if [ "${lcstr[1]}" == "无" ]; then
                    lcstr[1]=""
                fi
                echo "${lcstr[0]}=${lcstr[1]}" >> $dst_base_dir/$cluster/cluster.ini
            fi
        done
        echo "" >> $dst_base_dir/$cluster/cluster.ini
    done
}
Set_token(){
    if [ -f $dst_token_file ]; then
        default_token=$(cat $dst_token_file)
    else
        default_token="pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE="
    fi
    info "当前预设的服务器令牌：\n $default_token"
    read -p "是否更改？1.是 2.否" ch
    if [ $ch -eq 1 ]; then
        tip "请输入或粘贴你的令牌到此处，注意最后不要输入空格："
        read mytoken
        echo $mytoken > $dst_token_file
        info "已更改服务器默认令牌！"
    else
        echo $default_token >$dst_token_file
    fi
    cat $dst_token_file > $dst_base_dir/$cluster/cluster_token.txt
}
Set_list(){
    if [ ! -f $data_dir/alist.txt ]; then touch $data_dir/alist.txt; fi
    if [ ! -f $data_dir/blist.txt ]; then touch $data_dir/blist.txt; fi
    if [ ! -f $data_dir/wlist.txt ]; then touch $data_dir/wlist.txt; fi
    cat $data_dir/alist.txt > $dst_base_dir/$cluster/adminlist.txt
    cat $data_dir/blist.txt > $dst_base_dir/$cluster/blocklist.txt
    cat $data_dir/wlist.txt > $dst_base_dir/$cluster/whitelist.txt
}
Set_serverini(){
    cat $data_dir/masterini.ini > $dst_base_dir/$cluster/Master/server.ini
    cat $data_dir/cavesini.ini > $dst_base_dir/$cluster/Caves/server.ini
}
Set_world(){
    info "是否修改地上世界配置？：1.是 2.否（默认为上次配置）"
    read wc
    configure_file="$data_dir/masterleveldata.txt"
    data_file="$dst_base_dir/$cluster/Master/leveldataoverride.lua"
    if [ $wc -ne 2 ]; then
        Set_world_config
    fi
    Write_in master
    info "是否修改洞穴世界配置？：1.是 2.否（同上）"
    read cw
    configure_file="$data_dir/cavesleveldata.txt"
    data_file="$dst_base_dir/$cluster/Caves/leveldataoverride.lua"
    if [ $cw -ne 2 ]; then
        Set_world_config
    fi
    Write_in caves
}
Set_world_config(){
    while (true); do
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
        for ((j=0;j<${#list[*]};j++)); do
            echo -e "\n\e[92m${liststr[$j]}\e[0m"
            cat $configure_file | grep -v "script_ver" | while read line; do
                ss=($line)
                if [ ${#ss[@]} -gt 4 ]; then
                    if [ $index -gt 3 ]; then
                        printf "\n"
                        index=1
                    fi
                    for ((i=4;i<${#ss[*]};i++)); do
                        if [ "${ss[$i]}" == "${ss[1]}" ]; then
                            value=${ss[$i+1]}
                        fi
                    done
                    if [ "${list[$j]}" == "${ss[2]}" ]; then
                        printf "%-21s\t" "[$linenum]${ss[3]}: $value"
                        index=$[$index + 1]
                    fi
                fi
                linenum=$[$linenum + 1]
            done
        done
        printf "\n"
        cmd=""
        while (true); do
            if [[ $cmd == "" ]]; then
                read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
            else
                break
            fi
        done
        case $cmd in
            0)
            info "更改已保存！"
            break;;
            *)
            changelist=($(sed -n "${cmd}p" $configure_file))
               echo -e "\e[92m请选择${changelist[3]}： \e[0m\c"
               index=1
               for ((i=4;i<${#changelist[*]};i=$i+2)); do
                   echo -e "\e[92m$index.${changelist[$[$i + 1]]}\e[0m\c"
                   index=$[$index + 1]
               done
               echo -e "\e[92m: \e[0m\c"
               read changelistindex
               listnum=$[$changelistindex - 1]*2
               changelist[1]=${changelist[$[$listnum + 4]]}
               changestr="${changelist[@]}"
               sed -i "${cmd}c $changestr" $configure_file;;
        esac
    done
}
Write_in(){
    data_num=$[$(grep -n "^" $configure_file | tail -n 1 | cut -d : -f1) - 1]
    cat "$data_dir/${1}start.lua" > $data_file
    index=1
    cat $configure_file | grep -v "script_ver" | while read line; do
        ss=($line)
        if [ $index -lt $data_num ]; then
            char=","
        else
            char=""
        fi
        index=$[$index + 1]
        if [[ ${ss[1]} == "highlyrandom" ]]; then
            str="${ss[0]}=\"highly random\"$char"
        else
            str="${ss[0]}=\"${ss[1]}\"$char"
        fi
        echo "    $str" >> $data_file
    done
    cat "$data_dir/${1}end.lua" >> $data_file
}
Default_mod(){
    echo 'return {
-- 别删这个
["DONOTDELETE"]={ configuration_options={  }, enabled=true }
}' > $dst_base_dir/$cluster/Master/modoverrides.lua
    echo 'return {
-- 别删这个
["DONOTDELETE"]={ configuration_options={  }, enabled=true }
}' > $dst_base_dir/$cluster/Caves/modoverrides.lua	
}
Setup_mod(){
    touch $data_dir/mods_setup.lua
    dir=$(cat $dst_base_dir/$cluster/Master/modoverrides.lua | grep "workshop" | cut -f2 -d '"' | cut -d "-" -f2)
    for moddir in $dir; do
        if [[ $(grep "$moddir" -c "$data_dir/mods_setup.lua") = 0 ]]; then 
            echo "ServerModSetup(\"$moddir\")" >> "$data_dir/mods_setup.lua"
        fi
    done
    cp "$data_dir/mods_setup.lua" "$dst_server_dir/mods/dedicated_server_mods_setup.lua"
}
Start_shard(){
    Setup_mod
    cd "$dst_server_dir/bin"
    for s in $shard; do
        tmux new-session -s DST_$s -d "$dst_bin_cmd -cluster $cluster -shard $s"
    done
}
Start_check(){
    masterserverlog_path="$dst_base_dir/$cluster/Master/server_log.txt"
    cavesserverlog_path="$dst_base_dir/$cluster/Caves/server_log.txt"
    echo "" > $masterserverlog_path
    echo "" > $cavesserverlog_path
    while (true); do
        if tmux has-session -t DST_Master > /dev/null 2>&1 && tmux has-session -t DST_Caves > /dev/null 2>&1; then
            if [[ $(grep "Sim paused" -c "$masterserverlog_path") > 0 ]]; then
                echo "服务器开启成功，和小伙伴尽情玩耍吧！"
                break
            fi
            if [[ $(grep "Your Server Will Not Start" -c "$masterserverlog_path") > 0 ]]; then
                echo "服务器开启未成功，请执行关闭服务器命令后再次尝试，并注意令牌是否成功设置且有效。"
                break
            fi
        fi
        if tmux has-session -t DST_Master > /dev/null 2>&1 && ! tmux has-session -t DST_Caves > /dev/null 2>&1; then
            if [[ $(grep "Sim paused" -c "$masterserverlog_path") > 0 ]]; then
                echo "服务器开启成功，和小伙伴尽情玩耍吧！"
                break
            fi
            if [[ $(grep "Your Server Will Not Start" -c "$masterserverlog_path") > 0 ]]; then
                echo "服务器开启未成功，请执行关闭服务器命令后再次尝试，并注意令牌是否成功设置且有效。"
                break
            fi
        fi	
        if ! tmux has-session -t DST_Master > /dev/null 2>&1 && tmux has-session -t DST_Caves > /dev/null 2>&1; then
            if [[ $(grep "Sim paused" -c "$cavesserverlog_path") > 0 ]]; then
                echo "服务器开启成功，和小伙伴尽情玩耍吧！"
                break
            fi
            if [[ $(grep "Your Server Will Not Start" -c "$cavesserverlog_path") > 0 ]]; then
                echo "服务器开启未成功，请执行关闭服务器命令后再次尝试，并注意令牌是否成功设置且有效。"
                break
            fi
        fi	
    done 
}
#############################################################################
First_run_check(){
if [ ! -f $dst_server_dir/version.txt ]; then
        info "检测到你是首次运行脚本，需要进行必要的配置，所需时间由服务器带宽决定，大概一个小时 ..."
        Check_sys
        Open_swap
        Mkdstdir
        Install_Dependency
        Install_Steamcmd
        info "安装游戏服务端 ..."
        Install_Game
        Fix_steamcmd
        if [ ! -f $dst_server_dir/version.txt ]; then
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
    mkdir -p $HOME/steamcmd
    mkdir -p $dst_server_dir
    mkdir -p $DST_conf_basedir/$DST_conf_dirname
    mkdir -p $data_dir
}
# 检查当前系统信息
Check_sys(){
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
    if [[ $release != "ubuntu" && $release != "debian" && $release != "centos" ]]; then
        error "很遗憾！本脚本暂时只支持Debian7+和Ubuntu12+和CentOS7+的系统！" && exit 1
    fi
    bit=`uname -m`
}
# 安装依赖库和必要软件
Install_Dependency(){
    info "安装DST所需依赖库及软件 ..."
    if [[ $release != "centos" ]]; then
        if [[ ${bit} = "x86_64" ]]; then
            sudo dpkg --add-architecture i386
                sudo apt update
                sudo apt install -y lib32gcc1 libstdc++6 libstdc++6:i386 libcurl4-gnutls-dev:i386 tmux wget lua5.2
        else
             sudo apt update   
            sudo apt install -y libstdc++6 libcurl4-gnutls-dev tmux wget lua5.2
        fi
    else
        if [[ ${bit} = "x86_64" ]]; then
            sudo yum install -y tmux glibc.i686 libstdc++ libstdc++.i686 libcurl.i686 wget lua5.2
        else
            sudo yum install -y wget tmux libstdc++ libcurl lua5.2
        fi
     fi
}
# Install steamcmd
Install_Steamcmd(){
    wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" 
    tar -xzvf steamcmd_linux.tar.gz -C $HOME/steamcmd
    chmod +x $HOME/steamcmd/steamcmd.sh
    rm steamcmd_linux.tar.gz
}
# Install DST Dedicated Server
Install_Game(){
    cd $HOME/steamcmd || exit 1
    ./steamcmd.sh +login "anonymous" +force_install_dir "$dst_server_dir" +app_update "343050" validate +quit
}
# 修复SteamCMD [S_API FAIL] SteamAPI_Init() failed;
Fix_steamcmd(){
    info "修复Steamcmd可能存在的依赖问题 ..."
    mkdir -p "${HOME}/.steam/sdk32"
    cp -v $HOME/steamcmd/linux32/steamclient.so "${HOME}/.steam/sdk32/steamclient.so"
    # fix lib for centos
    if [[ $release == "centos" ]] && [ ! -f "$dst_server_dir/bin/lib32/libcurl-gnutls.so.4" ]; then
        info "libcurl-gnutls.so.4 missing...create a lib link."
        ln -s "/usr/lib/libcurl.so.4" "$dst_server_dir/bin/lib32/libcurl-gnutls.so.4"
    fi
}
##########################################################################
# Show change log
Show_changelog(){
    echo -e "\e[33m==============================脚本更新说明======================================\e[0m"
    curl -s ${update_link}/dstscript/changelog.txt > /tmp/changelog.txt
    datelog=$(cat /tmp/changelog.txt | head -n 1)
    cat /tmp/changelog.txt | grep -A 20 "更新日志 $datelog"
    echo -e "\e[33m================================================================================\e[0m"
    sleep 3
}
# 脚本更新
Update_script(){
    curl -s ${update_link}/dstscript/filelist.txt > /tmp/filelist.txt
    for file in $(cat /tmp/filelist.txt | cut -d ":" -f1); do
        new_ver=$(cat /tmp/filelist.txt | grep "$file" | cut -d ":" -f2)
        if [[ "$file" != "dstserver.sh" ]]; then file="dstscript/$file"; fi
        if [ -f $HOME/$file ]; then
            cur_ver=$(cat $HOME/$file | grep "script_ver=" | head -n 1 | cut -d '"' -f2)
        else
            cur_ver="000"
        fi
        [[ -z ${new_ver} ]] && new_ver=$cur_ver
        if [[ ${new_ver} != ${cur_ver} ]]; then
            info "$file 发现新版本[ ${new_ver} ]，更新中..."
            wget ${update_link}/$file -O $HOME/$file > /dev/null 2>&1
            chmod +x $HOME/dstserver.sh
            info "$file 已更新为最新版本[ ${new_ver} ] !"
            if [[ "$file" == "dstserver.sh" ]]; then need_exit="true"; fi
            need_update="true"
        fi
    done
    if [[ "$need_update" == "true" ]]; then Show_changelog; fi
    if [[ "$need_exit" == "true" ]]; then
        tmux kill-session -t Auto_update > /dev/null 2>&1
        tip "因脚本已更新，自动更新进程已退出，如需要请重新开启！"
        exit 0
    fi
}
# MOD update check
Update_DST_MOD(){
    info "检查启用的创意工坊MOD是否有更新 ..."
    for modid in $(cat $data_dir/mods_setup.lua | grep "ServerModSetup" | cut -d '"' -f2); do
        mod_new_ver=$(curl -s ${mod_api_link}?modid=$modid)
        if [ -f $dst_server_dir/mods/workshop-$modid/modinfo.lua ]; then
            echo "fuc=\"getver\"" > $data_dir/modinfo.lua
            cat $dst_server_dir/mods/workshop-$modid/modinfo.lua >> $data_dir/modinfo.lua
            cd $data_dir
            mod_cur_ver=$(lua modconf.lua)
        else
            mod_cur_ver=$mod_new_ver
        fi
        if [[ $mod_cur_ver != "" && $mod_new_ver != "" && $mod_new_ver != "nil" && $mod_cur_ver != $mod_new_ver ]]; then
            info "MOD 有更新($modid[$mod_cur_ver ==> $mod_new_ver])，即将重启更新 ..."
            Reboot_server
            break
        fi
    done
}
Status_keep(){
    for shard in $(grep "shard" $server_conf_file | cut -d "=" -f2); do
        if ! tmux has-session -t DST_$shard > /dev/null 2>&1; then
            server_alive=false
            break
        else
            server_alive=true
        fi
    done
    if [[ $(grep "serveropen" $server_conf_file | cut -d "=" -f2) == "true" &&  $server_alive == "false" ]]; then
        tip "服务器异常退出，即将重启 ..."
        Reboot_server
    fi
}
Simple_server_status(){
    cluster="无"
    [ -f ${server_conf_file} ] && cluster=$(cat $server_conf_file | grep "^cluster" | cut -d "=" -f2)
    if tmux has-session -t DST_Master > /dev/null 2>&1; then 
        master_on="开启"
    else
        master_on="关闭"
    fi
    if tmux has-session -t DST_Caves > /dev/null 2>&1; then
        caves_on="开启"
    else
        caves_on="关闭"
    fi
    cluster_name="无"
    [ -f $dst_base_dir/$cluster/cluster.ini ] && cluster_name=$(cat $dst_base_dir/$cluster/cluster.ini | grep "^cluster_name" | cut -d "=" -f2)
    echo -e "\e[33m存档:【$cluster】 地面:【$master_on】 洞穴:【$caves_on】 名称:【$cluster_name】\e[0m"
}
Fix_Net_hosts(){
    sudo chmod 666 /etc/hosts
    if ! grep steamusercontent-a.akamaihd.net /etc/hosts > /dev/null 2>&1; then
        echo "72.246.103.17 steamusercontent-a.akamaihd.net" >> /etc/hosts
    fi
    if ! grep s3.amazonaws.com /etc/hosts > /dev/null 2>&1; then
        echo "52.216.136.5 s3.amazonaws.com" >> /etc/hosts
    fi
    sudo chmod 644 /etc/hosts
}
####################################################################################
if [[ $1 == "au" ]]; then
    while (true); do
        Update_DST
        Update_DST_MOD
        Status_keep
        info "每半小时进行一次更新检测。。。"
        sleep 1800
    done
fi
# Run from here
First_run_check
Fix_Net_hosts
Update_script
Update_DST_Check
Menu
