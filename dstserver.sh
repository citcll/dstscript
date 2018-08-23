#!/bin/bash
#===============================================================================
#    System Required: Ubuntu12+/Debian7+
#    Description: Install and manager the Don't Starve Together Dedicated Server
#    Version: 1.1.9 2018-08-22 22:49:02
#    Author: Ariwori
#    Blog: https://wqlin.com/blog/dstscript.html
#===============================================================================
script_ver="1.1.9"
dst_conf_dirname="DoNotStarveTogether"   
dst_conf_basedir="$HOME/.klei"
dst_base_dir="$dst_conf_basedir/$dst_conf_dirname"
dst_server_dir="$HOME/DSTServer"
dst_bin_cmd="./dontstarve_dedicated_server_nullrenderer"
data_dir="$HOME/dstscript"
dst_token_file="$data_dir/clustertoken.txt"
server_conf_file="$data_dir/server.conf"
# 屏幕输出
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Yellow_font_prefix="\033[33m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"
info(){ echo -e "${Info} $1"}
tip(){ echo -e "${Tip} $1"}
error(){ echo -e "${Error} $1"}
# Main menu
Menu(){    
    while (true); do
	    echo -e "\e[33m==============欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]($script_ver)==============\e[0m"
        echo
		echo -e "\e[33m作者：Ariwori        Bug反馈：https://wqlin.com/blog/dstscript.html\e[0m"
		echo -e "\e[33m本脚本一切权利归作者所有。未经许可禁止使用本脚本进行任何的商业活动！\e[0m"
		echo
		echo -e "\e[31m游戏服务端安装目录：$dst_server_dir (Version: $game_ver)\e[0m"
		echo
        echo -e "\e[92m[1]启动服务器           [2]关闭服务器         [3]重启服务器\e[0m"  
        echo -e "\e[92m[4]查看服务器状态       [5]添加或移除MOD      [6]设置管理员和黑名单\e[0m"
		echo -e "\e[92m[7]控制台               [8]自动更新           [9]退出本脚本\e[0m"
		echo -e "\e[92m[10]删除存档            [11]更新游戏服务端/MOD\e[0m"
        echo
        echo -e "\e[33m================================================================================\e[0m"
        echo -e "\e[92m请输入命令代号：\e[0m\c"
        read cmd  
		case $cmd in
		    1)
            Start_server;;
			2)
            Close_server;;
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
Start_server(){
    info "本操作将会关闭已开启的服务器 ... Ctrl+C 中断操作 ..."
    sleep 3
    Close_server
    echo -e "\e[92m是否新建存档: [y|n] (默认: y): \e[0m\c"
	read yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		echo -e "\e[92m请输入新建存档名称：（不要包含中文、符号和空格）\e[0m"
        read cluster
		if [ ! -d "$dst_base_dir/$cluster" ]; then 
		    mkdir -pv $dst_base_dir/$cluster
	    fi
		Set_cluster
		Set_token
		Default_list
		Set_serverini
		Set_world
    else
        echo -e "\e[92m已有存档：\e[0m"
		ls -l $dst_base_dir | awk '/^d/ {print $NF}' > /tmp/dirlist.txt
        index=1
        for dirlist in $(cat /tmp/dirlist.txt); do
            echo "$index. $dirlist"
            let index++
        done 
		echo -e "\e[92m请输入你要开启的存档编号：\e[0m\c"
		read listnum
		cluster=$(cat /tmp/dirlist.txt | head -n $listnum | tail -n 1)
    fi
    echo "cluster=$cluster" > $server_conf_file
    mkdir -pv $dst_base_dir/$cluster/Master
    mkdir -pv $dst_base_dir/$cluster/Caves
	if ! find $dst_base_dir/$cluster -name modoverrides.lua > /dev/null 2>&1; then
        Default_mod
    fi
    Setup_mod
    cp "$data_dir/mods_setup.lua" "$dst_server_dir/mods/dedicated_server_mods_setup.lua"	
	cd "$dst_server_dir/bin"
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
	Start_shard
	info "服务器开启中。。。请稍候。。。"
	sleep 10
	Start_check
}
Close_server(){
    if tmux has-session -t DST_Master > /dev/null 2>&1 || tmux has-session -t DST_Caves > /dev/null 2>&1; then
	    if tmux has-session -t DST_Master > /dev/null 2>&1; then
            tmux send-keys -t DST_Master "c_shutdown(true)" C-m
	    fi
		sleep 3
	    if tmux has-session -t DST_Caves > /dev/null 2>&1; then
            tmux send-keys -t DST_Caves "c_shutdown(true)" C-m
	    fi
		sleep 1
		info "服务器已关闭！"
	else
		sleep 1
		info "服务器为未开启！"
	fi
    Exit_auto_update
}
Exit_auto_update(){
    if tmux has-session -t Auto_update > /dev/null 2>&1; then
        tmux kill-session -t Auto_update
	fi
    info "自动更新进程已停止运行 ..."
}
Set_cluster(){
    while (true); do
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
		read -p "请选择你要更改的选项(修改完毕输入数字 0 确认修改并退出)：" cmd
		case $cmd in
			0)
			info "更改已保存！"
   			break;;
			*)
            cmd=$[$cmd + 1]
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
Default_list(){
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
	if [ $wc -eq 1 ]; then
		configure_file="$data_dir/masterleveldata.txt"
		data_file="$dst_base_dir/$cluster/Master/leveldataoverride.lua"
		Set_world_cofig
        Write_in
	fi
	info "是否修改洞穴世界配置？：1.是 2.否（同上）"
	read cw
	if [ $cw -eq 1 ]; then
		configure_file="$data_dir/cavesleveldata.txt"
		data_file="$dst_base_dir/$cluster/Caves/leveldataoverride.lua"
		Set_world_config
        Write_in
	fi
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
			cmd=$[$cmd + 1]
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
	cat "$data_dir/masterstart.lua" > $data_file
	index=1
	cat $configure_file | grep -v "script_ver" | while read line; do
		ss=($line)
		if [ $index -lt $data_num ]; then
			char=","
		else
			char=""
		fi
		index=$[$index + 1]
		str="${ss[0]}=\"${ss[1]}\"$char"
		echo "$str" >> $data_file
	done
	cat "$data_dir/masterend.lua" >> $data_file
}
Default_mod(){

}
Setup_mod(){

}
Start_shard(){
    for s in $shard; do
		tmux new-session -s DST_$s -d "$DST_bin_cmd -cluster $cluster_name -shard $s"
	done
}
Start_check(){
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
#############################################################################
First_run_check(){
if [ ! -f $dst_server_dir/version.txt ]; then
        info "检测到你是首次运行脚本，需要进行必要的配置，大概一个小时 ..."
        Check_sys
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
# 创建文件夹
Mkdstdir(){
    mkdir -pv $HOME/steamcmd
	mkdir -pv $dst_server_dir
	mkdir -pv $DST_conf_basedir/$DST_conf_dirname
	mkdir -pv $data_dir
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
    wget "http://media.steampowered.com/client/steamcmd_linux.tar.gz" 
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
    mkdir -pv "${HOME}/.steam/sdk32"
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
		if [[ "$file" != "dstserver.sh" ]]; then file="dstscript/$file"; fi
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
		    if [[ "$file" == "dstserver.sh" ]]; then need_exit="true"; fi
    	fi
		Show_changelog
		if [[ "$need_exit" == "true" ]]; then
			tmux kill-session -t Auto_update
			tip "因脚本已更新，自动更新进程已退出，如需要请重新开启！"
			exit 0
		fi
    done
}
####################################################################################
# Run from here
First_run_check
Update_script
Menu