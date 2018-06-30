#!/bin/bash
#-------------------------------------------------------------------------------------------
#作者：Ariwori 2018-06-29 00:10:49
#需配合putty和winscp或者Xshell使用
#首次使用上传脚本至用户根目录并给予执行权限
#云服务器系统为linux发行版本Ubuntu
#旧饭新炒，有很多不完善和不合理的地方，我就懒得改了                                                                        
#-------------------------------------------------------------------------------------------
shell_ver="1.1.0"
DST_conf_dirname="DoNotStarveTogether"   
DST_conf_basedir="$HOME/.klei" 
DST_bin_cmd="./dontstarve_dedicated_server_nullrenderer"


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
        info "首次运行配置完毕，如果无任何异常，你就可以创建新的世界了。"
    fi
}
# 创建文件夹
mkdstdir(){
    mkdir -pv $HOME/steamcmd
	mkdir -pv $HOME/DSTServer
	mkdir -pv $DST_conf_basedir/$DST_conf_dirname
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
    sudo apt install -y tmux
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
}
first_run_check
##########################################################################
# 更新游戏服务端
Update_DST(){
    appmanifestfile=$(find "$HOME/DSTServer" -type f -name "appmanifest_343050.acf")
    currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)
    cd $HOME/steamcmd || exit
    availablebuild=$(./steamcmd.sh +login "anonymous" +app_info_update 1 +app_info_print 343050 +app_info_print 343050 +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
    if [ "${currentbuild}" != "${availablebuild}" ]; then
        info "更新可用(${currentbuild}===>${availablebuild}！即将执行更新..."
        Install_Game
    else
        tip "无可用更新！当前Steam构建版本（$currentbuild）"
    fi
}

function setupmod()
{
    echo "ServerModSetup(\"1301033176\")
" >> "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua"
    dir=$(ls -l "$HOME/DSTServer/mods" |awk '/^d/ {print $NF}'|grep "workshop"|cut -f2 -d"-")
    for modid in $dir
    do
	    if [[ $(grep "$modid" -c "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua") > 0 ]] ;then 
		    echo "" >> "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua"
		else	
            echo "ServerModSetup(\"$modid\")" >> "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua"
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
function settoken()
{
    echo -e "\e[92m是否使用预设服务器令牌：1.是 2.否 \e[0m"
    read isreset
	case $isreset in 	
		1)
		echo "xyXThBqSds+ku7ObcWRS1gbH/GlXdtKZ" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster_token.txt" ;;
		2)
		echo -e "\e[92m请输入你的服务器令牌：）\e[0m"
		read token
		echo "$token" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster_token.txt" ;;
	esac
	echo "服务器令牌设置完毕！"
}

function setcluster()
{
    echo "" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini"
    echo -e "\e[92m是否为Steam群组服务器：1.是 2.否 \e[0m"
    read isgroup
    case $isgroup in 
        1)	
		echo -e "\e[92m群组官员是否设为管理员：1.是 2.否\e[0m"
        read isadmin
		case $isadmin in
		    1)
			steamgroupadmins="true";;
            2)
			steamgroupadmins="false";;
        esac
		echo -e "\e[92m请输入Steam群组ID:\e[0m"
		read steamgroupid
		echo -e "\e[92m服务器是否设为仅Steam群组成员可进：1.是 2.否\e[0m"
		read isonly
		case $isonly in
		    1)
			steamgrouponly="true";;
            2)
			steamgrouponly="false";;
		    esac
	    echo "[STEAM]
steam_group_admins = $steamgroupadmins
steam_group_id = $steamgroupid
steam_group_only = $steamgrouponly

" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini";;
       2)
	   echo "" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini";;
	esac
    echo -e "\e[92m请选择游戏模式：1.无尽 2.生存 3.荒野\e[0m"
    read choosemode
    case $choosemode in
        1)
		gamemode="endless";;
        2)
		gamemode="survival";;
        3)
		gamemode="wilderness";;
    esac

    echo -e "\e[92m请输入最大玩家数量：\e[0m"
    read players

    echo -e "\e[92m是否开启PVP：1.是 2.否\e[0m"
    read ispvp
    case $ispvp in
        1)
		ifpvp="true";;
        2)
		ifpvp="false";;
    esac
	
echo "[GAMEPLAY]
game_mode = $gamemode
max_players = $players
pvp = $ifpvp
pause_when_empty = true

" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini"

    echo -e "\e[92m请选择游戏风格：1.休闲 2.合作 3.竞赛 4.疯狂\e[0m"
    read intent
    case $intent in
        1)
        intention="social";;
        2)
        intention="cooperative";;
        3)
        intention="competitive";;
        4)
        intention="madness";;
    esac
	
    echo -e "\e[92m请输入服务器介绍：PS：若无请按Enter键\e[0m"
    read description

	echo -e "\e[92m请输入服务器名字：\e[0m"
    read name
	
	echo -e "\e[92m请输入服务器密码：PS：若无请按Enter键\e[0m"
    read password
	echo -e "\e[92m请输入预留的服务器玩家位置个数：（设置后请在后续步骤添加白名单，否则无效）\e[0m"
    read whitelistslots
	
    echo "[NETWORK]
lan_only_cluster = false
cluster_intention = $intention
cluster_description = $description
cluster_name = $name
offline_cluster = false
cluster_password = $password
whitelist_slots = $whitelistslots

" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini"

    echo "[MISC]
console_enabled = true

" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini"

    echo -e "\e[92m请选择服务器开启模式：1.只搭建地上或者洞穴世界 2.单服务器同时搭建地上和洞穴世界\e[0m"
    read servermode
	case $servermode in
	    1)
		echo -e "\e[92m请输入主世界外网IP:\e[0m"
		read masterip
		echo "[SHARD]
shard_enabled = true
bind_ip = 0.0.0.0
master_ip = $masterip
master_port = 10888
cluster_key = Kurumi

" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini";;
        2)
		echo "[SHARD]
shard_enabled = true
bind_ip = 127.0.0.1
master_ip = 127.0.0.1
master_port = 10888
cluster_key = Kurumi

" >> "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/cluster.ini";;
	esac
    clear
    echo "房间信息配置完成！"
} 

function setserverini()
{
    if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master" ]
	    then 
		    mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master
			echo "[NETWORK]
server_port = 10999


[SHARD]
is_master = true
name = Master
id = 1


[STEAM]
master_server_port = 27019
authentication_port = 8769" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/server.ini"			
	    fi
	if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves" ]
	then 
	    mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves
        echo "[NETWORK]
server_port = 10998


[SHARD]
is_master = false
name = Caves
id = 2


[STEAM]
master_server_port = 27018
authentication_port = 8768" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves/server.ini"
	fi
}

function startserver()
{
    if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}" ]
	then 
		mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}
	fi
	closeserver
    echo -e "\e[92m是否新建存档：1.是  2.否\e[0m"
	read isnew
	case $isnew in
	    1)
		echo -e "\e[92m请输入存档名称：（不要包含中文）\e[0m"
		read clustername
		cluster_name=$clustername
		if [ ! -d "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}" ]
	    then 
		    mkdir -p ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}
	    fi
		setcluster
		settoken
		createlistfile
		setserverini
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
		ls -l ${DST_conf_basedir}/${DST_conf_dirname} |awk '/^d/ {print $NF}'
		echo -e "\e[92m请输入已有存档名称：\e[0m"
		read clustername
		cluster_name=$clustername		
		;;
	esac
	echo "cluster=$cluster_name" > dst.conf
	setupmod
	if [[ ! -f ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua ]]; then
		modadd
	    listallmod
        addmod
    fi
    cp "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua" "$HOME/DSTServer/mods/dedicated_server_mods_setup.lua"	
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
	echo "shard=\"$shard\"" > $HOME/dst.conf
	startshard
	startcheck
	echo -e "\e[92m服务器开启中。。。请稍候。。。\e[0m"
	sleep 10
	startcheck
	menu
}
function startshard(){
	for s in $shard; do
		tmux new-session -s DST_Caves -d "$DST_bin_cmd -cluster $cluster_name -shard $shard"
	done
}
function startcheck()
{
	masterserverlog_path="${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/server_log.txt"
	cavesserverlog_path="${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves/server_log.txt"
	while :
    do
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

function setmasterworld()
{
    echo -e "\e[92m请选择生物群落：1.经典（没有巨人）  默认（联机）直接按Enter \e[0m"
	task_set="default"
	read smaster
	case $smaster in
	    1)
		task_set="classic";;
	esac
	echo -e "\e[92m请选择初始环境： 默认直接按Enter  1.三箱  2.永夜\e[0m"
	start_location="default"
	read smaster
	case $smaster in
	    1)
		world_size="plus";;
		2)
		world_size="darkness";;
	esac
	echo -e "\e[92m请选择地图大小：1.小型 2.中等  默认（大型）直接按Enter 3.巨型\e[0m"
	world_size="default"
	read scaves
	case $scaves in
	    1)
		world_size="small";;
		2)
		world_size="medium";;
		3)
		world_size="huge";;
	esac
	echo -e "\e[92m请设置岔路地形：1.无 2.最少  默认直接按Enter 3.最多\e[0m"
	branching="default"
	read scaves
	case $scaves in
	    1)
		branching="never";;
		2)
		branching="least";;
		3)
		branching="most";;
	esac
	echo -e "\e[92m请设置环状地形：1.无  默认直接按Enter   2.总是\e[0m"
	loop="default"
	read scaves
	case $scaves in
	    1)
		loop="never";;
		2)
		loop="always";;
	esac
	echo -e "\e[92m请选择要参与的活动：1.无  默认直接按Enter  2.万圣夜  3.冬季盛宴  4.鸡年吉祥\e[0m"
	specialevent="default"
	read scaves
	case $scaves in
	    1)
		specialevent="none";;
		2)
		specialevent="hallowed_nights";;
		3)
		specialevent="winters_feast";;
		4)
		specialevent="year_of_the_gobbler";;
	esac
	
	echo -e "\e[92m请设置秋天长度：1.无 2.很短 3.短 默认直接按Enter 4.长 5.很长 6.随机\e[0m"
	setseason
	autumn="$season"
	
	echo -e "\e[92m请设置冬天长度：1.无 2.很短 3.短 默认直接按Enter 4.长 5.很长 6.随机\e[0m"
	setseason
	winter="$season"

	echo -e "\e[92m请设置春天长度：1.无 2.很短 3.短 默认直接按Enter 4.长 5.很长 6.随机\e[0m"
	setseason
	spring="$season"
	
	echo -e "\e[92m请设置夏天长度：1.无 2.很短 3.短 默认直接按Enter 4.长 5.很长 6.随机\e[0m"
	setseason
	summer="$season"
	
	echo -e "\e[92m请设置开始季节：默认（秋季）直接按Enter  1. 冬季  2.春季  3.夏季  4.秋或春  5.冬或夏  6.随机\e[0m"
	season_start="default"
	read scaves
	case $scaves in
	    1)
		season_start="winter";;
		2)
		season_start="spring";;
		3)
		season_start="summer";;
		4)
		season_start="autumnorspring";;
		5)
		season_start="winterorsummer";;
		6)
		season_start="random";;
	esac
	
	echo -e "\e[92m请设置昼夜长短：\e[0m"
	echo -e "\e[92m      默认直接按Enter   1.长白昼\e[0m"
	echo -e "\e[92m      2.长黄昏          3.长夜晚\e[0m"
	echo -e "\e[92m      4.无白昼          5.无黄昏\e[0m"
	echo -e "\e[92m      6.无夜晚          7.仅有白昼\e[0m"
	echo -e "\e[92m      8.仅有黄昏        9.仅有夜晚\e[0m"
	day="default"
	read scaves
	case $scaves in
	    1)
		day="longday";;
		2)
		day="longdusk";;
		3)
		day="longnight";;
		4)
		day="noday";;
		5)
		day="nodusk";;
		6)
		day="nonight";;
		7)
		day="onlyday";;
		8)
		day="onlydusk";;
		8)
		day="onlynight";;
	esac
	echo -e "\e[92m请设置再生速度：1.极慢 2.慢 默认直接按Enter 3.快 4.极快\e[0m"
	regrowth="default"
	read scaves
	case $scaves in
	    1)
		regrowth="veryslow";;
		2)
		regrowth="slow";;
		3)
		regrowth="fast";;
		4)
		regrowth="veryfast";;
	esac
	echo -e "\e[92m请设置作物患病：1.无 2.随机 3.慢 默认直接按Enter 4.快\e[0m"
	disease_delay="default"
	read scaves
	case $scaves in
	    1)
		disease_delay="none";;
		2)
		disease_delay="random";;
		3)
		disease_delay="long";;
		4)
		disease_delay="short";;
	esac
	echo -e "\e[92m请设置初始资源多样性：1.经典 默认直接按Enter 2.高度随机\e[0m"
	prefabswaps_start="default"
	read scaves
	case $scaves in
	    1)
		prefabswaps_start="classic";;
		2)
		prefabswaps_start="highly random";;
	esac
	echo -e "\e[92m请设置树石化速率：1.无 2.慢 默认直接按Enter 3.快 4.极快\e[0m"
	petrification="default"
	read scaves
	case $scaves in
	    1)
		petrification="none";;
		2)
		petrification="few";;
		3)
		petrification="many";;
		4)
		petrification="max";;
	esac
	
	echo -e "\e[92m请设置前辈：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	boons="$preset"
	
	echo -e "\e[92m请设置复活台：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	touchstone="$preset"
	
	echo -e "\e[92m请设置雨：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	weather="$preset"
	
	echo -e "\e[92m请设置彩蛋：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	alternatehunt="$preset"
	
	echo -e "\e[92m请设置杀人蜂巢穴：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	angrybees="$preset"
	
	echo -e "\e[92m请设置秋季BOSS：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	bearger="$preset"
	
	echo -e "\e[92m请设置牛：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	beefalo="$preset"
	
	echo -e "\e[92m请设置牛发情频率：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	beefaloheat="$preset"
	
	echo -e "\e[92m请设置蜜蜂巢穴：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	bees="$preset"
	
	echo -e "\e[92m请设置鸟：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	birds="$preset"
	
	echo -e "\e[92m请设置草：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	grass="$preset"
	
	echo -e "\e[92m请设置蝴蝶：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	butterfly="$preset"
	
	echo -e "\e[92m请设置秃鹫：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	buzzard="$preset"
	
	echo -e "\e[92m请设置仙人掌：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	cactus="$preset"
	
	echo -e "\e[92m请设置胡萝卜：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	carrot="$preset"
	
	echo -e "\e[92m请设置浣熊猫：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	catcoon="$preset"
	
	echo -e "\e[92m请设置冬季BOSS：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	deerclops="$preset"
	
	echo -e "\e[92m请设置春季BOSS：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	goosemoose="$preset"
	
	echo -e "\e[92m请设置夏季BOSS：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	dragonfly="$preset"
	
	echo -e "\e[92m请设置花：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	flower="$preset"
	
	echo -e "\e[92m请设置青蛙雨：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	frograin="$preset"
	
	echo -e "\e[92m请设置树枝：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	sapling="$preset"
	
	echo -e "\e[92m请设置尖刺灌木：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	marshbush="$preset"
	
	echo -e "\e[92m请设置芦苇：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	reeds="$preset"
	
	echo -e "\e[92m请设置树木：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	trees="$preset"	
	
	echo -e "\e[92m请设置燧石：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	flint="$preset"
	
	echo -e "\e[92m请设置岩石：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	rock="$preset"
	
	echo -e "\e[92m请设置猎犬丘：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	houndmound="$preset"
	
    echo -e "\e[92m请设置猎犬袭击：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	hounds="$preset"
	
	echo -e "\e[92m请设置足迹：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	hunt="$preset"
	
    echo -e "\e[92m请设置小偷 ：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	krampus="$preset"	

    echo -e "\e[92m请设置浆果丛：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	berrybush="$preset" 	
	
	echo -e "\e[92m请设置蘑菇：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	mushroom="$preset"
	
	echo -e "\e[92m请设置闪电：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	lightning="$preset"
	
	echo -e "\e[92m请设置电羊：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	lightninggoat="$preset"
	
	echo -e "\e[92m请设置池塘：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	ponds="$preset"

	echo -e "\e[92m请设置食人花：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	lureplants="$preset"
	
	echo -e "\e[92m请设置兔子：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	rabbits="$preset"
	
	echo -e "\e[92m请设置鱼人：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	merm="$preset"
	
	echo -e "\e[92m请设置陨石频率：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	meteorshowers="$preset"
	
	echo -e "\e[92m请设置陨石区域：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	meteorspawner="$preset"  

    echo -e "\e[92m请设置蜘蛛：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	spiders="$preset"		
	
	echo -e "\e[92m请设置触手：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	tentacles="$preset"	
	
	echo -e "\e[92m请设置齿轮马：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	chess="$preset"

	echo -e "\e[92m请设置树人：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	liefs="$preset"
	
	echo -e "\e[92m请设置鼹鼠：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	moles="$preset"     	
	
	echo -e "\e[92m请设置企鹅：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	penguins="$preset"
	
	echo -e "\e[92m请设置火鸡：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	perd="$preset"
	
	echo -e "\e[92m请设置猪人：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	pigs="$preset"
	
	echo -e "\e[92m请设置冰川：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	rock_ice="$preset"
	
	echo -e "\e[92m请设置风滚草：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	tumbleweed="$preset"
	
	echo -e "\e[92m请设置海象巢穴：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	walrus="$preset"
	
	echo -e "\e[92m请设置野火（自燃）：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	wildfires="$preset"
	
	echo -e "\e[92m请设置高脚鸟：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	tallbirds="$preset"
	clear
	echo "return {
  desc=\"The standard Don't Starve experience.\",
  hideminimap=false,
  id=\"SURVIVAL_TOGETHER\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"Default\",
  numrandom_set_pieces=4,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"$alternatehunt\",
    angrybees=\"$angrybees\",
    autumn=\"$autumn\",
    bearger=\"$bearger\",
    beefalo=\"$beefalo\",
    beefaloheat=\"$beefaloheat\",
    bees=\"$bees\",
    berrybush=\"$berrybush\",
    birds=\"$birds\",
    boons=\"$boons\",
    branching=\"$branching\",
    butterfly=\"$butterfly\",
    buzzard=\"$buzzard\",
    cactus=\"$cactus\",
    carrot=\"$carrot\",
    catcoon=\"$catcoon\",
    chess=\"$chess\",
    day=\"$day\",
    deciduousmonster=\"default\",
    deerclops=\"$deerclops\",
    disease_delay=\"$disease_delay\",
    dragonfly=\"$dragonfly\",
    flint=\"$flint\",
    flowers=\"$flower\",
    frograin=\"$frograin\",
    goosemoose=\"$goosemoose\",
    grass=\"$grass\",
    houndmound=\"$houndmound\",
    hounds=\"$hounds\",
    hunt=\"$hunt\",
    krampus=\"$krampus\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"$liefs\",
    lightning=\"$lightning\",
    lightninggoat=\"$lightninggoat\",
    loop=\"$loop\",
    lureplants=\"$lureplants\",
    marshbush=\"$marshbush\",
    merm=\"$merm\",
    meteorshowers=\"$meteorshowers\",
    meteorspawner=\"$meteorspawner\",
    moles=\"$moles\",
    mushroom=\"$mushroom\",
    penguins=\"$penguins\",
    perd=\"$perd\",
    petrification=\"$petrification\",
    pigs=\"$pigs\",
    ponds=\"$ponds\",
    prefabswaps_start=\"$prefabswaps_start\",
    rabbits=\"$rabbits\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"default\",
    rock=\"$rock\",
    rock_ice=\"$rock_ice\",
    sapling=\"$sapling\",
    season_start=\"$season_start\",
    specialevent=\"$specialevent\",
    spiders=\"$spiders\",
    spring=\"$spring\",
    start_location=\"$start_location\",
    summer=\"$summer\",
    tallbirds=\"$tallbirds\",
    task_set=\"$task_set\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    tumbleweed=\"$tumbleweed\",
    walrus=\"$walrus\",
    weather=\"$weather\",
    wildfires=\"$wildfires\",
    winter=\"$winter\",
    world_size=\"$world_size\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/leveldataoverride.lua"
}

function setseason()
{
    season="default"
	read scaves
	case $scaves in
	    1)
		season="noseason";;
		2)
		season="veryshortseason";;
		3)
		season="shortseason";;
		4)
		season="longseason";;
		5)
		season="verylongseason";;
		6)
		season="random";;
	esac
}

function setcavesworld()
{
    echo -e "\e[92m请选择地图大小：1.小型 2.中等  默认（大型）直接按Enter 3.巨型\e[0m"
	world_size="default"
	read scaves
	case $scaves in
	    1)
		world_size="small";;
		2)
		world_size="medium";;
		3)
		world_size="huge";;
	esac
	echo -e "\e[92m请设置岔路地形：1.无 2.最少 默认直接按Enter 3.最多\e[0m"
	branching="default"
	read scaves
	case $scaves in
	    1)
		branching="never";;
		2)
		branching="least";;
		3)
		branching="most";;
	esac
	echo -e "\e[92m请设置环状地形：1.无  默认直接按Enter 2.总是\e[0m"
	loop="default"
	read scaves
	case $scaves in
	    1)
		loop="never";;
		2)
		loop="always";;
	esac
	echo -e "\e[92m请设置再生速度：1.极慢 2.慢 默认直接按Enter 3.快 4.极快\e[0m"
	regrowth="default"
	read scaves
	case $scaves in
	    1)
		regrowth="veryslow";;
		2)
		regrowth="slow";;
		3)
		regrowth="fast";;
		4)
		regrowth="veryfast";;
	esac
	echo -e "\e[92m请设置洞穴光照：1.极慢 2.慢 默认直接按Enter 3.快 4.极快\e[0m"
	cavelight="default"
	read scaves
	case $scaves in
	    1)
		cavelight="veryslow";;
		2)
		cavelight="slow";;
		3)
		cavelight="fast";;
		4)
		cavelight="veryfast";;
	esac
	echo -e "\e[92m请设置作物患病：1.无 2.随机 3.慢 默认直接按Enter 4.快\e[0m"
	disease_delay="default"
	read scaves
	case $scaves in
	    1)
		disease_delay="none";;
		2)
		disease_delay="random";;
		3)
		disease_delay="long";;
		4)
		disease_delay="short";;
	esac
	echo -e "\e[92m请设置初始资源多样性：1.经典 默认直接按Enter 2.高度随机\e[0m"
	prefabswaps_start="default"
	read scaves
	case $scaves in
	    1)
		prefabswaps_start="classic";;
		2)
		prefabswaps_start="highly random";;
	esac
	echo -e "\e[92m请设置树石化速率：1.无 2.慢 默认直接按Enter 3.快 4.极快\e[0m"
	petrification="default"
	read scaves
	case $scaves in
	    1)
		petrification="none";;
		2)
		petrification="few";;
		3)
		petrification="many";;
		4)
		petrification="max";;
	esac
	echo -e "\e[92m请设置前辈：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	boons="$preset"
	
	echo -e "\e[92m请设置复活台：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	touchstone="$preset"
	
	echo -e "\e[92m请设置雨：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	weather="$preset"
	
	echo -e "\e[92m请设置地震频率：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	earthquakes="$preset"
	
	echo -e "\e[92m请设置草：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	grass="$preset"
	
	echo -e "\e[92m请设置树枝：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	sapling="$preset"
	
	echo -e "\e[92m请设置尖刺灌木：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	marshbush="$preset"
	
	echo -e "\e[92m请设置芦苇：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	reeds="$preset"
	
	echo -e "\e[92m请设置树木：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	trees="$preset"	
	
	echo -e "\e[92m请设置燧石：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	flint="$preset"
	
	echo -e "\e[92m请设置岩石：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	rock="$preset"
	
	echo -e "\e[92m请设置蘑菇树：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	mushtree="$preset"
	
    echo -e "\e[92m请设置蕨类植物：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	fern="$preset"
	
	echo -e "\e[92m请设置荧光果：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	flower_cave="$preset"
	
    echo -e "\e[92m请设置发光浆果 ：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	wormlights="$preset"	

    echo -e "\e[92m请设置浆果丛：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	berrybush="$preset" 	
	
	echo -e "\e[92m请设置蘑菇：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	mushroom="$preset"
	
	echo -e "\e[92m请设置香蕉：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	banana="$preset"
	
	echo -e "\e[92m请设置苔藓：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	lichen="$preset"
	
	echo -e "\e[92m请设置洞穴池塘：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	cave_ponds="$preset"
	
	echo -e "\e[92m请设置啜食者：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	slurper="$preset"
	
	echo -e "\e[92m请设置兔人：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	bunnymen="$preset"
	
	echo -e "\e[92m请设置蜗牛：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	slurtles="$preset"
	
	echo -e "\e[92m请设置石虾：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	rocky="$preset"
	
	echo -e "\e[92m请设置猴子：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	monkey="$preset"  

    echo -e "\e[92m请设置洞穴蜘蛛：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	cave_spiders="$preset"		
	
	echo -e "\e[92m请设置触手：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	tentacles="$preset"	
	
	echo -e "\e[92m请设置齿轮马：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	chess="$preset"

	echo -e "\e[92m请设置树人：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	liefs="$preset"
	
	echo -e "\e[92m请设置蝙蝠：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	bats="$preset"     	
	
	echo -e "\e[92m请设置裂缝：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	fissure="$preset"
	
	echo -e "\e[92m请设置蠕虫袭击：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	wormattacks="$preset"
	
	echo -e "\e[92m请设置蠕虫：1.无 2.较少 默认直接按Enter 3.较多 4.大量\e[0m"
	setoverride
	worms="$preset"
	
    clear
	echo "return {
  background_node_range={ 0, 1 },
  desc=\"Delve into the caves... together!\",
  hideminimap=false,
  id=\"DST_CAVE\",
  location=\"cave\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"The Caves\",
  numrandom_set_pieces=0,
  override_level_string=false,
  overrides={
    banana=\"$banana\",
    bats=\"$bats\",
    berrybush=\"$berrybush\",
    boons=\"$boons\",
    branching=\"$branching\",
    bunnymen=\"$bunnymen\",
    cave_ponds=\"$cave_ponds\",
    cave_spiders=\"$cave_spiders\",
    cavelight=\"$cavelight\",
    chess=\"$chess\",
    disease_delay=\"$disease_delay\",
    earthquakes=\"$earthquakes\",
    fern=\"$fern\",
    fissure=\"$fissure\",
    flint=\"$flint\",
    flower_cave=\"$flower_cave\",
    grass=\"$grass\",
    layout_mode=\"RestrictNodesByKey\",
    lichen=\"$lichen\",
    liefs=\"$liefs\",
    loop=\"$loop\",
    marshbush=\"$marshbush\",
    monkey=\"$monkey\",
    mushroom=\"$mushroom\",
    mushtree=\"$mushtree\",
    petrification=\"$petrification\",
    prefabswaps_start=\"$prefabswaps_start\",
    reeds=\"$reeds\",
    regrowth=\"$regrowth\",
    roads=\"never\",
    rock=\"$rock\",
    rocky=\"$rocky\",
    sapling=\"$sapling\",
    season_start=\"default\",
    slurper=\"$slurper\",
    slurtles=\"$slurtles\",
    start_location=\"caves\",
    task_set=\"cave_default\",
    tentacles=\"$tentacles\",
    touchstone=\"$touchstone\",
    trees=\"$trees\",
    weather=\"$weather\",
    world_size=\"$world_size\",
    wormattacks=\"$wormattacks\",
    wormhole_prefab=\"tentacle_pillar\",
    wormlights=\"$wormlights\",
    worms=\"$worms\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves/leveldataoverride.lua"
}

function setoverride()
{
    preset="default"
	read s
	case $s in
	    1)
		preset="never";;
		2)
		preset="rare";;
		3)
		preset="often";;
		4)
		preset="always";;
	esac
}

function setworld()
{
	echo -e "\e[92m请选择要更改的地上世界设置：\e[0m"
	echo -e "\e[92m         1.经典（没有巨人ROG）\e[0m"
	echo -e "\e[92m         2.三箱（快速开局）\e[0m"
	echo -e "\e[92m         3.永夜\e[0m"
	echo -e "\e[92m         4.自定义（随心所欲）\e[0m"
	echo -e "\e[92m         5.默认\e[0m"
	read masterset
	case $masterset in
	    1)
		echo "return {
  desc=\"Don't Starve Together with Reign of Giants turned off.\",
  hideminimap=false,
  id=\"SURVIVAL_TOGETHER_CLASSIC\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"No Giants Here\",
  numrandom_set_pieces=4,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"default\",
    angrybees=\"default\",
    autumn=\"default\",
    bearger=\"never\",
    beefalo=\"default\",
    beefaloheat=\"default\",
    bees=\"default\",
    berrybush=\"default\",
    birds=\"default\",
    boons=\"default\",
    branching=\"default\",
    butterfly=\"default\",
    buzzard=\"never\",
    cactus=\"never\",
    carrot=\"default\",
    catcoon=\"never\",
    chess=\"default\",
    day=\"default\",
    deciduousmonster=\"never\",
    deerclops=\"default\",
    disease_delay=\"default\",
    dragonfly=\"never\",
    flint=\"default\",
    flowers=\"default\",
    frograin=\"never\",
    goosemoose=\"never\",
    grass=\"default\",
    houndmound=\"never\",
    hounds=\"default\",
    hunt=\"default\",
    krampus=\"default\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"default\",
    lightning=\"default\",
    lightninggoat=\"never\",
    loop=\"default\",
    lureplants=\"default\",
    marshbush=\"default\",
    merm=\"default\",
    meteorshowers=\"default\",
    meteorspawner=\"default\",
    moles=\"never\",
    mushroom=\"default\",
    penguins=\"default\",
    perd=\"default\",
    petrification=\"default\",
    pigs=\"default\",
    ponds=\"default\",
    prefabswaps_start=\"default\",
    rabbits=\"default\",
    reeds=\"default\",
    regrowth=\"default\",
    roads=\"default\",
    rock=\"default\",
    rock_ice=\"never\",
    sapling=\"default\",
    season_start=\"default\",
    specialevent=\"default\",
    spiders=\"default\",
    spring=\"noseason\",
    start_location=\"default\",
    summer=\"noseason\",
    tallbirds=\"default\",
    task_set=\"default\",
    tentacles=\"default\",
    touchstone=\"default\",
    trees=\"default\",
    tumbleweed=\"default\",
    walrus=\"default\",
    weather=\"default\",
    wildfires=\"never\",
    winter=\"default\",
    world_size=\"default\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/leveldataoverride.lua"	;;
		2)
		echo "return {
  desc=\"A quicker start in a harsher world.\",
  hideminimap=false,
  id=\"SURVIVAL_DEFAULT_PLUS\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"Together Plus\",
  numrandom_set_pieces=4,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"default\",
    angrybees=\"default\",
    autumn=\"default\",
    bearger=\"default\",
    beefalo=\"default\",
    beefaloheat=\"default\",
    bees=\"default\",
    berrybush=\"rare\",
    birds=\"default\",
    boons=\"often\",
    branching=\"default\",
    butterfly=\"default\",
    buzzard=\"default\",
    cactus=\"default\",
    carrot=\"rare\",
    catcoon=\"default\",
    chess=\"default\",
    day=\"default\",
    deciduousmonster=\"default\",
    deerclops=\"default\",
    disease_delay=\"default\",
    dragonfly=\"default\",
    flint=\"default\",
    flowers=\"default\",
    frograin=\"default\",
    goosemoose=\"default\",
    grass=\"default\",
    houndmound=\"default\",
    hounds=\"default\",
    hunt=\"default\",
    krampus=\"default\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"default\",
    lightning=\"default\",
    lightninggoat=\"default\",
    loop=\"default\",
    lureplants=\"default\",
    marshbush=\"default\",
    merm=\"default\",
    meteorshowers=\"default\",
    meteorspawner=\"default\",
    moles=\"default\",
    mushroom=\"default\",
    penguins=\"default\",
    perd=\"default\",
    petrification=\"default\",
    pigs=\"default\",
    ponds=\"default\",
    prefabswaps_start=\"default\",
    rabbits=\"rare\",
    reeds=\"default\",
    regrowth=\"default\",
    roads=\"default\",
    rock=\"default\",
    rock_ice=\"default\",
    sapling=\"default\",
    season_start=\"default\",
    specialevent=\"default\",
    spiders=\"often\",
    spring=\"default\",
    start_location=\"plus\",
    summer=\"default\",
    tallbirds=\"default\",
    task_set=\"default\",
    tentacles=\"default\",
    touchstone=\"default\",
    trees=\"default\",
    tumbleweed=\"default\",
    walrus=\"default\",
    weather=\"default\",
    wildfires=\"default\",
    winter=\"default\",
    world_size=\"default\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/leveldataoverride.lua";;
        3)
		echo "return {
  desc=\"A dark twist on the standard Don't Starve experience.\",
  hideminimap=false,
  id=\"COMPLETE_DARKNESS\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"Lights Out\",
  numrandom_set_pieces=4,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"default\",
    angrybees=\"default\",
    autumn=\"default\",
    bearger=\"default\",
    beefalo=\"default\",
    beefaloheat=\"default\",
    bees=\"default\",
    berrybush=\"default\",
    birds=\"default\",
    boons=\"default\",
    branching=\"default\",
    butterfly=\"default\",
    buzzard=\"default\",
    cactus=\"default\",
    carrot=\"default\",
    catcoon=\"default\",
    chess=\"default\",
    day=\"onlynight\",
    deciduousmonster=\"default\",
    deerclops=\"default\",
    disease_delay=\"default\",
    dragonfly=\"default\",
    flint=\"default\",
    flowers=\"default\",
    frograin=\"default\",
    goosemoose=\"default\",
    grass=\"default\",
    houndmound=\"default\",
    hounds=\"default\",
    hunt=\"default\",
    krampus=\"default\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"default\",
    lightning=\"default\",
    lightninggoat=\"default\",
    loop=\"default\",
    lureplants=\"default\",
    marshbush=\"default\",
    merm=\"default\",
    meteorshowers=\"default\",
    meteorspawner=\"default\",
    moles=\"default\",
    mushroom=\"default\",
    penguins=\"default\",
    perd=\"default\",
    petrification=\"default\",
    pigs=\"default\",
    ponds=\"default\",
    prefabswaps_start=\"default\",
    rabbits=\"default\",
    reeds=\"default\",
    regrowth=\"default\",
    roads=\"default\",
    rock=\"default\",
    rock_ice=\"default\",
    sapling=\"default\",
    season_start=\"default\",
    specialevent=\"default\",
    spiders=\"default\",
    spring=\"default\",
    start_location=\"default\",
    summer=\"default\",
    tallbirds=\"default\",
    task_set=\"default\",
    tentacles=\"default\",
    touchstone=\"default\",
    trees=\"default\",
    tumbleweed=\"default\",
    walrus=\"default\",
    weather=\"default\",
    wildfires=\"default\",
    winter=\"default\",
    world_size=\"default\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/leveldataoverride.lua";;
        4)
		setmasterworld;;
		5)
		echo "return {
  desc=\"The standard Don't Starve experience.\",
  hideminimap=false,
  id=\"SURVIVAL_TOGETHER\",
  location=\"forest\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"Default\",
  numrandom_set_pieces=4,
  ordered_story_setpieces={ \"Sculptures_1\", \"Maxwell5\" },
  override_level_string=false,
  overrides={
    alternatehunt=\"default\",
    angrybees=\"default\",
    autumn=\"default\",
    bearger=\"default\",
    beefalo=\"default\",
    beefaloheat=\"default\",
    bees=\"default\",
    berrybush=\"default\",
    birds=\"default\",
    boons=\"default\",
    branching=\"default\",
    butterfly=\"default\",
    buzzard=\"default\",
    cactus=\"default\",
    carrot=\"default\",
    catcoon=\"default\",
    chess=\"default\",
    day=\"default\",
    deciduousmonster=\"default\",
    deerclops=\"default\",
    disease_delay=\"default\",
    dragonfly=\"default\",
    flint=\"default\",
    flowers=\"default\",
    frograin=\"default\",
    goosemoose=\"default\",
    grass=\"default\",
    houndmound=\"default\",
    hounds=\"default\",
    hunt=\"default\",
    krampus=\"default\",
    layout_mode=\"LinkNodesByKeys\",
    liefs=\"default\",
    lightning=\"default\",
    lightninggoat=\"default\",
    loop=\"default\",
    lureplants=\"default\",
    marshbush=\"default\",
    merm=\"default\",
    meteorshowers=\"default\",
    meteorspawner=\"default\",
    moles=\"default\",
    mushroom=\"default\",
    penguins=\"default\",
    perd=\"default\",
    petrification=\"default\",
    pigs=\"default\",
    ponds=\"default\",
    prefabswaps_start=\"default\",
    rabbits=\"default\",
    reeds=\"default\",
    regrowth=\"default\",
    roads=\"default\",
    rock=\"default\",
    rock_ice=\"default\",
    sapling=\"default\",
    season_start=\"default\",
    specialevent=\"default\",
    spiders=\"default\",
    spring=\"default\",
    start_location=\"default\",
    summer=\"default\",
    tallbirds=\"default\",
    task_set=\"default\",
    tentacles=\"default\",
    touchstone=\"default\",
    trees=\"default\",
    tumbleweed=\"default\",
    walrus=\"default\",
    weather=\"default\",
    wildfires=\"default\",
    winter=\"default\",
    world_size=\"default\",
    wormhole_prefab=\"wormhole\" 
  },
  random_set_pieces={
    \"Sculptures_2\",
    \"Sculptures_3\",
    \"Sculptures_4\",
    \"Sculptures_5\",
    \"Chessy_1\",
    \"Chessy_2\",
    \"Chessy_3\",
    \"Chessy_4\",
    \"Chessy_5\",
    \"Chessy_6\",
    \"Maxwell1\",
    \"Maxwell2\",
    \"Maxwell3\",
    \"Maxwell4\",
    \"Maxwell6\",
    \"Maxwell7\",
    \"Warzone_1\",
    \"Warzone_2\",
    \"Warzone_3\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Master/leveldataoverride.lua";;
    esac
    echo -e "\e[92m请选择要更改的洞穴世界设置：\e[0m"
	echo -e "\e[92m         1.洞穴增强（危机四伏）\e[0m"
	echo -e "\e[92m         2.自定义（随心所欲）\e[0m"
	echo -e "\e[92m         3.默认 \e[0m"
	read cavesset
	case $cavesset in
		1)
		echo "return {
  background_node_range={ 0, 1 },
  desc=\"A darker, more arachnid-y cave experience.\",
  hideminimap=false,
  id=\"DST_CAVE_PLUS\",
  location=\"cave\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"Caves Plus\",
  numrandom_set_pieces=0,
  override_level_string=false,
  overrides={
    banana=\"default\",
    bats=\"default\",
    berrybush=\"rare\",
    boons=\"often\",
    branching=\"default\",
    bunnymen=\"default\",
	carrot=\"rare\",
    cave_ponds=\"default\",
    cave_spiders=\"often\",
    cavelight=\"default\",
    chess=\"default\",
    disease_delay=\"default\",
    earthquakes=\"default\",
    fern=\"default\",
    fissure=\"default\",
    flint=\"default\",
    flower_cave=\"rare\",
    grass=\"default\",
    layout_mode=\"RestrictNodesByKey\",
    lichen=\"default\",
    liefs=\"default\",
    loop=\"default\",
    marshbush=\"default\",
    monkey=\"default\",
    mushroom=\"default\",
    mushtree=\"default\",
    petrification=\"default\",
    prefabswaps_start=\"default\",
	rabbits=\"rare\",
    reeds=\"default\",
    regrowth=\"default\",
    roads=\"never\",
    rock=\"default\",
    rocky=\"default\",
    sapling=\"default\",
    season_start=\"default\",
    slurper=\"default\",
    slurtles=\"default\",
    start_location=\"caves\",
    task_set=\"cave_default\",
    tentacles=\"default\",
    touchstone=\"default\",
    trees=\"default\",
    weather=\"default\",
    world_size=\"default\",
    wormattacks=\"default\",
    wormhole_prefab=\"tentacle_pillar\",
    wormlights=\"rare\",
    worms=\"default\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves/leveldataoverride.lua";;
		2)
		setcavesworld;;
		3)
		echo "return {
  background_node_range={ 0, 1 },
  desc=\"Delve into the caves... together!\",
  hideminimap=false,
  id=\"DST_CAVE\",
  location=\"cave\",
  max_playlist_position=999,
  min_playlist_position=0,
  name=\"The Caves\",
  numrandom_set_pieces=0,
  override_level_string=false,
  overrides={
    banana=\"default\",
    bats=\"default\",
    berrybush=\"default\",
    boons=\"default\",
    branching=\"default\",
    bunnymen=\"default\",
    cave_ponds=\"default\",
    cave_spiders=\"default\",
    cavelight=\"default\",
    chess=\"default\",
    disease_delay=\"default\",
    earthquakes=\"default\",
    fern=\"default\",
    fissure=\"default\",
    flint=\"default\",
    flower_cave=\"default\",
    grass=\"default\",
    layout_mode=\"RestrictNodesByKey\",
    lichen=\"default\",
    liefs=\"default\",
    loop=\"default\",
    marshbush=\"default\",
    monkey=\"default\",
    mushroom=\"default\",
    mushtree=\"default\",
    petrification=\"default\",
    prefabswaps_start=\"default\",
    reeds=\"default\",
    regrowth=\"default\",
    roads=\"never\",
    rock=\"default\",
    rocky=\"default\",
    sapling=\"default\",
    season_start=\"default\",
    slurper=\"default\",
    slurtles=\"default\",
    start_location=\"caves\",
    task_set=\"cave_default\",
    tentacles=\"default\",
    touchstone=\"default\",
    trees=\"default\",
    weather=\"default\",
    world_size=\"default\",
    wormattacks=\"default\",
    wormhole_prefab=\"tentacle_pillar\",
    wormlights=\"default\",
    worms=\"default\" 
  },
  required_prefabs={ \"multiplayer_portal\" },
  substitutes={  },
  version=3 
}" > "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/Caves/leveldataoverride.lua" ;;
	esac
	
}

function createlistfile()
{
    echo " " > ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/adminlist.txt
	echo " " > ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/whitelist.txt
	echo " " > ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/blocklist.txt
}

function addlist()
{
    echo -e "\e[92m请输入你要添加的KLEIID（KU_XXXXXXX）：\e[0m"
	read kleiid
	if [[ $(grep "$kleiid" -c "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/$listfile") > 0 ]] ;then 
		echo -e "\e[92m名单已经存在！\e[0m"
	else
	    echo "$kleiid" >> ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/$listfile
	    echo -e "\e[92m名单添加完毕！\e[0m"
    fi
}

function dellist()
{
    echo "=========================================================================="
	grep "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/$listfile" -e "KU"
	echo -e "\e[92m请输入你要移除的KLEIID（KU_XXXXXXX）：\e[0m"
	read kleiid
	if [[ $(grep "$kleiid" -c "${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/$listfile") > 0 ]] ;then 
		sed -i "/$kleiid/d" ${DST_conf_basedir}/${DST_conf_dirname}/${cluster_name}/$listfile
		echo -e "\e[92m名单已移除！\e[0m"
	else
	    echo -e "\e[92m名单不存在！\e[0m"
	fi
}

function listmanager()
{
    echo -e "\e[92m已有存档：\e[0m"
	ls -l ${DST_conf_basedir}/${DST_conf_dirname} | awk '/^d/ {print $NF}'
	echo -e "\e[92m请输入要设置的存档：\e[0m"
	read clustername
	cluster_name=$clustername
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
	
    for i in $(grep "workshop" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua" | cut -d '"' -f 2 | cut -d '-' -f 2)
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
		if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua") > 0 ]]
		then 
			echo "地上世界该Mod已添加"
		else
			sed -i "2i [\"workshop-$modid\"]={ configuration_options={  }, enabled=true }," ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua
		    echo "地上世界Mod添加完成"
		fi
		if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Caves/modoverrides.lua") > 0 ]]
		then 
			echo "洞穴世界该Mod已添加"
		else
			sed -i "2i [\"workshop-$modid\"]={ configuration_options={  }, enabled=true }," ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Caves/modoverrides.lua
		    echo "洞穴世界Mod添加完成"
		fi
		echo "" >> "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua"
        if [[ $(grep "$modid" -c "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua") > 0 ]] ;then 
		    echo "" >> "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua"
		else	
            echo "ServerModSetup(\"$modid\")" >> "${DST_conf_basedir}/${DST_conf_dirname}/mods_setup.lua"
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
		if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua") > 0 ]]
		then 
			sed -i "/$modid/d" ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua
			echo "地上世界Mod移除完成"
		else
			echo "地上世界该Mod未添加"
		fi
		if [[ $(grep "$modid" "${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Caves/modoverrides.lua") > 0 ]]
		then 
			sed -i "/$modid/d" ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Caves/modoverrides.lua
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
}" > ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Master/modoverrides.lua
	echo "return {
[\"workshop-1301033176\"]={ configuration_options={  }, enabled=true }
}" > ${DST_conf_basedir}/${DST_conf_dirname}/$cluster_name/Caves/modoverrides.lua	
}

function console()
{
    if tmux has-session -t DST_Master > /dev/null 2>&1; then 
	    echo "当前世界不是主世界，请在主世界所在服务器操作"
		menu
	fi
    echo -e "\e[92m已有存档：\e[0m"
	ls -l ${DST_conf_basedir}/${DST_conf_dirname} |awk '/^d/ {print $NF}'
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
	    tmux send-keys -t DST_Master "c_announce(\"服务器设置因做了改动需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
	fi
	if tmux has-session -t DST_Caves > /dev/null 2>&1; then						        
		tmux send-keys -t DST_Caves "c_announce(\"服务器设置因做了改动需要重启，预计耗时三分钟，给你带来的不便还请谅解！\")" C-m
	fi
}

function deldir()
{
    echo -e "\e[92m已有存档：\e[0m"
	ls -l ${DST_conf_basedir}/${DST_conf_dirname} |awk '/^d/ {print $NF}'
	echo -e "\e[92m请输入要删除的存档[请谨慎选择]：\e[0m"
	read clustername
	rm -rf ${DST_conf_basedir}/${DST_conf_dirname}/$clustername
	echo -e "\e[92m存档删除完毕！\e[0m"
}

function listallplayer()
{	
    playernumber=$( date +%s%3N )
	tmux send-keys -t DST_Master "c_printplayersnumber($playernumber)" C-m
	if [[ $( grep "${DST_conf_basedir}/${DST_conf_dirname}/$clustername/Master/server_log.txt" -e "$playernumber" | cut -d ':' -f 6 ) > 0 ]]; then
	    sleep 3
		playerlist=$( date +%s%3N )
	   tmux send-keys -t DST_Master "c_printplayerlist($playerlist)" C-m
	    echo -e "\e[92m============================================================\e[0m"
        grep "${DST_conf_basedir}/${DST_conf_dirname}/$clustername/Master/server_log.txt" -e "$playerlist" | cut -d ' ' -f 2-6 | tail -n +2
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

function rebootserver(){
	cluster_name=$(cat $HOME/dst.conf|grep clustername|cut -d "=" -f2)
	shard=$(cat $HOME/dst.conf|grep shard|cut -d "=" -f2)
	startshard
	startcheck
}
# 脚本更新
Update_shell(){
	cur_ver=$shell_ver
    info "当前版本为 [ ${cur_ver} ]，开始检测最新版本..."
    new_ver=$(wget --no-check-certificate -qO- https://raw.githubusercontent.com/ariwori/dstscript/master/DSTServer.sh|grep "^shell_ver=" |cut -d '=' -f2)
    [[ -z ${new_ver} ]] && tip "检测最新版本失败 !" && new_ver=$cur_ver
    if [[ ${new_ver} != ${cur_ver} ]]; then
        info "发现新版本[ ${new_ver} ]，更新中..."
        wget https://raw.githubusercontent.com/ariwori/dstscript/master/DSTServer.sh -O $HOME/DSTServer.sh
    	chmod +x $HOME/DSTServer.sh
        info "已更新为最新版本[ ${new_ver} ] !"
    else
        info "当前已是最新版本[ ${new_ver} ] !"
    fi
}
function menu()
{    
    while :
    do
	    echo -e "\e[33m================欢迎使用饥荒联机版独立服务器脚本[Linux-Steam]==================\e[0m"
        echo
		echo -e "\e[33m作者：Ariwori        Bug反馈：https://blog.wqlin.com/dstscript.html\e[0m"
		echo -e "\e[33m本脚本一切权利归作者所有。未经许可禁止使用本脚本进行任何的商业活动！\e[0m"
		echo
		echo -e "\e[31m首次使用请将本地电脑上的MOD上传到\e[0m"
		echo -e "\e[31m云服务器$HOME/DSTServer/mods目录下\e[0m"
		echo
        echo -e "\e[92m[1]启动服务器           [2]关闭服务器         [3]重启服务器\e[0m"  
        echo -e "\e[92m[4]查看游戏服务器状态   [5]添加或移除MOD      [6]设置管理员和黑名单\e[0m"
		echo -e "\e[92m[7]控制台               [8]自动更新   [9]退出本脚本\e[0m"
		echo -e "\e[92m[10]删除存档            [11]开启虚拟内存（单服务器开洞穴使用）\e[0m"
		echo -e "\e[92m[1２]更新游戏服务端(MOD更新一般重启即可)		  [13]更新脚本\e[0m"
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
	            ls -l ${DST_conf_basedir}/${DST_conf_dirname} |awk '/^d/ {print $NF}'
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
				echo "该功能已移除，请使用手动更新命令！"
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
				closeserver
				Update_DST
				break;;
				13)
				Update_shell
				break;;			
		    esac
    done
}

menu
