date
curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep 'data-releaseID=' | cut -d '/' -f6 | cut -d "-" -f1 | sort | tail -n 1
date
cd ${HOME}/steamcmd || exit 1
./steamcmd.sh +login "anonymous" +force_install_dir "${dst_server_dir}" +app_update "343050" validate +quit
date

# Gets availablebuild info
	cd "${steamcmddir}" || exit
	availablebuild=$(./steamcmd.sh +login "${steamuser}" "${steampass}" +app_info_update 1 +app_info_print "${appid}" +app_info_print "${appid}" +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
	if [ -z "${availablebuild}" ]; then
		fn_print_fail "Checking for update: SteamCMD"
		sleep 0.5
		fn_print_fail_nl "Checking for update: SteamCMD: Not returning version info"
		fn_script_log_fatal "Checking for update: SteamCMD: Not returning version info"
		core_exit.sh
	else
		fn_print_ok "Checking for update: SteamCMD"
		fn_script_log_pass "Checking for update: SteamCMD"
		sleep 0.5
	fi