#!/usr/bin/env bash
#===============================================================================
#	System Required: Debian 7+/Ubuntu 14.04+
#	Description: Install and manager the Don't Starve Together Dedicated Server
#	Version: 2.0.0 2018-06-01 23:35:46
#	Author: Ariwori
#	Blog: https://blog.wqlin.com/dstscript.html
#===============================================================================

sh_ver="2.0.0"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
steamcmd_folder="${filepath}/steamcmd"
config_folder="${filepath}/.dst"
game_folder="${filepath}/dstdedicatedserver"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"
Separator_1="——————————————————————————————"

check_root(){
	[[ $EUID == 0 ]] && echo -e "${Tip} 当前账号为ROOT，存在安全隐患，如你使用非本人提供的来源获取的脚本出现任何问题，本人概不负责！"
}
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
DST_installation_status(){
	[[ ! -e ${steamcmd_folder} ]] && echo -e "${Error} 没有发现 Steamcmd 文件夹，请检查！" && exit 1
}
# 读取 配置信息
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
# 写入 配置信息
Init_configuration(){
	[[ ! -e ${config_folder} ]] && mkdir $config_folder
	cat > ${config_folder}/default_cave_level.json<<-EOF
[
	{"name":"boons","value":"default","type":"environment","cn_str":"前辈遗迹"},
	{"name":"branching","value":"default","type":"environment","cn_str":"岔路地形"},
	{"name":"cavelight","value":"default","type":"environment","cn_str":"洞穴光照"},
	{"name":"disease_delay","value":"default","type":"environment","cn_str":"作物患病"},
	{"name":"earthquakes","value":"default","type":"environment","cn_str":"地震频率"},
	{"name":"loop","value":"default","type":"environment","cn_str":"环状地形"},
	{"name":"petrification","value":"default","type":"environment","cn_str":"石化速率"},
	{"name":"prefabswaps_start","value":"default","type":"environment","cn_str":"初始多样性"},
	{"name":"regrowth","value":"default","type":"environment","cn_str":"资源再生"},
	{"name":"touchstone","value":"default","type":"environment","cn_str":"猪头祭坛"},
	{"name":"weather","value":"default","type":"environment","cn_str":"雨"},
	{"name":"world_size","value":"default","type":"environment","cn_str":"地图大小"},
	{"name":"wormlights","value":"default","type":"environment","cn_str":"发光浆果"},
	{"name":"banana","value":"default","type":"food","cn_str":"香蕉"},
	{"name":"berrybush","value":"often","type":"food","cn_str":"浆果丛"},
	{"name":"lichen","value":"default","type":"food","cn_str":"苔藓"},
	{"name":"mushroom","value":"default","type":"food","cn_str":"蘑菇"},
	{"name":"bunnymen","value":"default","type":"animal","cn_str":"兔人"},
	{"name":"cave_ponds","value":"default","type":"animal","cn_str":"洞穴池塘"},
	{"name":"monkey","value":"default","type":"animal","cn_str":"猴子"},
	{"name":"rocky","value":"default","type":"animal","cn_str":"石虾"},
	{"name":"slurper","value":"default","type":"animal","cn_str":"啜食者"},
	{"name":"slurtles","value":"default","type":"animal","cn_str":"蜗牛"},
	{"name":"bats","value":"default","type":"monster","cn_str":"蝙蝠"},
	{"name":"cave_spiders","value":"default","type":"monster","cn_str":"洞穴蜘蛛"},
	{"name":"chess","value":"default","type":"monster","cn_str":"齿轮怪"},
	{"name":"fissure","value":"default","type":"monster","cn_str":"影怪裂缝"},
	{"name":"liefs","value":"default","type":"monster","cn_str":"树精"},
	{"name":"tentacles","value":"never","type":"monster","cn_str":"触手怪"},
	{"name":"wormattacks","value":"default","type":"monster","cn_str":"蠕虫袭击"},
	{"name":"worms","value":"default","type":"monster","cn_str":"蠕虫"}
]
EOF
	cat > ${config_folder}/default_forest_level.json<<-EOF
[
	{"name":"autumn","value":"default","type":"environment","cn_str":"秋天"},
	{"name":"boons","value":"default","type":"environment","cn_str":"前辈遗迹"},
	{"name":"branching","value":"default","type":"environment","cn_str":"岔路地形"},
	{"name":"day","value":"default","type":"environment","cn_str":"昼夜长短"},
	{"name":"disease_delay","value":"default","type":"environment","cn_str":"作物患病"},
	{"name":"frograin","value":"default","type":"environment","cn_str":"青蛙雨"},
	{"name":"lightning","value":"default","type":"environment","cn_str":"闪电"},
	{"name":"loop","value":"default","type":"environment","cn_str":"环状地形"},
	{"name":"petrification","value":"default","type":"environment","cn_str":"石化速率"},
	{"name":"regrowth","value":"default","type":"environment","cn_str":"资源再生"},
	{"name":"season_start","value":"default","type":"environment","cn_str":"初始季节"},
	{"name":"specialevent","value":"default","type":"environment","cn_str":"节日活动"},
	{"name":"spring","value":"default","type":"environment","cn_str":"春天"},
	{"name":"start_location","value":"default","type":"environment","cn_str":"初始环境"},
	{"name":"summer","value":"default","type":"environment","cn_str":"夏天"},
	{"name":"touchstone","value":"default","type":"environment","cn_str":"猪头祭坛"},
	{"name":"weather","value":"default","type":"environment","cn_str":"雨"},
	{"name":"wildfires","value":"default","type":"environment","cn_str":"自燃"},
	{"name":"winter","value":"default","type":"environment","cn_str":"冬天"},
	{"name":"world_size","value":"default","type":"environment","cn_str":"地图大小"},
	{"name":"prefabswaps_start","value":"default","type":"environment","cn_str":"初始多样性"},
	{"name":"roads","value":"default","type":"environment","cn_str":"道路"},
	{"name":"task_set","value":"default","type":"environment","cn_str":"生物群落"},
	{"name":"berrybush","value":"default","type":"food","cn_str":"浆果丛"},
	{"name":"cactus","value":"default","type":"food","cn_str":"仙人掌"},
	{"name":"carrot","value":"default","type":"food","cn_str":"胡萝卜"},
	{"name":"mushroom","value":"default","type":"food","cn_str":"蘑菇"},
	{"name":"angrybees","value":"default","type":"animal","cn_str":"杀人蜂"},
	{"name":"beefalo","value":"default","type":"animal","cn_str":"皮费罗牛"},
	{"name":"bees","value":"default","type":"animal","cn_str":"蜜蜂"},
	{"name":"birds","value":"default","type":"animal","cn_str":"鸟"},
	{"name":"butterfly","value":"default","type":"animal","cn_str":"蝴蝶"},
	{"name":"buzzard","value":"default","type":"animal","cn_str":"秃鹫"},
	{"name":"catcoon","value":"default","type":"animal","cn_str":"浣猫"},
	{"name":"hunt","value":"default","type":"animal","cn_str":"狼/羊/象"},
	{"name":"lightninggoat","value":"default","type":"animal","cn_str":"电羊"},
	{"name":"moles","value":"default","type":"animal","cn_str":"鼹鼠"},
	{"name":"penguins","value":"default","type":"animal","cn_str":"企鹅"},
	{"name":"perd","value":"default","type":"animal","cn_str":"火鸡"},
	{"name":"pigs","value":"default","type":"animal","cn_str":"猪人"},
	{"name":"rabbits","value":"default","type":"animal","cn_str":"兔子"},
	{"name":"tallbirds","value":"default","type":"animal","cn_str":"高脚鸟"},
	{"name":"beefaloheat","value":"default","type":"animal","cn_str":"牛发情频率"},
	{"name":"antliontribute","value":"default","type":"monster","cn_str":"蚁狮事件"},
	{"name":"bearger","value":"rare","type":"monster","cn_str":"熊"},
	{"name":"chess","value":"default","type":"monster","cn_str":"齿轮怪"},
	{"name":"deciduousmonster","value":"default","type":"monster","cn_str":"桦树精"},
	{"name":"deerclops","value":"default","type":"monster","cn_str":"独眼巨鹿"},
	{"name":"dragonfly","value":"default","type":"monster","cn_str":"龙蝇"},
	{"name":"goosemoose","value":"default","type":"monster","cn_str":"鹿角鹅"},
	{"name":"houndmound","value":"default","type":"monster","cn_str":"猎犬丘"},
	{"name":"hounds","value":"default","type":"monster","cn_str":"猎犬袭击"},
	{"name":"krampus","value":"default","type":"monster","cn_str":"坎普斯"},
	{"name":"liefs","value":"default","type":"monster","cn_str":"树精"},
	{"name":"lureplants","value":"default","type":"monster","cn_str":"食人花"},
	{"name":"merm","value":"default","type":"monster","cn_str":"鱼人"},
	{"name":"spiders","value":"default","type":"monster","cn_str":"蜘蛛"},
	{"name":"tentacles","value":"default","type":"monster","cn_str":"触手怪"},
	{"name":"walrus","value":"default","type":"monster","cn_str":"海象"}
]
EOF
	cat > ${config_folder}/world_level_options.json<<-EOF
{
	"roads_options":[
		{"value":"never","cn_str":"无"},
		{"value":"default","cn_str":"有"}
	],
	"cavelight_options":[
		{"value":"veryslow","cn_str":"极慢"},
		{"value":"slow","cn_str":"慢"},
		{"value":"default","cn_str":"默认"},
		{"value":"fast","cn_str":"快"},
		{"value":"veryfast","cn_str":"极快"}
	],
	"prefabswaps_start":[
		{"value":"classic","cn_str":"经典"},
		{"value":"highlyrandom","cn_str":"高度随机"},
		{"value":"default","cn_str":"默认"}
	],
	"world_size_options":[
		{"value":"small","cn_str":"小型"},
		{"value":"medium","cn_str":"中等"},
		{"value":"default","cn_str":"大型"},
		{"value":"huge","cn_str":"巨型"}
	],
	"task_set_option":[
		{"value":"classic","cn_str":"没有巨人"},
		{"value":"default","cn_str":"联机"}
	],
	"petrification_options":[
		{"value":"default","cn_str":"默认"},
		{"value":"none","cn_str":"无"},
		{"value":"few","cn_str":"慢"},
		{"value":"many","cn_str":"快"},
		{"value":"max","cn_str":"极快"}
	],
	"regrowth_options":[
		{"value":"veryslow","cn_str":"极慢"},
		{"value":"slow","cn_str":"慢"},
		{"value":"default","cn_str":"默认"},
		{"value":"fast","cn_str":"快"},
		{"value":"veryfast","cn_str":"极快"}
	],
	"disease_delay_options":[
		{"value":"default","cn_str":"默认"},
		{"value":"none","cn_str":"无"},
		{"value":"random","cn_str":"随机"},
		{"value":"long","cn_str":"慢"},
		{"value":"short","cn_str":"快"}
	],
	"default_options":[
		{"value":"never","cn_str":"无"},
		{"value":"rare","cn_str":"较少"},
		{"value":"default","cn_str":"默认"},
		{"value":"often","cn_str":"较多"},
		{"value":"always","cn_str":"大量"}
	],
	"season_start_options":[
		{"value":"default","cn_str":"秋季"},
		{"value":"winter","cn_str":"冬季"},
		{"value":"spring","cn_str":"春季"},
		{"value":"summer","cn_str":"夏季"},
		{"value":"autumnorspring","cn_str":"秋或春"},
		{"value":"winterorsummer","cn_str":"冬或夏"},
		{"value":"random","cn_str":"随机"}
	],
	"start_location_options":[
		{"value":"default","cn_str":"默认"},
		{"value":"plus","cn_str":"三箱"},
		{"value":"darkness","cn_str":"永夜"}
	],
	"winter_options":[
		{"value":"noseason","cn_str":"无"},
		{"value":"veryshortseason","cn_str":"很短"},
		{"value":"shortseason","cn_str":"短"},
		{"value":"longseason","cn_str":"长"},
		{"value":"verylongseason","cn_str":"很长"},
		{"value":"random","cn_str":"随机"},
		{"value":"default","cn_str":"默认"}
	],
	"summer_options":[
		{"value":"noseason","cn_str":"无"},
		{"value":"veryshortseason","cn_str":"很短"},
		{"value":"shortseason","cn_str":"短"},
		{"value":"longseason","cn_str":"长"},
		{"value":"verylongseason","cn_str":"很长"},
		{"value":"random","cn_str":"随机"},
		{"value":"default","cn_str":"默认"}
	], 
	"spring_options":[
		{"value":"noseason","cn_str":"无"},
		{"value":"veryshortseason","cn_str":"很短"},
		{"value":"shortseason","cn_str":"短"},
		{"value":"longseason","cn_str":"长"},
		{"value":"verylongseason","cn_str":"很长"},
		{"value":"random","cn_str":"随机"},
		{"value":"default","cn_str":"默认"}
	],
	"autumn_options":[
		{"value":"noseason","cn_str":"无"},
		{"value":"veryshortseason","cn_str":"很短"},
		{"value":"shortseason","cn_str":"短"},
		{"value":"longseason","cn_str":"长"},
		{"value":"verylongseason","cn_str":"很长"},
		{"value":"random","cn_str":"随机"},
		{"value":"default","cn_str":"默认"}
	],
	"day_options":[
		{"value":"longday","cn_str":"长白昼"},
		{"value":"longdusk","cn_str":"长黄昏"},
		{"value":"longnight","cn_str":"长夜晚"},
		{"value":"noday","cn_str":"无白昼"},
		{"value":"nodusk","cn_str":"无黄昏"},
		{"value":"nonight","cn_str":"无夜晚"},
		{"value":"onlyday","cn_str":"仅白昼"},
		{"value":"onlydusk","cn_str":"仅黄昏"},
		{"value":"onlynight","cn_str":"仅夜晚"}
	],
	"specialevent_options":[
		{"value":"none","cn_str":"无"},
		{"value":"default","cn_str":"自动"},
		{"value":"hallowed_nights","cn_str":"万圣夜"},
		{"value":"winters_feast","cn_str":"冬季盛宴"},
		{"value":"winters_feast","cn_str":"鸡年活动"},
		{"value":"winters_feast","cn_str":"狗年活动"}
	]
}
EOF
	cat > ${config_folder}/playerlist.json<<-EOF
{
	"adminlist":[
		{"kleiid":"KU_xxxxxx","steamid":"64位ID","nickname":"昵称"}
	],
	"whitelist":[
		{"kleiid":"KU_xxxxxx","steamid":"64位ID","nickname":"昵称"}
	],
	"blocklist":[
		{"kleiid":"KU_xxxxxx","steamid":"64位ID","nickname":"昵称"}
	],
	"historylist":[
		{"kleiid":"KU_xxxxxx","steamid":"64位ID","nickname":"昵称"}
	]
}
EOF
}
Update_DST(){
	DST_installation_status
	echo -e "${Info} 开始安装/更新 DST Dedicated Server ..."
	info "安装/更新游戏服务端。。。"
	cd $steamcmd_folder
	./steamcmd.sh +login anonymous +force_install_dir ${game_folder} +app_update 343050 validate +quit
	cd
	echo "${Tips} 请根据提示判断是否更新完毕！"
}
}
Install_Steamcmd(){
	[[ ! -e ${steamcmd_folder} ]] && mkdir ${steamcmd_folder}
	cd ${steamcmd_folder}
	curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
	[[ ! -e "~/steamcmd/steamcmd.sh" ]] && echo "${Error} Steamcmd 下载失败，请检查！" && exit 1
	cd
	echo "${Info} 开始安装 Steamcmd 依赖 ..."
	if [[ ${bit} = "x86_64" ]]; then
		sudo apt install -y lib32stdc++6 lib32gcc1
	else
		sudo apt install -y libgcc1 libstdc++6
	fi
	echo -e "${Info} Steamcmd 安装完成 !"
}
# 安装 JQ解析器
JQ_install(){
	if [[ ! -e ${jq_file} ]]; then
		cd "${DST_folder}"
		if [[ ${bit} = "x86_64" ]]; then
			wget --no-check-certificate "http://ozwsnihn1.bkt.clouddn.com/jq-linux64"
		else
			wget --no-check-certificate "http://ozwsnihn1.bkt.clouddn.com/jq-linux32"
		fi
		sudo mv jq_linux* /usr/bin/jq
		[[ ! -e "/usr/bin/jq" ]] && echo -e "${Error} JQ解析器 下载失败，请检查 !" && exit 1
		sudo chmod +x /usr/bin/jq
		echo -e "${Info} JQ解析器 安装完成，继续 ..." 
	else
		echo -e "${Info} JQ解析器 已安装，继续 ..."
	fi
}
# 安装 依赖
Installation_dependency(){
	sudo apt update
	sudo apt install -y wget curl tar screen 
	[[ ! -e "/usr/bin/screen" ]] && echo -e "${Error} 依赖 screen(多窗口管理) 安装失败，多半是软件包源的问题，请检查 !" && exit 1
}
Install_DST(){
	check_root
	[[ -e ${config_user_file} ]] && echo -e "${Error} DST Dedicated Server 文件夹已存在，请检查( 如安装失败或者存在旧版本，请先卸载 ) !" && exit 1
	[[ -e ${DST_folder} ]] && echo -e "${Error}  Steamcmd 文件夹已存在，请检查( 如安装失败或者存在旧版本，请先卸载 ) !" && exit 1
	echo -e "${Info} 开始更新服务器软件库及安装脚本必须软件 ..."
	Install_dependency
	echo -e "${Info} 开始下载/安装 JSNO解析器 JQ ..."
	JQ_install
	echo -e "${Info} 开始下载/安装 Steamcmd 及其依赖 ..."
	Install_Steamcmd
	echo -e "${Info} 开始下载/安装 DST Dedicated Server ..."
	Update_DST
	echo -e "${Info} 开始初始化脚本配置文件..."
	Init_configuration
	echo -e "${Info} 所有步骤 安装完毕，可以创建你的饥荒世界了 ..."
}
Uninstall_DST(){
	[[ ! -e ${config_user_file} ]] && [[ ! -e ${DST_folder} ]] && echo -e "${Error} 没有安装 ShadowsocksR，请检查 !" && exit 1
	echo "确定要 卸载ShadowsocksR？[y/N]" && echo
	stty erase '^H' && read -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		if [[ -z "${now_mode}" ]]; then
			port=`${jq_file} '.server_port' ${config_user_file}`
			Del_iptables
		else
			user_total=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | wc -l`
			for((integer = 1; integer <= ${user_total}; integer++))
			do
				port=`${jq_file} '.port_password' ${config_user_file} | sed '$d' | sed "1d" | awk -F ":" '{print $1}' | sed -n "${integer}p" | sed -r 's/.*\"(.+)\".*/\1/'`
				Del_iptables
			done
		fi
		if [[ ${release} = "centos" ]]; then
			chkconfig --del DST
		else
			update-rc.d -f DST remove
		fi
		rm -rf ${DST_folder} && rm -rf ${config_folder} && rm -rf /etc/init.d/DST
		echo && echo " ShadowsocksR 卸载完成 !" && echo
	else
		echo && echo " 卸载已取消..." && echo
	fi
}
Start_DST(){
	DST_installation_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ShadowsocksR 正在运行 !" && exit 1
	/etc/init.d/DST start
	check_pid
	[[ ! -z ${PID} ]] && View_User
}
Stop_DST(){
	DST_installation_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ShadowsocksR 未运行 !" && exit 1
	/etc/init.d/DST stop
}
Restart_DST(){
	DST_installation_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/DST stop
	/etc/init.d/DST start
	check_pid
	[[ ! -z ${PID} ]] && View_User
}
View_Log(){
	DST_installation_status
	[[ ! -e ${DST_log_file} ]] && echo -e "${Error} ShadowsocksR日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo
	tail -f ${DST_log_file}
}
Update_Shell(){
	echo -e "当前版本为 [ ${sh_ver} ]，开始检测最新版本..."
	sh_new_ver=$(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/GoforDance/dstserver/master/shell/dst.sh" |grep 'sh_ver="' |awk -F "=" '{print $NF}' |sed 's/\"//g' |head -1) && sh_new_type="github"
	[[ -z ${sh_new_ver} ]] && sh_new_ver=$(wget --no-check-certificate -qO- "http://ozwsnihn1.bkt.clouddn.com/dst.sh" |grep 'sh_ver="' |awk -F "=" '{print $NF}' |sed 's/\"//g' |head -1) && sh_new_type="qiniu"
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 检测最新版本失败 !" && exit 0
	if [[ ${sh_new_ver} != ${sh_ver} ]]; then
		echo -e "发现新版本[ ${sh_new_ver} ]，是否更新？[Y/n]"
		stty erase '^H' && read -p "(默认: y):" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			if [[ $sh_new_type == "qiniu" ]]; then
				wget -N --no-check-certificate http://ozwsnihn1.bkt.clouddn.com/dst.sh && chmod +x dst.sh
			else
				wget -N --no-check-certificate https://raw.githubusercontent.com/GoforDance/dstserver/master/shell/dst.sh && chmod +x dst.sh
			fi
			echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !"
		else
			echo && echo "	已取消..." && echo
		fi
	else
		echo -e "当前已是最新版本[ ${sh_new_ver} ] !"
	fi
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本暂不支持当前系统 ${release} !" && exit 1
echo -e "  DST Dedicated Server 一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  ---- GoforDream | blog.wqlin.com/dst-shell.html ----

  ${Green_font_prefix}1.${Font_color_suffix} 安装 DST Dedicated Server
  ${Green_font_prefix}2.${Font_color_suffix} 更新 DST Dedicated Server
  ${Green_font_prefix}3.${Font_color_suffix} 卸载 DST Dedicated Server
  ${Green_font_prefix}4.${Font_color_suffix} 更新  DST Dedicated Server MOD
————————————
  ${Green_font_prefix}5.${Font_color_suffix} 查看 账号信息
  ${Green_font_prefix}6.${Font_color_suffix} 显示 连接信息
  ${Green_font_prefix}7.${Font_color_suffix} 设置 用户配置
  ${Green_font_prefix}8.${Font_color_suffix} 手动 修改配置
  ${Green_font_prefix}9.${Font_color_suffix} 切换 端口模式
————————————
 ${Green_font_prefix}10.${Font_color_suffix} 启动 ShadowsocksR
 ${Green_font_prefix}11.${Font_color_suffix} 停止 ShadowsocksR
 ${Green_font_prefix}12.${Font_color_suffix} 重启 ShadowsocksR
 ${Green_font_prefix}13.${Font_color_suffix} 查看 ShadowsocksR 日志
————————————
 ${Green_font_prefix}14.${Font_color_suffix} 其他功能
 ${Green_font_prefix}15.${Font_color_suffix} 升级脚本
 "
menu_status
echo && stty erase '^H' && read -p "请输入数字 [1-15]：" num
case "$num" in
	1)
	Install_DST
	;;
	2)
	Update_DST
	;;
	3)
	Uninstall_DST
	;;
	4)
	Install_Libsodium
	;;
	5)
	View_User
	;;
	6)
	View_user_connection_info
	;;
	7)
	Modify_Config
	;;
	8)
	Manually_Modify_Config
	;;
	9)
	Port_mode_switching
	;;
	10)
	Start_DST
	;;
	11)
	Stop_DST
	;;
	12)
	Restart_DST
	;;
	13)
	View_Log
	;;
	14)
	Other_functions
	;;
	15)
	Update_Shell
	;;
	*)
	echo -e "${Error} 请输入正确的数字 [1-15]"
	;;
esac