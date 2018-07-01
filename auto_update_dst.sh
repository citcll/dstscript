#/bin/bash
#=======================================================================================================================
#
#相关说明：(本来是不想写的，代码里出现中文是真难受，还有脚本里的游戏公告，没办法应国人习惯)
#          原脚本来源于Klei论坛，原脚本信息未作改动，具体自己看
#          脚本可实现游戏服务端和mod自动更新（包括智能更新和强制更新），进程维护
#脚本修复：修复由于新版游戏相关路径改动产生错误，修复自动更新算法
#脚本改动：增加控制台（console manager），其实也没写什么，因为发现没什么实用性，更多功能可以自己添加
#          增加服务端检测（start check），主要是解决偶尔自动更新重启后令牌会失效的问题
#          增加游戏端下载，首次使用不用再手动安装游戏服务端
#使用说明：root用户目录下，给予脚本执行权限，终端输入：sudo chmod 744 /root/auto_update_dst.sh
#          首次使用--执行本脚本出现Game running in screen ..., OK.字样后退到终端执行：sudo killall screen 
#          之后配置好相关文件（建议本地游戏客户端客服再上传，相关自行解决）再次执行脚本即可
#          脚本智能更新和控制台需配合mod--Servermanager（原作者脚本修改，已上传创意工坊，自行搜索订阅）开服必须启用
#友情提醒：我提供的适合我当前用（双服务器：地上+地下），怎么开都是支持的，不过要改动
#          小白就不要看了，老司机自己DIY,不难
#          虽然不全是我的东西，也希望不要用于商业利益，请自重
#          有老司机会的，愿意的也可以给小白们写个教程，我比较懒就算了
#
#======================================================================================================================
# DST dedicated server auto-update script [Linux]
DST_updater_version=1.3
# Description:    Maintains DST servers up and up to date: game & workshop mods
#                  > Graceful shutdown: Restart when no players are online.
#                  > Forced shutdown (option): Restart between 3AM to 6AM server
#                     time with player prior announcement
# Author:         n01ce
# Credits:        jacklul
# Pre-requisites: DST Dedicated Server existing install
#                  > 500MB disk space, or 1GB if you have both a normal (non beta) server and a cavesbeta server
#                  > sudo apt-get install screen diffutils grep
# WARNING:        ORIGINAL GAME FILES AND WORKSHOP MOD FILES ARE OVERWRITTEN BY UPDATES, DO A BACKUP TO BE SAFE
#                  > modseetings.lua will be copied to modsettings.MASTER.lua at first launch.
#                  > You must then use this file and (as usual) "modsettings.lua" to configure mods.
# Recommended:    Graceful Shutdown mod : copy the mod folder in your game path "mods" folder
# Run:            To launch server 1 (SCREEN IS AUTOMATICALLY CREATED):
#                   ./auto_update_dst.sh 1
# Check status:   screen -ls
#                 screen -r SCREEN_NAME


# CONFIG : SERVER(S) : REQUIRED

DST_game_path[1]="/${USER}/Steam/steamapps/common/Don't Starve Together Dedicated Server"
DST_conf_dirname[1]="DoNotStarveServer_1" # Server configuration directory name located in /${USER}/.klei/
                                          # Avoid using comments in your cluster.ini.
DST_screen_name[1]="DST01"  # Game screen name, avoid using just "DST" if you have multiple servers.
                            # If possible, use only alphanumeric characters
                            # Your game server MUST be off or already running in this screen name.
                            #   If your game server is already running, check its current screen name with "screen -ls", otherwise choose what you want.
                            #   Note: Mod Graceful Shutdown needs a game server restart to load.
#DST_game_beta[1]="public" # Game beta branch to update. "public" for the production game, or game beta branch name (eg. "cavesbeta")
DST_game_beta[1]="public"
DST_allow_forced_shutdown[1]=true # Allow Forced Shutdown method (must be the same config for master and slave server (caves))

# If you have multiple servers...
#DST_game_path[2]="/${USER}/Steam/steamapps/common/Don't Starve Together Dedicated Server" # must be different for each server, except for the 2 servers that are master/slave (caves+main world)
#DST_conf_dirname[2]="DoNotStarveServer_2" # must be different for each server
#DST_screen_name[2]="DST02" # must be different for each server. use a unique pattern/keyword/number in each server screen name.
#DST_game_beta[2]="cavesbeta"
#DST_allow_forced_shutdown[2]=true
#
#DST_game_path[3]="/${USER}/steamapps/common/DST02"
#DST_conf_dirname[3]="DST02cave"
#DST_screen_name[3]="DST02cave"
#DST_game_beta[3]="cavesbeta"
#DST_allow_forced_shutdown[3]=true


# CONFIG : GLOBAL : REQUIRED

steamcmd_path="/${USER}/steamcmd" # Path to your existing steamcmd
DST_temp_path="/${USER}/temp/DST_Update_Check" # Temp. dir with 500MB-1GB free, will be created by script

# CONFIG : CUSTOMIZATION

restart_min_hour=3   # Start hour when script is allowed to perform a forced shutdown. 24hour format, local server time
restart_max_hour=6   # End hour when script is allowed to perform a forced shutdown. 24hour format, local server time
announce_period=1800 # Frequency of forced shutdown prior game c_announce()'s. 60*30 seconds = every 30 minutes

DST_backupchat=true # Chat log is INFINITE, max log age doesn't apply.
DST_backuplog=true  # Logs are backed-up after a reboot. Max log age applies.
DST_log_maxage=20   # Number of days before game logs are deleted.

DST_keepalive=300 # Time in seconds between game keepalive check (game is restared if not alive)
DST_updatecheckcycle=3600 # Time in seconds between game update check cycle (contact of steam servers)


# CONFIG : USE WITH EXTREME CAUTION

DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer" # Don't change the path, just add "LD_LIBRARY_PATH=~/dst_lib " if you need it (Debian 7)

DST_validate="validate" # "validate" or empty string ""
 # Validate: (recommended by Klei)
 #  > Game folder will be a perfect copy of the Steam game, i.e. stable
 #  > All changes to the original files in the game folder will be erased! (Non-original game files are OK)
 #  > -ONLY- use "dedicated_server_mods_setup.MASTER.lua" + "modsettings.MASTER.lua"
 #  > OR "dedicated_server_mods_setup.MASTER.lua" + "modoverrides.lua" (no master for the latest)
 # Empty: (recommended by Steam)
 #  > Game folder may become instable if you modify game files directly
 #  > All changes in the game folder "should" only be erased if updated by Steam
 #  > Use directly  "dedicated_server_mods_setup.lua" + "modsettings.lua" OR "dedicated_server_mods_setup.lua" + "modoverrides.lua"
DST_TEMP_validate="" # Same but applies to the game update temporary folder

DST_conf_basedir="/${USER}/.klei" # Don't change this without adding cmdline option -persistent_storage_root '${DST_conf_basedir}'

DST_base_cmdline_options="-console" # You should use your server cluster.ini instead.
                                    # This setting common to all servers.
                                    # Everything allowed except -conf_dir


# SCRIPT CODE
function PrepareLib()
{
	apt-get -y update
	apt-get -y install screen
	apt-get -y install lib32gcc1
	apt-get -y install lib32stdc++6
	apt-get -y install libcurl4-gnutls-dev:i386
	apt-get -y install htop
	apt-get -y install diffutils 
	apt-get -y install grep
}

function Prepare()
{
    if [ ! -d "./steamcmd" ];then
        PrepareLib
        mkdir ./steamcmd
        cd ./steamcmd
        wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
        tar -xvzf steamcmd_linux.tar.gz
        rm -f steamcmd_linux.tar.gz
        ./steamcmd.sh +login anonymous +app_update 343050 validate +quit
    fi
    cd "$HOME"
}

Prepare

if [[ "$1" == "screened" ]]; then
	SRVID=$2;
else
	SRVID=$1;
fi
if [ -z ${DST_conf_dirname[$SRVID]} ]; then
	SRVID=1
fi

DST_this_game_path=${DST_game_path[$SRVID]}
DST_this_conf_dirname=${DST_conf_dirname[$SRVID]}
DST_this_screen_name=${DST_screen_name[$SRVID]}
DST_this_game_beta=${DST_game_beta[$SRVID]}
DST_this_allow_forced_shutdown=${DST_allow_forced_shutdown[$SRVID]} # Allow Forced Shutdown method
DST_this_cmdline_options="${DST_base_cmdline_options} -conf_dir \"${DST_this_conf_dirname}\""

DST_array[$SRVID]=0
DST_array_num[$SRVID]=$SRVID
DST_array_game_path[$SRVID]=$DST_this_game_path # TODO: This and other could be simplified since =DST_game_path[$SRVID], just keep table DST_array
DST_array_conf_dirname[$SRVID]=$DST_this_conf_dirname
DST_array_screen_name[$SRVID]=$DST_this_screen_name
DST_array_game_beta[$SRVID]=$DST_this_game_beta
DST_array_allow_forced_shutdown[$SRVID]=$DST_this_allow_forced_shutdown
DST_array_cmdline_options[$SRVID]=$DST_this_cmdline_options

# Find if there's an other server linked to this one (cave+main world)
shard_with=0
this_master_port=$(awk -F "=" '/master_port/ {print $2}' "${DST_conf_basedir}/${DST_this_conf_dirname}/Cluster_1/cluster.ini" | tr -d ' ')
for sid in "${!DST_conf_dirname[@]}"
do
	master_port=$(awk -F "=" '/master_port/ {print $2}' "${DST_conf_basedir}/${DST_conf_dirname[$sid]}/Cluster_1/cluster.ini" | tr -d ' ')
	#echo "${DST_conf_basedir}/${DST_conf_dirname[$sid]}/Cluster_1/Master/cluster.ini"
	#echo "$this_master_port !=  && $this_master_port != $master_port && $sid != $SRVID"
	#sleep 2
	if [[ "$this_master_port" != "" && "$this_master_port" == "$master_port" && "$sid" != "$SRVID" ]]; then
		#echo "$this_master_port !=  && $this_master_port != $master_port && $sid != $SRVID"
		shard_with=$sid
		DST_shard_game_path=${DST_game_path[$shard_with]}
		DST_shard_conf_dirname=${DST_conf_dirname[$shard_with]}
		DST_shard_screen_name=${DST_screen_name[$shard_with]}
		DST_shard_game_beta=${DST_game_beta[$shard_with]}
		DST_shard_allow_forced_shutdown=DST_shard_allow_forced_shutdown=${DST_allow_forced_shutdown[$shard_with]} # Allow Forced Shutdown method
		DST_shard_cmdline_options="${DST_base_cmdline_options} -conf_dir \"${DST_shard_conf_dirname}\""

		DST_array[$shard_with]=1
		DST_array_num[$shard_with]=$shard_with
		DST_array_game_path[$shard_with]=$DST_shard_game_path
		DST_array_conf_dirname[$shard_with]=$DST_shard_conf_dirname
		DST_array_screen_name[$shard_with]=$DST_shard_screen_name
		DST_array_game_beta[$shard_with]=$DST_shard_game_beta
		DST_array_allow_forced_shutdown[$shard_with]=$DST_shard_allow_forced_shutdown
		DST_array_cmdline_options[$shard_with]=$DST_shard_cmdline_options
		break
	fi
done


#DST_conf_path=${DST_conf_basedir}"/"${DST_this_screen_name}
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
SCRIPTNAME=`basename $0`
SCRIPTHERE=$( pwd )


all_branches_to_sync=($(printf "%s\n" "${DST_game_beta[@]}" | sort -u))

# Update from v1.2 to v1.3
if [ -f "${DST_temp_path}/version.txt" ]; then
	#if [ ! -d "${DST_temp_path}/branch_public" ]; then
		echo -e "\e[93mINFO: Updating to version v1.3...\e[0m"
		echo -e "Stopping game update check routine..."
		screen -S "D_S_T_GAMECHECKROUTINE" -X quit
		echo -e "Moving temporary game dir in subfolder. Don't worry about the move warning."
		mkdir "${DST_temp_path}/branch_public"
		mv "${DST_temp_path}/"* "${DST_temp_path}/branch_public"
		echo -e "Continuing in 10 seconds..."
		sleep 10
	#fi
fi
#Check whether server started sucessful
function server_sucess_check {
   if find_screen "DST01" >/dev/null; then
        for sk in "${!DST_array[@]}" ; do
		    echo -e "Check whether server started sucessed per 120sec:"
		    if [[ $(grep "Your Server Will Not Start" -c "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt") > 0 ]]; then
			    screen -S "DST01" -p 0 -X stuff "c_shutdown()$(printf \\r)"
			    echo -e "\e[93mServer not started!\e[0m"
		    else
			    echo -e "\e[92mServer started sucessful.\e[0m"
		    fi
        done
	fi
  			
}
#Console Manager 
function console_manager {
 while true
    do
	    echo -e "\e[96m==================console meau=================\e[0m"
	    echo -e "\e[96m1.Restart server    2.List allplayers\e[0m"
        echo -e "\e[96m3.Resurrect allplayers\e[0m"
		echo -e "\e[96m4.Dumping world state\e[0m"
		echo -e "\e[96mYou can add cmd by youself\e[0m"
		echo -e "\e[96m===============================================\e[0m"
		randomness=$( date +%s%3N )
        read cmd
		clear
        case $cmd in
            1)
            for sk in "${!DST_array[@]}" ; do
					target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
					screen -S "$target_screen" -p 0 -X stuff "c_save()$(printf \\r)"
					sleep 3
					screen -S "$target_screen" -p 0 -X stuff "c_shutdown()$(printf \\r)"					
				done
            break;;
			 2)
            for sk in "${!DST_array[@]}" ; do
					target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
					screen -S "$target_screen" -p 0 -X stuff "c_printplayerslist(${randomness})$(printf \\r)"
					char=$(grep "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt" -e "${randomness}:ENDList" | cut -f2-5 -d " " )
					echo $char
				done
            break;;
			 3)
            for sk in "${!DST_array[@]}" ; do
					target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
					screen -S "$target_screen" -p 0 -X stuff "for k,v in pairs(AllPlayers) do v:PushEvent('respawnfromghost') end$(printf \\r)"					
				done
            break;;
			 4)
            for sk in "${!DST_array[@]}" ; do
					target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
					screen -S "$target_screen" -p 0 -X stuff "c_printseasons(${randomness})$(printf \\r)"
                    char=$(grep "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt" -e "${randomness}:ENDSeasons" | cut -f2-9 -d " " )
					echo $char					
				done
            break;;
        esac
    done
}

# Check for a game update
# Compare version.txt with a temporary full copy of the game (steamcmd has no option for partial game file download & steam API GetSchemaForGame doesn't work with DST)
# The copy is without "validate", so it uses disk space but no bandwidth (except when updates arises)
function update_temp_game {
	echo -e "Synchronization of game update temporary folder..."
	for branch in "${all_branches_to_sync[@]}"
	do	
		echo -e "Updating branch: \e[34m${branch}\e[90m"
		cd "${steamcmd_path}"
		beta_arg=""
		if [[ "$branch" != "public" ]]; then
			beta_arg="-beta ${branch}"
		fi
		./steamcmd.sh +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +force_install_dir "${DST_temp_path}/branch_${branch}" +app_update 343050 ${beta_arg} ${DST_TEMP_validate} +quit | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
		echo -e "\e[0mSynchronization done."
		echo "Locking & updating shared version file..."
		flock "${DST_temp_path}/branch_${branch}/version4updater.txt" -c "cp \"${DST_temp_path}/branch_${branch}/version.txt\" \"${DST_temp_path}/branch_${branch}/version4updater.txt\""
		echo "Unlocked shared version file."
	done
}

function find_screen {
	if screen -ls "$1" | grep -o "^\s*[0-9]*\.$1[ "$'\t'"](" --color=NEVER -m 1 | grep -oh "[0-9]*\.$1" --color=NEVER -m 1 -q >/dev/null; then
		screen -ls "$1" | grep -o "^\s*[0-9]*\.$1[ "$'\t'"](" --color=NEVER -m 1 | grep -oh "[0-9]*\.$1" --color=NEVER -m 1 2>/dev/null
		return 0
	else
		echo "$1"
		return 1
	fi
}

# Kill all updaters & game check routine
#if [ "$1" == "stop" ]; then
#	DST_SCREEN_PID=$( screen -ls "${iscreen}" | awk "/${iscreen}/"' { print $1 } ' | cut -f1 -d"." )

# Force this server game updater script & game check routing
if [[ "$1" == "check" || "$1" == "checknow" ]]; then

	HASERROR=false
	list="D_S_T_GAMECHECKROUTINE D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER D_S_T_UPDATER"   
		echo -e "Waking up all update check cycles of screens starting by D_S_T_:\e[36m"
		screen -ls "D_S_T_GAMECHECKROUTINE" | awk "/D_S_T_GAMECHECKROUTINE/"' { print $1 } '
		screen -ls "D_S_T_UPDATER" | awk "/D_S_T_UPDATER/"' { print $1 } '
		echo -en "\e[0m"
		echo "If you see less than 2 screen names, you have a problem or no updater running."
		echo "This will take: screen numbers x10 x5seconds."
	for iscreen in $list
	do
		DST_SCREEN_PIDS=$( screen -ls "${iscreen}" | awk "/${iscreen}/"' { print $1 } ' | cut -f1 -d"." )
		while read DST_SCREEN_ONEPID; do
			if [ ! -z "$DST_SCREEN_ONEPID" ]; then
				DST_BASH_PIDS=$( ps axo ppid,pid,comm | grep "bash" | awk "/${DST_SCREEN_ONEPID}/"' { print $2 } ' )
				if [ ! -z "$DST_BASH_PIDS" ]; then
					echo "Killing sleeps of PID $DST_SCREEN_ONEPID..."
					while read line ; do pkill -P "$line" sleep ; done  <<< "$DST_BASH_PIDS"
					echo "Waiting 5 seconds before next sleep kill..."
					sleep 5
				else
					echo "NOBASH ${iscreen}"
					HASERROR=true
				fi
			else
				echo "NOSCREEN ${iscreen}"
				HASERROR=true
			fi
			if [[ "$HASERROR" == true ]]; then
				echo -e "\e[31m\e[1mERROR: Bash or screen ${iscreen} not found!\e[0m"
			fi
		done  <<< "$DST_SCREEN_PIDS"
	done
	if [[ "$HASERROR" == false ]]; then
		echo "Check status in the following screens:"
		screen -ls "D_S_T_GAMECHECKROUTINE" | awk "/D_S_T_GAMECHECKROUTINE/"' { print $1 } '
		screen -ls "D_S_T_UPDATER" | awk "/D_S_T_UPDATER/"' { print $1 } '
		echo -e "  \e[1mscreen -r \"SCREEN_NAME_HERE\"\e[0m"
	fi
	echo "Force check normally terminated."
	exit
fi


# Game check routine, common to all servers
if [ "$1" == "gamecheckroutine" ]; then
	echo "DST Dedicated Server Auto-Updater ${DST_updater_version}"
	echo "Game check routine common to all servers"
	while true;
	do
		update_temp_game
		echo -e "\e[32mNext game update check cycle in ${DST_updatecheckcycle}sec.\e[0m"
		sleep ${DST_updatecheckcycle}
	done
	exit
fi


if [ "$1" == "consolemanager" ]; then
	echo "DST Dedicated Server Auto-Updater ${DST_updater_version}"
	echo "Console Manager common to all servers"
	while true;
	do
		console_manager
	done
	exit
fi

if [ "$1" == "startcheck" ]; then
	echo "DST Dedicated Server Auto-Updater ${DST_updater_version}"
	echo "Start Check common to all servers"
	while true;
	do
		server_sucess_check
		echo -e "\e[32mNext server start cycle in ${DST_updatecheckcycle}sec.\e[0m"
		sleep ${DST_updatecheckcycle}
	done
	exit
fi

# Normal routine, dedicated to one server
THIS_SCREEN_NAME=""
THIS_PID=$$
THIS_BASH_PPID=$( ps -p $THIS_PID o ppid,pid,comm | grep $THIS_PID | awk "/${THIS_PID}/"' { print $1 } ' )
if screen -ls "${THIS_BASH_PPID}." | grep "${THIS_BASH_PPID}." >/dev/null; then
	THIS_SCREEN_NAME=$( screen -ls "${THIS_BASH_PPID}." | grep "^\s*${THIS_BASH_PPID}" | cut -f2 -d"." | cut -f1 | cut -f1 -d" " )
fi

# Force shutdown now
if [[ "$2" == "shut" || "$2" == "shutdown" || "$2" == "kill" ]]; then
	echo -e "\e[31mFORCED shutdown of the following game servers & updaters in 10sec. \e[1mAbort with CTRL+C:\e[0m"
	for sk in "${!DST_array[@]}" ; do
		echo -e "- Server n°${DST_array_num[$sk]} \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m (\e[36m${DST_array_conf_dirname[$sk]}\e[0m)"
	done
	do_save="true"
	if [[ "$3" == "nosave" ]]; then
		echo "Shutdown will be without save."
		do_save="false"
	fi
	sleep 10
	for sk in "${!DST_array[@]}" ; do
		echo -e "\e[31mKILLING updater screen D_S_T_UPDATER_${DST_array_screen_name[$sk]}\e[0m"
		target_screen=$(find_screen "D_S_T_UPDATER_${DST_array_screen_name[$sk]}")
		screen -X -S "$target_screen" quit
		echo -e "\e[31m\e[1mATTEMPTING **FORCED** GAME SHUTDOWN OF SERVER n°$sk \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m (\e[36m${DST_array_conf_dirname[$sk]}\e[0m)"
		target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
		screen -S "$target_screen" -p 0 -X stuff "c_shutdown(${do_save})$(printf \\r)"
	done
	echo -e "\e[31mKILLING screen D_S_T_GAMECHECKROUTINE\e[0m (can be restarted by remaining updaters anyway)\e[0m"
	target_screen=$(find_screen "D_S_T_GAMECHECKROUTINE")
	screen -X -S "$target_screen" quit
	echo "Waiting 10sec for screens to die..."
	sleep 10
	echo -e "Remaining screens (\e[31mgame servers may take more time to die\e[0m):"
	screen -ls
	echo "Done"
	exit
fi

# Delete saves
if [[ "$2" == "delsave" ]]; then
	echo -e "\e[31mDELETING SAVES of the following game servers in 10sec. \e[1mAbort with CTRL+C:\e[0m"
	for sk in "${!DST_array[@]}" ; do
		echo -e "- Server n°${DST_array_num[$sk]} \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m (\e[36m${DST_array_conf_dirname[$sk]}\e[0m)"
	done
	sleep 10
	for sk in "${!DST_array[@]}" ; do
		rm -r "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/save"
	done
	echo "Done"
exit
fi

# Restart updater in screen
if [[ "$1" != "screened" ]]; then
	if [ ! -z "$THIS_SCREEN_NAME" ]; then
		if grep "^D_S_T_UPDATER" <<< $THIS_SCREEN_NAME  >/dev/null; then
			echo -e "\e[31m\e[1mERROR: You must not start the updater inside a D_S_T_ screen!\e[0m"
			echo -e "Instead, start the updater with \e[1m./auto_update_dst.sh\e[0m, the script will auto-screen itself."
			echo "Aborting in 10sec..."
			exit 0
			sleep 10
		else
			echo -e "\e[38;5;208m\e[1mWARNING:\e[0m\e[38;5;208m Launcher is running in screen ${THIS_SCREEN_NAME}, that's strange.\e[0m"
			echo "Continuing anyway..."
			sleep 2
		fi
	fi
	# Screen exists
	if find_screen "D_S_T_UPDATER_${DST_this_screen_name}" >/dev/null; then
		echo "Updater screen already exists."
		echo "Reattaching here & now D_S_T_UPDATER_${DST_this_screen_name}..."
		sleep 2
		screen -d -r "D_S_T_UPDATER_${DST_this_screen_name}"
		exit
	fi
	# Screen linked shard exists
	if [[ ${shard_with} != 0 ]]; then
		if find_screen "D_S_T_UPDATER_${DST_shard_screen_name}" >/dev/null; then
			echo "Shared updater screen already exists for joint shard server n°${shard_with}."
			echo "Reattaching here & now D_S_T_UPDATER_${DST_shard_screen_name}..."
			sleep 3
			target_screen=$(find_screen "D_S_T_UPDATER_${DST_shard_screen_name}")
			screen -d -r "$target_screen"
			exit
		fi
	fi
	echo "Creating screen D_S_T_UPDATER_${DST_this_screen_name}..."
	sleep 1
	screen -mS "D_S_T_UPDATER_${DST_this_screen_name}" /bin/bash -c "$0 screened $1"
	exit
fi


# MAIN CODE
# Server updater starting...

echo "DST Dedicated Server Auto-Updater ${DST_updater_version}"
echo -e "Updater script for server: \e[36m\e[1m${DST_this_screen_name}\e[0m (\e[36m${DST_this_conf_dirname}\e[0m)"
if [[ ${shard_with} != 0 ]]; then
	echo -e "\e[92mShard detected with server n°${shard_with}! \e[36m\e[1m${DST_shard_screen_name}\e[0m (\e[36m${DST_shard_conf_dirname}\e[0m)"
	echo -e "This screen will now manage both master/slave servers, synchronously."
fi
if [[ ${shard_with} == 0 && "$this_master_port" != "" ]]; then
	echo -e "\e[31m\e[1mERROR: Unable to find the joint shard master/slave server in the config!\e[0m"
	echo -e "Please reference the other shard server in the updater script config and make sure both ini cluster are correct, contains no comments and are saved."
	echo -e "This script shall handle the master and slave at the same time."
	echo -e "Continuting anyway with only 1 server in 30sec... or abort with Ctrl+C."
	sleep 30
fi

echo "TIP: To view/interact with the game, run from another terminal:"
for sk in "${!DST_array[@]}" ; do
	echo -e "     \e[1mscreen -r \"${DST_array_screen_name[$sk]}\"\e[0m"
done
echo "TIP: To check the status of the game update checker:"
echo -e "     \e[1mscreen -r \"D_S_T_GAMECHECKROUTINE\"\e[0m"
echo "TIP: List all your current screens with:"
echo -e "     \e[1mscreen -ls\e[0m"
echo "TIP: To force update check cycle, run from another terminal:"
echo -e "     \e[1m$0 check\e[0m"
echo "TIP: To stop this script, use Ctrl+C. Closing window will keep it running."

# Check if we are running on a screen
if [ ! -z "$THIS_SCREEN_NAME" ]; then
	if grep "^D_S_T_UPDATER" <<< $THIS_SCREEN_NAME  >/dev/null; then
		echo -e "\e[92mGreat, this updater is running on screen $THIS_SCREEN_NAME\e[0m"
	else
		echo -e "\e[38;5;208m\e[1mWARNING:\e[0m\e[38;5;208m This updater screen name should start by \"D_S_T_UPDATER\","
		echo -e "instead it's \"$THIS_SCREEN_NAME\"."
		echo -e "This will limit your ability to launch clean forced checks.\e[0m"
	fi
else
	echo -e "\e[38;5;208m\e[1mWARNING:\e[0m\e[38;5;208m This updater script is not running in a screen."
	echo -e "This will limit your ability to launch clean forced checks.\e[0m"
fi

sleep 5

DST_has_game_update=false
DST_has_mods_update=false
DST_nosleepstatus=1 # Force check at first launch
DST_loop_counter=0



while true;
do 
	# NOOBISH-PROOF inital mod conf .MASTER file generation
	for sk in "${!DST_array[@]}" ; do
		cd "${DST_array_game_path[$sk]}/mods"
		if [ ! -f "dedicated_server_mods_setup.MASTER.lua" ]; then
			echo -e "Server n°${DST_array_num[$sk]} \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m (\e[36m${DST_array_conf_dirname[$sk]}\e[0m):"
			echo -e "\e[31m\e[1mIMPORTANT: YOU MUST USE THE .MASTER FILES TO EDIT MODS FROM NOW\e[0m"
			echo "Existing files will now be copied once to dedicated_server_mods_setup.MASTER.lua + modsettings.MASTER.lua."
			echo "From now, use these .MASTER files, or dedicated_server_mods_setup.MASTER.lua + modoverrides.lua, to configure mods."
			echo "Never use the two original .lua files directly."
			echo "Not that game files (not \".klei\" conf directly) are always overwritten by Steam updates when using the \"validate\" option (by default)."
			cp "dedicated_server_mods_setup.lua" "dedicated_server_mods_setup.MASTER.lua"
			cp "modsettings.lua" "modsettings.MASTER.lua"
			echo "Initiating cycle in 20 seconds..."
			sleep 20
			echo
		fi
	done

	# LAUNCH OPTION: VALIDATE TEMP GAME DIR
	# Use option "rebuild" to rebuild the temporary game update dir.
	# Useless, except if you mess up with version.txt, if updates are buggy, or if you copied your messy game dir to the temp dir /public or /cavesbeta to avoid initial download.
	if [ "$1" == "rebuild" ]; then
		DST_TEMP_validate="validate"
		update_temp_game
		echo "Rebuilt temporary game dir with \"validate\" option. Exiting."
		exit
	fi

	cd "${steamcmd_path}"

	do_pause=false

	last_game_path=""
	modarg=""
	for sk in "${!DST_array[@]}" ; do

		# Disable update if one of the shards is running with the same game path
		can_update=true
		if [[ "${DST_this_game_path}" == "${DST_shard_game_path}" ]]; then
			for sk2 in "${!DST_array[@]}" ; do
				if find_screen "${DST_array_screen_name[$sk2]}" >/dev/null; then
					can_update=false
				fi
			done
		fi

		echo -e "Server n°${DST_array_num[$sk]} \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m (\e[36m${DST_array_conf_dirname[$sk]}\e[0m):"
		# UPDATE & LAUNCH GAME
		if find_screen "${DST_array_screen_name[$sk]}" >/dev/null; then
			DST_now=$(date +"%D %T")
			echo -e "\e[92m${DST_now}: Game running in screen \"${DST_array_screen_name[$sk]}\", OK.\e[0m"
		else
			echo -e "\e[33mGame screen \"${DST_array_screen_name[$sk]}\" not running.\e[0m"
			if [[ "${can_update}" == true ]]; then
				if [[ "${last_game_path}" != "${DST_array_game_path[$sk]}" ]]; then
					branch="${DST_array_game_beta[$sk]}"
					echo -e "\e[93mInitiating game update/sync with branch \"$branch\" before launch...\e[90m"
					beta_arg=""
					if [[ "$branch" != "public" ]]; then
						beta_arg="-beta ${branch}"
					fi
					cd "${steamcmd_path}"
					./steamcmd.sh +@ShutdownOnFailedCommand 1 +@NoPromptForPassword 1 +login anonymous +force_install_dir "${DST_array_game_path[$sk]}" +app_update 343050 ${beta_arg} ${DST_validate} +quit | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
					echo -e "\e[0mGame update/sync done."
					echo -e "Restoring mod conf files from master."
					cd "${DST_array_game_path[$sk]}/mods"
					cp "dedicated_server_mods_setup.MASTER.lua" "dedicated_server_mods_setup.lua"
					cp "modsettings.MASTER.lua" "modsettings.lua"
				else
					echo -e "This server has the same game path as the first shard, skipping update step..."
				fi
			else
				echo -e "We can't update this server before starting it, as the other shard is running with the same game path... If an update is necessary, it will be launched later."
			fi

			if [ "${DST_backupchat}" = true ] && [ -f "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_chat_log.txt" ]; then
				echo -e "Saving chat log."
				cat "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_chat_log.txt" >> "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log_archive/server_chat_log.save.txt"
			fi
			if [ "${DST_backuplog}" = true ]; then
				echo "Deleting old and oversized log archives..."
				find "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log_archive/server_log."*".txt" -mtime +"${DST_log_maxage}" -delete 2>/dev/null

				logs_size=$( find "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log_archive/server_log."*".txt" -mtime -1 -printf "%s\n" 2>/dev/null | awk '{t+=$1}END{print t}' )
				if [[ ${logs_size} =~ ^-?[0-9]+$ ]]; then # Is integer
					logs_size_Mo=$(( ${logs_size} / 1048576 ))
					#echo "Total log size: ${logs_size_Mo}Mo"
					if [[ $logs_size_Mo > 50 ]]; then
						echo -e "\e[31m\e[1mALERT: Too big log archives! Deleting all archives.\e[0m"
						find "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log_archive/server_log."*".txt" -delete 2>/dev/null
						rm "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log-updater.txt"
						DST_now=$(date +"%D %T")
						echo "${DST_now}: [${DST_array_screen_name[$sk]}] Too big log archives! Deleting all archives." >> "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log-updater.txt"
					fi
				fi
			fi
			if [ "${DST_backuplog}" = true ] && [ -f "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt" ]; then
				echo -e "Saving game log."
				DST_timestamp=$(date +"%s")
				mkdir "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log_archive" 2&>/dev/null
				cat "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt" > "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log_archive/server_log.${DST_timestamp}.txt"
			fi
			cd "${DST_array_game_path[$sk]}/bin"
			echo -e "Starting game (inc. mod updates) in detached DST screen \"${DST_array_screen_name[$sk]}\"..."
			echo "Screen command: ${DST_bin_cmd} ${DST_array_cmdline_options[$sk]}"
			if [[ "${can_update}" == false ]]; then
				modarg="-skip_update_server_mods"
			fi
			screen -dmS "${DST_array_screen_name[$sk]}" /bin/sh -c "${DST_bin_cmd} ${DST_array_cmdline_options[$sk]} ${modarg}"
			DST_now=$(date +"%D %T")
			echo "${DST_now}: [${DST_array_screen_name[$sk]}] Game launch initiated." >> "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log-updater.txt"
			echo -e "\e[92m${DST_now}: DST game started in screen \"${DST_array_screen_name[$sk]}\", OK.\e[0m"
			echo -e "Check game status from another terminal with:"
			echo -e "  \e[1mscreen -r \"${DST_array_screen_name[$sk]}\"\e[0m"
			echo -e "  then detach with: Ctrl-a + d"
			echo -e "  or detach screen from terminal with: screen -d \"${DST_array_screen_name[$sk]}\""
			cd "${steamcmd_path}"
			if [[ "${can_update}" == true ]]; then
				echo -e "\e[32mPausing 180sec for mods to download.\e[0m"
				sleep 180
			fi
			do_pause=true
		fi
		last_game_path=${DST_array_game_path[$sk]}
		modarg="-skip_update_server_mods" # Don't update mods for the next server launch (since the first one is launched/running)
	done
	if [ "${do_pause}" = true ]; then
		echo -e "\e[32mPausing ${DST_keepalive}sec before continuing cycle.\e[0m"
		sleep ${DST_keepalive}
		DST_nosleepstatus=$?
	fi

	# LAUNCH GAME UPDATE CHECK ROUTINE IN SEPARATE SCREEN
	if find_screen "D_S_T_GAMECHECKROUTINE" >/dev/null; then
		echo -e "\e[92m${DST_now}: Update check routine running in screen \"D_S_T_GAMECHECKROUTINE\", OK.\e[0m"
	else
		echo -e "\e[93mGame update check routine not running. Launching...\e[0m"
		cd ${SCRIPTHERE}

		screen -dmS "D_S_T_GAMECHECKROUTINE" /bin/bash -c "$0 gamecheckroutine"

		DST_now=$(date +"%D %T")
		echo "${DST_now}: [${DST_this_screen_name}] Game update check routine initiated."
		echo -e "Check routine status from another terminal with:"
		echo -e "  \e[1mscreen -r \"D_S_T_GAMECHECKROUTINE\"\e[0m"
		echo -e "  then detach with: Ctrl-a + d"
		echo -e "  or detach screen from terminal with: screen -d \"D_S_T_GAMECHECKROUTINE\""
		echo -e "\e[32mPausing ${DST_keepalive}sec before continuing cycle.\e[0m"
		cd "${steamcmd_path}"
		sleep ${DST_keepalive}
		DST_nosleepstatus=$?
	fi
	
	
	# LAUNCH CONSOLE MANAGER IN SEPARATE SCREEN
	if find_screen "D_S_T_CONCOLEMANAGER" >/dev/null; then
		echo -e "\e[92m${DST_now}: Console Manager running in screen \"D_S_T_CONCOLEMANAGER\", OK.\e[0m"
	else
		echo -e "\e[93mConsole Manager not running. Launching...\e[0m"
		cd ${SCRIPTHERE}

		screen -dmS "D_S_T_CONCOLEMANAGER" /bin/bash -c "$0 consolemanager"
		DST_now=$(date +"%D %T")
		echo "${DST_now}: Console Manager initiated."
		echo -e "To use Console Manager from another terminal with:"
		echo -e "  \e[1mscreen -r \"D_S_T_CONCOLEMANAGER\"\e[0m"
		echo -e "  then detach with: Ctrl-a + d"
		echo -e "  or detach screen from terminal with: screen -d \"D_S_T_CONCOLEMANAGER\""
		DST_nosleepstatus=$?
	fi

	# LAUNCH SERVER START CHECK IN SEPARATE SCREEN
	if find_screen "D_S_T_STARTCHECK" >/dev/null; then
		echo -e "\e[92m${DST_now}: Start check running in screen \"D_S_T_STARTCHECK\", OK.\e[0m"
	else
		echo -e "\e[93mStart check not running. Launching...\e[0m"
		cd ${SCRIPTHERE}
		screen -dmS "D_S_T_STARTCHECK" /bin/bash -c "$0 startcheck"
		DST_now=$(date +"%D %T")
		echo "${DST_now}: Start check initiated."
		echo -e "To use Start check from another terminal with:"
		echo -e "  \e[1mscreen -r \"D_S_T_STARTCHECK\"\e[0m"
		echo -e "  then detach with: Ctrl-a + d"
		echo -e "  or detach screen from terminal with: screen -d \"D_S_T_STARTCHECK\""
		DST_nosleepstatus=$?
	fi
	
	# CHECK FOR UPDATES
	# Check for mod updates in server log.txt
	# The game is already checking for mod updates periodically, it's no use to download all mods to check.
	do_pause=false
	DST_has_mods_update=false
	DST_has_game_update=false
	for sk in "${!DST_array[@]}" ; do
		echo -e "Server n°${DST_array_num[$sk]} \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m (\e[36m${DST_array_conf_dirname[$sk]}\e[0m):"
		if [[ $(grep "is out of date and needs to be updated for new users to be able to join the server" -c "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_chat_log.txt") > 0 ]]; then
			DST_has_mods_update=true
			echo -e "\e[93mMod update available!\e[0m"
		else
			echo -e "\e[92mNo mod update available.\e[0m"
		fi

		# Checking for game update from file generated by game update check routine
		if [ -f "${DST_temp_path}/branch_${DST_array_game_beta[$sk]}/version4updater.txt" ]; then
			if flock "${DST_temp_path}/branch_${DST_array_game_beta[$sk]}/version4updater.txt" -c "! diff -q \"${DST_temp_path}/branch_${DST_array_game_beta[$sk]}/version4updater.txt\" \"${DST_array_game_path[$sk]}/version.txt\" > /dev/null" ; then
				#echo $?
				DST_has_game_update=true
				echo -e "\e[93mGame update available!\e[0m"
				#diff -q "${DST_temp_path}/branch_${DST_array_game_beta[$sk]}/version4updater.txt" "${DST_array_game_path[$sk]}/version.txt"
				#echo $?
			else
				echo -e "\e[92mNo game update available.\e[0m" # or failed file lock
			fi
		else
			echo -e "\e[31m\e[1mWARNING: Unable to find ${DST_temp_path}/branch_${DST_array_game_beta[$sk]}/version4updater.txt\e[0m"
			echo -e "\e[31mRun: screen -r D_S_T_GAMECHECKROUTINE\e[0m"
			echo -e "\e[31mAnd check for errors.\e[0m"
			echo -e "\e[31mMaybe the initial download is still in progress.\e[0m"
			echo -e "Continuing anyway..."
			sleep 5
		fi
	done

	DST_is_shut=false
	loop_seconds=0
	shutdown_initiated=false
	last_announce=$(( -$announce_period ))

	# INITIATE RESTART
	if [[ "$DST_has_mods_update" == true || "$DST_has_game_update" == true ]]; then 
		while [ "$DST_is_shut" = false ] ; do

			# GRACEFUL SHUTDOWN METHOD
			# Attempt graceful shutdown when no players online
			# Require auto-update mod installed & enabled. Otherwise, only forced shutdown will be used.
			# Send c_shutdownifempty() DST command to screen periodically
			#randomness=$RANDOM
			if [ "$shutdown_initiated" = false ]; then
				echo -e "\e[36m\e[1mAttempting graceful shutdown:\e[0m \e[36mGetting number of players and checking 30sec later\e[0m"
				randomness=$( date +%s%3N )
				for sk in "${!DST_array[@]}" ; do
					echo "Sending c_printplayersnumber(${randomness}) to server $sk"
					target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
					screen -S "$target_screen" -p 0 -X stuff "c_printplayersnumber(${randomness})$(printf \\r)"
					
				done
				loop_seconds=$(( $loop_seconds + 10 ))
				sleep 30
				can_shutdown=true
				for sk in "${!DST_array[@]}" ; do
					numplayers[$sk]=$( grep "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt" -e "^.*:.*:.*: PrintPlayersNumber:${randomness}:.*:END" | cut -f6 -d":" )
					if [[ "${numplayers[$sk]}" =~ ^-?[0-9]+$ ]]; then # Is integer
						if [[ "${numplayers[$sk]}" != 0 ]]; then
						    echo "Announcing game/mod update available to players"					        
						        target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
						        screen -S "$target_screen" -p 0 -X stuff "c_announce(\"感谢你在本服务器玩耍，现游戏或者MOD需要更新，请你暂时退出游戏，以便服务器执行自动更新！\")$(printf \\r)"
								sleep 5
								screen -S "$target_screen" -p 0 -X stuff "c_announce(\"请你记住房间名，三分钟后再次搜索进入，谢谢你的合作！\")$(printf \\r)"
								sleep 5
                                screen -S "$target_screen" -p 0 -X stuff "c_announce(\"只有游戏或者MOD更新到最新版本，其他玩家才能加入游戏一起玩耍！\")$(printf \\r)"
					        sleep 10
							echo -e "Can't gracefuly shutdown now due to \"${numplayers[$sk]}\" player(s) on server $sk \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m"
							can_shutdown=false
						fi
						#PrintPlayersNumber:1479561554624:0:END
					else
						echo -e "\e[38;5;208m\e[1mWARNING:\e[0m\e[38;5;208m Can't retrieve number of players from game log.\e[0m"
						echo -e "Are you sure modgracefulshutdown version 1.3 or above has been installed, enabled and game restarted after?"
						echo "DEBUG: grep \"${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/Cluster_1/Master/server_log.txt\" -e \"^.*:.*:.*: PrintPlayersNumber:${randomness}:.*:END\" | cut -f6 -d\":\""
						echo "DEBUG: numplayers[$sk]=${numplayers[$sk]=}"
						can_shutdown=false
					fi
				done

				# Shutting down "gracefully"
				if [ "${can_shutdown}" = true ]; then
					for sk in "${!DST_array[@]}" ; do
						echo -e "\e[38;5;208m\e[1mNO PLAYERS ONLINE, \"GRACEFULY\" SHUTTING DOWN NOW SERVER $sk \e[36m\e[1m${DST_array_screen_name[$sk]}\e[0m"
						target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
						screen -S "$target_screen" -p 0 -X stuff "c_save(true)$(printf \\r)"
						sleep 5
						screen -S "$target_screen" -p 0 -X stuff "c_shutdown(true)$(printf \\r)"
						shutdown_type="there-was-NO-players"
						shutdown_initiated=true
					done
				fi
			
			else
				shutdown_finished=true
				for sk in "${!DST_array[@]}" ; do
					if find_screen "${DST_array_screen_name[$sk]}" >/dev/null; then
						shutdown_finished=false
					fi
				done
				if [ "$shutdown_finished" = false ]; then
					echo -e "\e[31mWaiting for game screen(s) to die by themselves...\e[0m"
				else
					echo -e "\e[92mGame screen(s) have finally shutdown. Breaking to initiate update/restart...\e[0m"
					screen -ls
					sleep 10
					DST_now=$(date +"%D %T")
					for sk in "${!DST_array[@]}" ; do
						echo "${DST_now}: [${DST_array_screen_name[$sk]}] Shutdown done. Players? = ${shutdown_type}. Reason: Mod update = ${DST_has_mods_update}; Game update = ${DST_has_game_update}." >> "${DST_conf_basedir}/${DST_array_conf_dirname[$sk]}/log-updater.txt"
					done
					DST_is_shut=true
					break
				fi
				loop_seconds=$(( $loop_seconds + 60 ))
				sleep 60
			fi
			
			# FORCED SHUTDOWN METHOD
			if [[ "$shutdown_initiated" == false && "$DST_this_allow_forced_shutdown" == true ]]; then
				time_to_restart_min_hour=$(( ($(date -d "${restart_min_hour}:00" +%s) - $(date +%s) + (86400)) % (86400) ))
				time_to_restart_max_hour=$(( ($(date -d "${restart_max_hour}:00" +%s) - $(date +%s) + (86400)) % (86400) ))

				# Force restart between 3:00 AM and 6:00 AM server time
				# Announce & shutdown in 2min
				if [ $time_to_restart_max_hour -le $time_to_restart_min_hour ]; then # We're inside the allowed force restart timeframe
					echo "Announcing forced shutdown to players: T-2min."
					for sk in "${!DST_array[@]}" ; do
						target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
						screen -S "$target_screen" -p 0 -X stuff "c_announce(\"感谢你在本服务器玩耍，服务器将在两分钟后强制关闭以执行更新！游戏记录会保存，更新完毕后会自动启动服务器.\")$(printf \\r)"
					done
					sleep 120
					for sk in "${!DST_array[@]}" ; do
						echo -e "\e[31m\e[1mATTEMPTING **FORCED** GAME SHUTDOWN OF SERVER $sk \e[36m\e[1m${DST_array_screen_name[$sk]}!\e[0m"
						target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
						screen -S "$target_screen" -p 0 -X stuff "c_shutdown(true)$(printf \\r)"
					done
					shutdown_initiated=1
					shutdown_type="there-was-SOME-players"

				# Announce a later shutdown			
				else
					# echo "Debug announce timer: $last_announce + $announce_period <= $loop_seconds"
					left_hours=$(( time_to_restart_min_hour/3600 ))
					left_mins=$(( (time_to_restart_min_hour/60)%60 ))
					if (( $last_announce + $announce_period <= $loop_seconds)); then
						last_announce=$loop_seconds
						echo "Announcing shutdown to players: T- ${left_hours}h${left_mins}min"
						for sk in "${!DST_array[@]}" ; do
							target_screen=$(find_screen "${DST_array_screen_name[$sk]}")
							screen -S "$target_screen" -p 0 -X stuff "c_announce(\"感谢你在本服务器玩耍，如果现在不愿意退出，服务器将在${left_hours}小时${left_mins}分钟后强制关闭以执行更新！游戏记录会保存，更新完毕后会自动启动服务器.\")$(printf \\r)"
						done
					fi
				fi
			fi
		done
	fi
	
	# Next update check cycle in seconds
	if [ "$DST_is_shut" = false ]; then
		echo -e "\e[32mNext keepalive/update check cycle in ${DST_keepalive}sec.\e[0m"
		sleep ${DST_keepalive}
		DST_nosleepstatus=$?
	fi
done