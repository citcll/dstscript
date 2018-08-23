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
			cmd=$[$cmd + 1]
			changelist=($(sed -n "${cmd}p" $dst_cluster_file))
   			#echo ${changelist[4]}
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
configure_file="dstscript/cavesleveldata.txt"
dst_cluster_file="dstscript/clusterdata.txt"
Set_world_config
#Set_cluster