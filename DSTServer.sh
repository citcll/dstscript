#!/bin/bash
#-------------------------------------------------------------------------------------------
# Author：Ariwori 2018-06-29 00:10:49
#-------------------------------------------------------------------------------------------
script_ver="1.1.9"
DST_conf_dirname="DoNotStarveTogether"   
DST_conf_basedir="$HOME/.klei"
dst_base_dir="$DST_conf_basedir/$DST_conf_dirname"
DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer"
data_dir="$HOME/dstscript"
dst_token_file="$data_dir/clustertoken.txt"
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"
info(){ echo -e "${Info} $1"|tee -a run.log; }
tip(){ echo -e "${Tip} $1"|tee -a run.log; }
error(){ echo -e "${Error} $1"|tee -a run.log; }
# 第一次运行
first_run_check(){
    if [ ! -f $HOME/DSTServer/version.txt  ]; then
        info "检测到你是首次运行脚本，需要进行必要的配置，大概一个小时 ..."
        check_sys
        mkdstdir
        Install_Dependency
        Install_Steamcmd
        info "安装游戏服务端 ..."
        Install_Game
        fix_steamcmd
		if [ ! -f $HOME/DSTServer/version.txt ]; then
			error "安装失败，请重试！多次重试仍无效请反馈!" && exit 1
		fi
        info "首次运行配置完毕，你可以创建新的世界了。"
    fi
}
# 创建文件夹
mkdstdir(){
    mkdir -pv $HOME/steamcmd
	mkdir -pv $HOME/DSTServer
	mkdir -pv $DST_conf_basedir/$DST_conf_dirname
	mkdir -pv $data_dir
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
 	       	sudo apt install -y lib32gcc1 libstdc++6 libstdc++6:i386 libcurl4-gnutls-dev:i386 tmux wget
		else
		 	sudo apt update   
			sudo apt install -y libstdc++6 libcurl4-gnutls-dev tmux wget
		fi
	else
		if [[ ${bit} = "x86_64" ]]; then
			sudo yum install -y tmux glibc.i686 libstdc++ libstdc++.i686 libcurl.i686 wget
		else
			sudo yum install -y wget tmux libstdc++ libcurl
		fi
 	fi
}
# Install steamcmd
Install_Steamcmd(){
    wget "http://media.steampowered.com/client/steamcmd_linux.tar.gz" 
    tar -xzvf steamcmd_linux.tar.gz -C $HOME/steamcmd
    chmod +x $HOME/steamcmd/steamcmd.sh
    rm steamcmd_linux.tar.gz
}
# Install DST Dedicated Server
Install_Game(){
    cd $HOME/steamcmd || exit 1
    ./steamcmd.sh +login "anonymous" +force_install_dir "$HOME/DSTServer" +app_update "343050" validate +quit
}
# 修复SteamCMD [S_API FAIL] SteamAPI_Init() failed;
fix_steamcmd(){
    info "修复Steamcmd可能存在的依赖问题 ..."
    mkdir -pv "${HOME}/.steam/sdk32"
    cp -v $HOME/steamcmd/linux32/steamclient.so "${HOME}/.steam/sdk32/steamclient.so"
	# fix lib for centos
	if [[ $release == "centos" ]] && [ ! -f "$HOME/DSTServer/bin/lib32/libcurl-gnutls.so.4" ]; then
		info "libcurl-gnutls.so.4 missing...create a lib link."
		ln -s "/usr/lib/libcurl.so.4" "$HOME/DSTServer/bin/lib32/libcurl-gnutls.so.4"
	fi
}
##########################################################################
# 更新游戏服务端
Update_DST_Check(){
    appmanifestfile=$(find "$HOME/DSTServer" -type f -name "appmanifest_343050.acf")
    currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)
    cd $HOME/steamcmd || exit
    availablebuild=$(./steamcmd.sh +login "anonymous" +app_info_update 1 +app_info_print 343050 +app_info_print 343050 +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
    if [ "${currentbuild}" != "${availablebuild}" ]; then
        info "更新可用(${currentbuild}===>${availablebuild}！即将执行更新..."
		dst_need_update=true
		closeserver
		Install_Game
    else
        tip "无可用更新！当前Steam构建版本（$currentbuild）"
		dst_need_update=false
    fi
}
Update_DST(){
	if tmux has-session -t DST_Master > /dev/null 2>&1 || tmux has-session -t DST_Caves > /dev/null 2>&1; then
		serveropen=true
	fi
	Update_DST_Check
	if [[ $serveropen == "true" && dst_need_update == "true" ]]; then
		rebootserver
	fi
}
function setupmod()
{
    echo "ServerModSetup(\"1301033176\")
" >> "$dst_base_dir/mods_setup.lua"
    dir=$(ls -l "$HOME/DSTServer/mods" |awk '/^d/ {print $NF}'|grep "workshop"|cut -f2 -d"-")
    for modid in $dir
    do
	    if [[ $(grep "$modid" -c "$dst_base_dir/mods_setup.lua") > 0 ]] ;then 
		    echo "" >> "$dst_base_dir/mods_setup.lua"
		else	
            echo "ServerModSetup(\"$modid\")" >> "$dst_base_dir/mods_setup.lua"
		fi
    done	
}

function closeserver()
{
    if tmux has-session -t DST_Master > /dev/null 2>&1 || tmux has-session -t DST_Caves > /dev/null 2>&1; then
	    if tmux has-session -t DST_Master > /dev/null 2>&1; then
            tmux send-keys -t DST_Master "c_shutdown(true)" C-m
	    fi
		sleep 3
	    if tmux has-session -t DST_Caves > /dev/null 2>&1; then
            tmux send-keys -t DST_Caves "c_shutdown(true)" C-m
	    fi
		sleep 1
		echo -e "\e[92m服务器已关闭！\e[0m"
	else
		sleep 1
		echo -e "\e[92m服务器为未开启！\e[0m"
	fi
}
Set_token(){
	if [ -f $dst_token_file ]; then
		default_token=$(cat $dst_token_file)
	else
		default_token="pds-g^KU_6yNrwFkC^9WDPAGhDM9eN6y2v8UUjEL3oDLdvIkt2AuDQB2mgaGE="
	fi
	info "当前预设的服务器令牌：$default_token"
	read -p "是否更改？1.是 2.否" ch
	if [ $ch -eq 1 ]; then
		warming "请输入或粘贴你的令牌到此处，注意最后不要输入空格："
		read mytoken
		echo $mytoken > $dst_token_file
		info "已更改服务器默认令牌！"
	else
		echo $default_token >$dst_token_file
	fi
	cat $dst_token_file > $dst_base_dir/$cluster/cluster_token.txt
}
Set_serverini(){
	cat $data_dir/masterini.ini > $dst_base_dir/$cluster/Master/server.ini
	cat $data_dir/cavesini.ini > $dst_base_dir/$cluster/Caves/server.ini
}
Set_list_file(){
	cat $data_dir/alist.txt > $dst_base_dir/$cluster/adminlist.txt
	cat $data_dir/blist.txt > $dst_base_dir/$cluster/blocklist.txt
	cat $data_dir/wlist.txt > $dst_base_dir/$cluster/whitelist.txt
}
function Start_server()
{
    if [ ! -d "$dst_base_dir" ]; then 
		mkdir -pv $dst_base_dir
	fi
	closeserver
    echo -e "\e[92m是否新建存档：1.是  2.否\e[0m"
	read isnew
	case $isnew in
	    1)
		echo -e "\e[92m请输入存档名称：（不要包含中文）\e[0m"
		read clustername
		cluster=$clustername
		if [ ! -d "$dst_base_dir/$cluster" ]; then 
		    mkdir -pv $dst_base_dir/$cluster
	    fi
		Set_cluster
		Set_token
		Set_list_file
		Set_serverini
		Set_world
		setworld
		echo -e "\e[92m是否设置管理员、黑名单和白名单：1.是  2.否\e[0m"
		read setlist
		case $setlist in  
		    1)
			listmanager;;
		esac
		;;
		2)
		echo -e "\e[92m已有存档：\e[0m"
		ls -l $dst_base_dir |awk '/^d/ {print $NF}'
		echo -e "\e[92m请输入已有存档名称：\e[0m"
		read clustername
		cluster=$clustername	
		;;
	esac
	echo "clustername=$cluster_name" > $HOME/dst.conf
	setupmod
	if [[ ! -f $dst_base_dir/$cluster_name/Master/modoverrides.lua ]]; then
		modadd
	    listallmod
        addmod
    fi
    cp "$dst_base_dir/mods_setup.lua" "$HOME/DSTServer/mods/dedicated_server_mods_setup.lua"	
	cd "$HOME/DSTServer/bin"
	echo -e "\e[92m请选择要启动的世界：1.仅地上  2.仅洞穴  3.地上 + 洞穴\e[0m"
	read shard 
	case $shard in
		1)		
		shard="Master"
		;;
		2)
		shard="Caves"
		;;
		3)
		shard="Master Caves"
		;;
	esac
	echo "shard=$shard" >> $HOME/dst.conf
	startshard
	echo -e "\e[92m服务器开启中。。。请稍候。。。\e[0m"
	sleep 10
	startcheck
	menu
}
function startshard(){
	for s in $shard; do
		tmux new-session -s DST_$s -d "$DST_bin_cmd -cluster $cluster_name -shard $s"
	done
}
function startcheck()
{
	masterserverlog_path="$dst_base_dir/$cluster/Master/server_log.txt"
	cavesserverlog_path="$dst_base_dir/$cluster/Caves/server_log.txt"
	echo "" > masterserverlog_path
	echo "" > cavesserverlog_path
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

function checkserver()
{    
	if tmux has-session -t DST_Master > /dev/null 2>&1 || tmux has-session -t DST_Caves > /dev/null 2>&1; then
	    echo -e "\e[92m即将跳转游戏服务器窗口，要退回本界面，在游戏服务器窗口按 ctrl+B　松开马上再按下　D　再执行脚本即可。\e[0m"
		sleep 3
	    if tmux has-session -t DST_Master > /dev/null 2>&1; then
	        tmux attach-session -t DST_Master
	    fi
	    if ! tmux has-session -t DST_Master > /dev/null 2>&1 && tmux has-session -t DST_Caves > /dev/null 2>&1; then
	        tmux attach-session -t DST_Caves
	    fi
	else
	    echo "游戏服务器未开启！"
		menu
	fi
}

function exitshell()
{
   clear
   cd $HOME
}
####################################################################\
# 房间设置
Set_cluster(){
	while (true); do
		echo -e "\e[92m=============【存档槽：$cluster】===============\e[0m"
		index=1
		cat $dst_cluster_file | while read line; do
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
		read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
		case $cmd in
			0)
			info "更改已保存！"
   			break;;
			*)
			changelist=($(sed -n "${cmd}p" $dst_cluster_file))
   			echo ${changelist[4]}
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
		cat $dst_cluster_file | while read lc; do
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
####################################################################
# 世界设置
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
			cat $configure_file | while read line; do
				ss=($line)
				if [ ${#ss[@]} -gt 4 ]; then
					if [ $index -lt 4 ]; then
						for ((i=4;i<${#ss[*]};i++)); do
							if [ "${ss[$i]}" == "${ss[1]}" ]; then
								value=${ss[$i+1]}
							fi
						done
						if [ "${list[$j]}" == "${ss[2]}" ]; then
							printf "%-21s\t" "[$linenum]${ss[3]}: $value"
							index=$[$index + 1]
						fi
					else
						printf "\n"
						index=1
					fi
				fi
				linenum=$[$linenum + 1]
			done
		done
		printf "\n"
		read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
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
Set_world(){
	info "是否修改地上世界配置？：1.是 2.否（默认为上次配置）"
	read wc
	if [ $wc -eq 1 ]; then
		configure_file="$data_dir/masterleveldata.txt"
		data_file="$dst_base_dir/$cluster/Master/leveldataoverride.lua"
		Set_world_cofig
	fi
	info "是否修改洞穴世界配置？：1是 2.否（同上）"
	read cw
	if [ $cw -eq 1 ]; then
		configure_file="$data_dir/cavesleveldata.txt"
		data_file="$dst_base_dir/$cluster/Caves/leveldataoverride.lua"
		Set_world_config
	fi

	cat "$data_dir/masterstart.lua" > $dst_base_dir/$cluster/Master/leveldataoverride.lua
	getin "$data_dir/masterleveldata.txt" "75" "Master"
	cat "$data_dir/masterend.lua" >> $dst_base_dir/$cluster/Master/leveldataoverride.lua

	cat "$data_dir/cavesstart.lua" > $dst_base_dir/$cluster/Caves/leveldataoverride.lua
	getin "$data_dir/cavesleveldata.txt" "46" "Caves"
	cat "$data_dir/cavesend.lua" >> $dst_base_dir/$cluster/Caves/leveldataoverride.lua
}
Write_in(){
	index=1
	cat $1 | while read line; do
		ss=($line)
		if [ $index -lt $2 ]; then
			char=","
		else
			char=""
		fi
		index=$[$index + 1]
		str="${ss[0]}=\"${ss[1]}\"$char"
		echo "$str" >> $dst_base_dir/$cluster/$3/leveldataoverride.lua
	done
}
########################################################################
function createlistfile()
{
    echo " " > $dst_base_dir/$cluster/adminlist.txt
	echo " " > $dst_base_dir/$cluster/whitelist.txt
	echo " " > $dst_base_dir/$cluster/blocklist.txt
}

function addlist()
{
    echo -e "\e[92m请输入你要添加的KLEIID（KU_XXXXXXX）：\e[0m"
	read kleiid
	if [[ $(grep "$kleiid" -c "$dst_base_dir/$cluster/$listfile") > 0 ]] ;then 
		echo -e "\e[92m名单已经存在！\e[0m"
	else
	    echo "$kleiid" >> $dst_base_dir/$cluster/$listfile
	    echo -e "\e[92m名单添加完毕！\e[0m"
    fi
}

function dellist()
{
    echo "=========================================================================="
	grep "$dst_base_dir/$cluster/$listfile" -e "KU"
	echo -e "\e[92m请输入你要移除的KLEIID（KU_XXXXXXX）：\e[0m"
	read kleiid
	if [[ $(grep "$kleiid" -c "$dst_base_dir/$cluster/$listfile") > 0 ]] ;then 
		sed -i "/$kleiid/d" $dst_base_dir/$cluster/$listfile
		echo -e "\e[92m名单已移除！\e[0m"
	else
	    echo -e "\e[92m名单不存在！\e[0m"
	fi
}

function listmanager()
{
	[[ -z $cluster_name ]] && echo -e "\e[92m已有存档：\e[0m" && ls -l $dst_base_dir | awk '/^d/ {print $NF}' && echo -e "\e[92m请输入要设置的存档：\e[0m" && read clustername && cluster_name=$clustername
    echo -e "\e[92m你要设置：1.管理员  2.黑名单  3.白名单\e[0m"
    read list
	case $list in
	    1)
		listfile="adminlist.txt"
		echo -e "\e[92m你要：1.添加管理员  2.移除管理员\e[0m"
		read addordel
		case $addordel in
		    1)
			addlist;;
		    2)
            dellist;;
        esac			
		;;
		2)
		listfile="blacklist.txt"
		echo -e "\e[92m你要：1.添加黑名单  2.移除黑名单\e[0m"
		read addordel
		case $addordel in
		    1)
			addlist;;
		    2)
            dellist;;
        esac
		;;
		3)
		listfile="whitelist.txt"
		echo -e "\e[92m你要：1.添加白名单  2.移除白名单\e[0m"
		read addordel
		case $addordel in
		    1)
			addlist;;
		    2)
            dellist;;
        esac
		;;
	esac
}

function listusedmod()
{
	
    for i in $(grep "workshop" "$dst_base_dir/$cluster_name/Master/modoverrides.lua" | cut -d '"' -f 2 | cut -d '-' -f 2)
    do
	    name=$(grep "$HOME/DSTServer/mods/workshop-$i/modinfo.lua" -e "name =" | cut -d '"' -f 2 | head -1)	
	    echo -e "\e[92m$i\e[0m-----------\e[33m$name\e[0m" 
    done
}

function listallmod()
{
    for i in $(ls -l "$HOME/DSTServer/mods" |awk '/^d/ {print $NF}' | cut -d '-' -f 2)
    do
        if [[ -f "$HOME/DSTServer/mods/workshop-$i/modinfo.lua" ]]; then
	        name=$(grep "$HOME/DSTServer/mods/workshop-$i/modinfo.lua" -e "name =" | cut -d '"' -f 2 | head -1)	
	        echo -e "\e[92m$i\e[0m----\e[33m$name\e[0m" 
	    fi
    done
}

function addmod()
{
	echo "请从以上列表选择你要启用的MODID，不存在直接输入9位数modid"
	echo -e "\e[31m只支持启用MOD，要具体配置在客机配置好上传配置文件即可\e[0m"
	echo "添加完毕请输入 0 ！"
	while :
	do
    read modid
	if [[ "$modid" = "0" ]]; then
	    echo "添加完毕 ！"
		break
	else
		if [[ $(grep "$modid" "$dst_base_dir/$cluster_name/Master/modoverrides.lua") > 0 ]]
		then 
			echo "地上世界该Mod已添加"
		else
			sed -i "2i [\"workshop-$modid\"]={ configuration_options={  }, enabled=true }," $dst_base_dir/$cluster_name/Master/modoverrides.lua
		    echo "地上世界Mod添加完成"
		fi
		if [[ $(grep "$modid" "$dst_base_dir/$cluster_name/Caves/modoverrides.lua") > 0 ]]
		then 
			echo "洞穴世界该Mod已添加"
		else
			sed -i "2i [\"workshop-$modid\"]={ configuration_options={  }, enabled=true }," $dst_base_dir/$cluster_name/Caves/modoverrides.lua
		    echo "洞穴世界Mod添加完成"
		fi
		echo "" >> "$dst_base_dir/mods_setup.lua"
        if [[ $(grep "$modid" -c "$dst_base_dir/mods_setup.lua") > 0 ]] ;then 
		    echo "" >> "$dst_base_dir/mods_setup.lua"
		else	
            echo "ServerModSetup(\"$modid\")" >> "$dst_base_dir/mods_setup.lua"
		fi	
    fi
    done 
}

function delmod()
{   
    echo "请从以上列表选择你要移除的MODID"
	echo "移除完毕请输入 0 ！"
    while :
	do
    read modid
	if [[ "$modid" == "0" ]]; then
	    echo "移除完毕！"
		break
	else
		if [[ $(grep "$modid" "$dst_base_dir/$cluster_name/Master/modoverrides.lua") > 0 ]]
		then 
			sed -i "/$modid/d" $dst_base_dir/$cluster_name/Master/modoverrides.lua
			echo "地上世界Mod移除完成"
		else
			echo "地上世界该Mod未添加"
		fi
		if [[ $(grep "$modid" "$dst_base_dir/$cluster_name/Caves/modoverrides.lua") > 0 ]]
		then 
			sed -i "/$modid/d" $dst_base_dir/$cluster_name/Caves/modoverrides.lua
			echo "洞穴世界Mod移除完成"
		else
			echo "洞穴世界该Mod未添加"
		fi 
    fi
	done
}

function modadd()
{    
    echo "return {
[\"workshop-1301033176\"]={ configuration_options={  }, enabled=true }
}" > $dst_base_dir/$cluster_name/Master/modoverrides.lua
	echo "return {
[\"workshop-1301033176\"]={ configuration_options={  }, enabled=true }
}" > $dst_base_dir/$cluster_name/Caves/modoverrides.lua	
}

function console()
{
    if tmux has-session -t DST_Master > /dev/null 2>&1; then 
	    echo "当前世界不是主世界，请在主世界所在服务器操作"
		menu
	fi
    echo -e "\e[92m已有存档：\e[0m"
	ls -l $dst_base_dir |awk '/^d/ {print $NF}'
	echo -e "\e[92m请输入当前开启的存档：\e[0m"
	read clustername
	cluster_name=$clustername	
    while :
    do
	    echo -e "\e[33m================欢迎使用饥荒联机版独立服务器脚本控制台==================\e[0m"
		echo
        echo -e "\e[92m[1]查看当前玩家         [2]踢出玩家           [3]禁止玩家\e[0m"  
        echo -e "\e[92m[4]禁止新玩家加入游戏   [5]允许新玩家加入游戏\e[0m"
		echo -e "\e[92m[6]返回主菜单           [7]重置远古废墟       [8]停止投票\e[0m"
		echo
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m"
        read cmd  
		    case $cmd in
				1)
				listallplayer
			    ;;	
                2)
				listallplayer
				echo "请输入你要踢出的玩家的KLEIID"
				read kleiid1
				tmux send-keys -t DST_Master "TheNet:Kick(%kleiid1)" C-m
				echo "玩家 $kleiid1 已被踢出游戏"
			    ;;	
                3)
				listallplayer
				echo "请输入你要禁止的玩家的KLEIID"
				read kleiid1
				tmux send-keys -t DST_Master "TheNet:Kick(%kleiid1)" C-m
				echo "玩家 $kleiid1 已被禁止加入游戏"
			    ;;	
                4)
				tmux send-keys -t DST_Master "TheNet:SetAllowIncomingConnections(false)" C-m
			    ;;
                5)
				tmux send-keys -t DST_Master "TheNet:SetAllowIncomingConnections(true)" C-m
			    ;;
                6)
				menu
				break
			    ;;	
                7)
				tmux send-keys -t DST_Master "c_resetruins()" C-m
			    ;;
                8)
				tmux send-keys -t DST_Master "c_stopvote" C-m
			    ;;				
		    esac
    done
}

function rebootannounce()
{
    if tmux has-session -t DST_Master > /dev/null 2>&1; then   									        
	    tmux send-keys -t DST_Master "c_announce(\"服务器因改动或更新需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
	fi
	if tmux has-session -t DST_Caves > /dev/null 2>&1; then						        
		tmux send-keys -t DST_Caves "c_announce(\"服务器设因改动或更新需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
	fi
}

function deldir()
{
    echo -e "\e[92m已有存档：\e[0m"
	ls -l $dst_base_dir |awk '/^d/ {print $NF}'
	echo -e "\e[92m请输入要删除的存档[请谨慎选择]：\e[0m"
	read clustername
	rm -rf $dst_base_dir/$clustername
	echo -e "\e[92m存档删除完毕！\e[0m"
}

function listallplayer()
{	
    playernumber=$( date +%s%3N )
	tmux send-keys -t DST_Master "c_printplayersnumber($playernumber)" C-m
	if [[ $( grep "$dst_base_dir/$clustername/Master/server_log.txt" -e "$playernumber" | cut -d ':' -f 6 ) > 0 ]]; then
	    sleep 3
		playerlist=$( date +%s%3N )
	   tmux send-keys -t DST_Master "c_printplayerlist($playerlist)" C-m
	    echo -e "\e[92m============================================================\e[0m"
        grep "$dst_base_dir/$clustername/Master/server_log.txt" -e "$playerlist" | cut -d ' ' -f 2-6 | tail -n +2
	    echo -e "\e[92m============================================================\e[0m"
	else
	    echo "没有玩家在服务器中！"
	fi
}

function openswap()
{
    sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
    sudo mkswap /swapfile
    sudo swapon /swapfile
	sudo chmod 0646 /etc/fstab
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
	clear
    echo -e "\e[92m虚拟内存已开启！\e[0m"
}
# reboot server
function rebootserver(){
	info "服务器重启中。。。请稍候。。。"
	cluster_name=$(cat $HOME/dst.conf|grep clustername|cut -d "=" -f2)
	shard=$(cat $HOME/dst.conf|grep shard|cut -d "=" -f2)
	startshard
	startcheck
}
# Show change log
Show_changelog(){
	echo -e "\e[33m=================================脚本更新说明========================================\e[0m"
	curl -s https://raw.githubusercontent.com/ariwori/dstscript/master/dstscript/changelog.txt > /tmp/changelog.txt
	datelog=$(cat /tmp/changelog.txt | head -n 1)
    cat /tmp/changelog.txt | grep -A 20 "$datelog"
	echo -e "\e[33m=====================================================================================\e[0m"
	sleep 3
}
# 脚本更新
Update_script(){
	curl -s https://raw.githubusercontent.com/ariwori/dstscript/master/dstscript/filelist.txt > /tmp/filelist.txt
    for file in $(cat /tmp/filelist.txt | cut -d ":" -f1); do
    	new_ver=$(cat /tmp/filelist.txt | grep "$file" | cut -d ":" -f2)
		if [[ "$file" != "DSTServer.sh" ]]; then file="dstscript/$file"; fi
		if [ -f $HOME/$file ]; then
			cur_ver=$(cat $HOME/$file | grep "script_ver" | cut -d '"' -f2)
		else
			cur_ver="000"
		fi
    	[[ -z ${new_ver} ]] && new_ver=$cur_ver
    	if [[ ${new_ver} != ${cur_ver} ]]; then
        	info "$file 发现新版本[ ${new_ver} ]，更新中..."
        	wget https://raw.githubusercontent.com/ariwori/dstscript/master/$file -O $HOME/$file
    		chmod +x $HOME/DSTServer.sh
        	info "$file 已更新为最新版本[ ${new_ver} ] !"
		    if [[ "$file" == "DSTServer.sh" ]]; then need_exit="true"; fi
    	fi
		Show_changelog
		if [[ "$need_exit" == "true" ]]; then
			tmux kill-session -t Auto_update
			tip "因脚本已更新，自动更新进程已退出，如需要请重新开启！"
			exit 0
		fi
}
# Main menu
function menu()
{    
    while :
    do
	    echo -e "\e[33m==============欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]($shell_ver)==============\e[0m"
        echo
		echo -e "\e[33m作者：Ariwori        Bug反馈：https://wqlin.com/blog/dstscript.html\e[0m"
		echo -e "\e[33m本脚本一切权利归作者所有。未经许可禁止使用本脚本进行任何的商业活动！\e[0m"
		echo
		echo -e "\e[31m首次使用请将本地电脑上的MOD上传到\e[0m"
		echo -e "\e[31m云服务器$HOME/DSTServer/mods目录下\e[0m"
		echo
        echo -e "\e[92m[1]启动服务器           [2]关闭服务器         [3]重启服务器\e[0m"  
        echo -e "\e[92m[4]查看游戏服务器状态   [5]添加或移除MOD      [6]设置管理员和黑名单\e[0m"
		echo -e "\e[92m[7]控制台               [8]自动更新           [9]退出本脚本\e[0m"
		echo -e "\e[92m[10]删除存档            [11]开启虚拟内存（单服务器开洞穴使用）\e[0m"
		echo -e "\e[92m[12]更新游戏服务端(MOD更新一般重启即可)       [13]更新脚本\e[0m"
		echo -e "\e[92m注：开启虚拟内存只需执行一次\e[0m"
        echo
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m"
        read cmd  
		    case $cmd in
			    1)startserver
				break;;
			    2)closeserver
				menu
                break;;
				3)rebootannounce
				sleep 10
				closeserver				
				rebootserver
				menu
				break;;
			    4)checkserver
			    break;;	
                5)echo -e "\e[92m设置完成后，须重启服务器才会生效。\e[0m"
				echo -e "\e[92m已有存档：\e[0m"
	            ls -l $dst_base_dir |awk '/^d/ {print $NF}'
	            echo -e "\e[92m请输入要设置的存档：\e[0m"
	            read clustername
	            cluster_name=$clustername
				echo -e "\e[92m你要：1.添加Mod  2.移除Mod\e[0m"
                read modad
	            case $modad in
	                1)
					listallmod
					addmod;;
					2)
					listusedmod
					delmod;;
				esac
				menu
			    break;;
                6)echo -e "\e[92m设置完成后，须重启服务器才会生效。\e[0m"
				listmanager
				menu
			    break;;	
				7)
				console
			    break;;	
                8)
				if tmux has-session -t Auto_update > /dev/null 2>&1; then
					info "自动更新进程已在运行，即将跳转。。。退出请按Ctrl + B松开再按D"
					sleep 3
					tmux attach-session -t Auto_update
				else
					tmux new-session -s Auto_update -d "./DSTServer.sh au"
					info "自动更新已开启！"
				fi
				menu
			    break;;
				9)
				exitshell
			    break;;	
                10)
				deldir
				menu
			    break;;	
                11)
				openswap
				menu
			    break;;
				12)
				Update_DST
				menu
				break;;
				13)
				Update_shell
				menu
				break;;			
		    esac
    done
}
if [[ $1 == "au" ]]; then
	while(true); do
		Update_DST
		info "每十分钟进行一次更新检测。。。"
		sleep 600
	done
fi
first_run_check
Update_script
menu
