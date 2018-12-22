#!/bin/bash
# Author: Ariwori 2018-08-21 21:29:31
# 国内访问Steam社区受限，故写此脚本拉取DST模组版本信息用于自动更新
workshop_mainlink='https://steamcommunity.com/workshop/browse/?appid=322330&browsesort=trend&section=readytouseitems'
page_num=$(curl -s $workshop_mainlink | grep -A 1 '<div class="workshopBrowsePagingControls">' |cut -d ">" -f8 |cut -d '<' -f1)
i=1
index=1
while(true); do
    while [ $page_num -gt $i ]; do
        echo "`date` 采集第 $i 页数据 ..."
        curl -s "${workshop_mainlink}&actualsort=trend&p=$i" > /tmp/per_page_temp.tmp
        for id in $(cat /tmp/per_page_temp.tmp |grep '<div class="workshopItemTitle ellipsis">' |cut -d '=' -f3 |cut -d '&' -f1); do
            curl -s "https://steamcommunity.com/sharedfiles/filedetails/?id=$id" > /tmp/per_id_temp.tmp
            version=$(cat "/tmp/per_id_temp.tmp" | grep '">Version:' | head -n 1 |cut -d 'V' -f2 |cut -d : -f2|cut -d '<' -f1)
            name=$(cat "/tmp/per_id_temp.tmp" | grep "workshopItemTitle" | cut -d">" -f2 | cut -d"<" -f1)
            echo "$index. $id——$name（$version）"            
            echo "{\"modid\":\"$id\",\"name\":\"$name\",\"version\":\"$version\"}" > $HOME/www/dstmod/$id
            let index++ 
        done
        let i++
    done
    echo "`date` 每五小时进行一次数据更新 ..."
    ddd 18000
    ddd 18000}
done
