date
curl -s https://forums.kleientertainment.com/game-updates/dst/ | grep 'data-releaseID=' | cut -d '/' -f6 | cut -d "-" -f1 | sort | tail -n 1
date
cd ${HOME}/steamcmd || exit 1
./steamcmd.sh +login "anonymous" +force_install_dir "${dst_server_dir}" +app_update "343050" validate +quit
date