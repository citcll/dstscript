#
#!/bin/bash
#
sudo apt update
sudo apt install -y git
info(){ echo -e "\e[92m[$(date "+%T") 信息] \e[0m$1"; }
info "下载脚本文件。。。"
git clone https://github.com/GoforDance/dst.git $HOME/dst >/dev/null 2>&1
[ $? -gt 0 ] && info "下载完成，安装中。。。"
echo "alias dst=\"bash $HOME/dst/shell/dst.sh\"" >> $HOME/.bashrc
rm install.sh
sudo chmod +x $HOME/dst/shell/*.sh
info "安装完成,更多请访问https://blog.wqlin.com"
