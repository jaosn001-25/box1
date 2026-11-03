#!/bin/sh
echo "========== 环境变量检查 =========="                                                                             
echo "大写 UUID: ${UUID:-<未设置>} | 小写 uuid: ${uuid:-<未设置>}"                                                    
echo "大写 VMPT: ${VMPT:-<未设置>} | 小写 vmpt: ${vmpt:-<未设置>}"                                                    
echo "大写 ARGO: ${ARGO:-<未设置>} | 小写 argo: ${argo:-<未设置>}"                                                    
echo "大写 AGN : ${AGN:-<未设置>}  | 小写 agn : ${agn:-<未设置>}"                                                     
echo "大写 CFIP: ${CFIP:-<未设置>} | 小写 cfip: ${cfip:-<未设置>}"                                                    
echo "=================================="       
export LANG=en_US.UTF-8
export uuid=${UUID:-${uuid}}
export vmpt=${VMPT:-${vmpt}}
export vwpt=${VMPT:-${VWPT:-${vwpt}}}
export argo=${ARGO:-${argo}}
export agn=${AGN:-${agn}}
export agk=${AGK:-${agk}}
export cfip=${CFIP:-${cfip}}
export ippz=${IPPZ:-${ippz}}
export name=${NAME:-${name}}
v46url="https://icanhazip.com"

showmode(){
echo "Argosbx脚本项目地址：https://github.com/yonggekkk/argosbx"
echo "---------------------------------------------------------"
echo
}

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "甬哥Github项目 ：github.com/yonggekkk"
echo "甬哥Blogger博客 ：ygkkk.blogspot.com"
echo "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
echo "Argosbx一键无交互小钢炮脚本💣 (精简版：vmess-ws + argo)"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

hostname=$(uname -a | awk '{print $2}')
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) echo "目前脚本不支持$(uname -m)架构" && exit
esac
mkdir -p "$HOME/agsbx"

v4v6(){
v4=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 --tries=2 -qO- "$v46url" 2>/dev/null) )
v6=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 --tries=2 -qO- "$v46url" 2>/dev/null) )
v4dq=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k https://ip.fm | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/' 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 --tries=2 -qO- https://ip.fm | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/' 2>/dev/null) )
v6dq=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k https://ip.fm | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/' 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 --tries=2 -qO- https://ip.fm | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/' 2>/dev/null) )
}

insuuid(){
if [ -z "$uuid" ] && [ ! -e "$HOME/agsbx/uuid" ]; then
uuid=$("$HOME/agsbx/xray" uuid)
echo "$uuid" > "$HOME/agsbx/uuid"
elif [ -n "$uuid" ]; then
echo "$uuid" > "$HOME/agsbx/uuid"
fi
uuid=$(cat "$HOME/agsbx/uuid")
echo "UUID密码：$uuid"
}

installxray(){
echo
echo "=========启用xray内核========="
if [ ! -e "$HOME/agsbx/xray" ]; then
url="https://github.com/yonggekkk/argosbx/releases/download/argosbx/xray-$cpu"; out="$HOME/agsbx/xray"; (command -v curl >/dev/null 2>&1 && curl -Lo "$out" -# --retry 2 "$url") || (command -v wget>/dev/null 2>&1 && timeout 3 wget -O "$out" --tries=2 "$url")
chmod +x "$HOME/agsbx/xray"
sbcore=$("$HOME/agsbx/xray" version 2>/dev/null | awk '/^Xray/{print $2}')
echo "已安装Xray正式版内核：$sbcore"
fi
cat > "$HOME/agsbx/xr.json" <<EOF
{
  "log": {
  "loglevel": "none"
  },
  "dns": {
    "servers": [
      "${xsdns}"
      ]
   },
  "inbounds": [
EOF
insuuid
}

addvlessws(){
if [ -n "$vwpt" ]; then
echo "$vwpt" > "$HOME/agsbx/vwpt"
vwpt=$(cat "$HOME/agsbx/vwpt")
echo "Vless-ws端口：$vwpt"
cat >> "$HOME/agsbx/xr.json" <<EOF
        {
            "tag": "vless-ws",
            "listen": "::",
            "port": ${vwpt},
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                  "path": "${uuid}-vw"
            }
        },
            "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"],
            "metadataOnly": false
            }
         }
EOF
fi
}

finalizexray(){
sed -i '${s/,\s*$//}' "$HOME/agsbx/xr.json"
cat >> "$HOME/agsbx/xr.json" <<EOF
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
      "domainStrategy":"${xryx}"
     }
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "ip": [ "::/0", "0.0.0.0/0" ],
        "network": "tcp,udp",
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
nohup "$HOME/agsbx/xray" run -c "$HOME/agsbx/xr.json" >/dev/null 2>&1 &
}

installargo(){
if [ -n "$argo" ]; then
echo
echo "=========启用Cloudflared-argo内核========="
if [ ! -e "$HOME/agsbx/cloudflared" ]; then
argocore=$({ command -v curl >/dev/null 2>&1 && curl -Ls https://data.jsdelivr.com/v1/package/gh/cloudflare/cloudflared || wget -qO- https://data.jsdelivr.com/v1/package/gh/cloudflare/cloudflared; } | grep -Eo '"[0-9.]+"' | sed -n 1p | tr -d '",')
echo "下载Cloudflared-argo最新正式版内核：$argocore"
url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"; out="$HOME/agsbx/cloudflared"; (command -v curl>/dev/null 2>&1 && curl -Lo "$out" -# --retry 2 "$url") || (command -v wget>/dev/null 2>&1 && timeout 3 wget -O "$out" --tries=2 "$url")
chmod +x "$HOME/agsbx/cloudflared"
fi
argoport=$(cat "$HOME/agsbx/vwpt" 2>/dev/null)
echo "Vless" > "$HOME/agsbx/vlvm"
echo "$argoport" > "$HOME/agsbx/argoport.log"
if [ -n "${agn}" ] && [ -n "${agk}" ]; then
argoname='固定'
nohup "$HOME/agsbx/cloudflared" tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${agk}" >/dev/null 2>&1 &
echo "${agn}" > "$HOME/agsbx/sbargoym.log"
echo "${agk}" > "$HOME/agsbx/sbargotoken.log"
else
argoname='临时'
nohup "$HOME/agsbx/cloudflared" tunnel --url http://localhost:$(cat $HOME/agsbx/argoport.log) --edge-ip-version auto --no-autoupdate --protocol http2 > "$HOME/agsbx/argo.log" 2>&1 &
fi
echo "申请Argo${argoname}隧道中……请稍等"
sleep 8
if [ -n "${agn}" ] && [ -n "${agk}" ]; then
argodomain=$(cat "$HOME/agsbx/sbargoym.log" 2>/dev/null)
else
argodomain=$(grep -a trycloudflare.com "$HOME/agsbx/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
fi
if [ -n "${argodomain}" ]; then
echo "Argo${argoname}隧道申请成功"
else
echo "Argo${argoname}隧道申请失败，请稍后再试"
fi
sleep 5
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'agsbx/(s|x)' || pgrep -f 'agsbx/(s|x)' >/dev/null 2>&1 ; then
echo "Argosbx脚本进程启动成功，安装完毕" && sleep 2
else
echo "Argosbx脚本进程未启动，安装失败" && exit
fi
fi
}

ins(){
if [ -n "$name" ]; then
sxname=$name-
echo "$sxname" > "$HOME/agsbx/name"
echo
echo "所有节点名称前缀：$name"
fi
v4v6
installxray
addvlessws
finalizexray
installargo
}

argosbxstatus(){
echo "=========当前内核运行状态========="
procs=$(find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null)
if echo "$procs" | grep -Eq 'agsbx/x' || pgrep -f 'agsbx/x' >/dev/null 2>&1; then
echo "Xray：运行中"
else
echo "Xray：未启用"
fi
if echo "$procs" | grep -Eq 'agsbx/c' || pgrep -f 'agsbx/c' >/dev/null 2>&1; then
echo "Argo：运行中"
else
echo "Argo：未启用"
fi
}

cip(){
ipbest(){
serip=$( (command -v curl >/dev/null 2>&1 && (curl -s4m5 -k "$v46url" 2>/dev/null || curl -s6m5 -k "$v46url" 2>/dev/null) ) || (command -v wget >/dev/null 2>&1 && (timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null || timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) ) )
if echo "$serip" | grep -q ':'; then
server_ip="[$serip]"
else
server_ip="$serip"
fi
echo "$server_ip" > "$HOME/agsbx/server_ip.log"
}
ipchange(){
v4v6
if [ -z "$v4" ]; then
vps_ipv4='无IPV4'
vps_ipv6="$v6"
location="$v6dq"
elif [ -n "$v4" ] && [ -n "$v6" ]; then
vps_ipv4="$v4"
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"
vps_ipv6='无IPV6'
location="$v4dq"
fi
echo
argosbxstatus
echo
echo "=========当前服务器本地IP情况========="
echo "本地IPV4地址：$vps_ipv4"
echo "本地IPV6地址：$vps_ipv6"
echo "服务器地区：$location"
echo
sleep 2
if [ "$ippz" = "4" ]; then
if [ -z "$v4" ]; then ipbest; else server_ip="$v4"; echo "$server_ip" > "$HOME/agsbx/server_ip.log"; fi
elif [ "$ippz" = "6" ]; then
if [ -z "$v6" ]; then ipbest; else server_ip="[$v6]"; echo "$server_ip" > "$HOME/agsbx/server_ip.log"; fi
else
ipbest
fi
}
ipchange
rm -rf "$HOME/agsbx/jh.txt"
uuid=$(cat "$HOME/agsbx/uuid")
server_ip=$(cat "$HOME/agsbx/server_ip.log")
sxname=$(cat "$HOME/agsbx/name" 2>/dev/null)
echo "*********************************************************"
echo "Argosbx脚本输出节点配置如下："
echo
# vless-ws 直连节点
if grep vless-ws "$HOME/agsbx/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-ws 】节点信息如下："
vwpt=$(cat "$HOME/agsbx/vwpt")
vw_link="vless://$uuid@$server_ip:$vwpt?encryption=none&flow=xtls-rprx-vision&type=ws&path=/$uuid-vw#${sxname}vl-ws-$hostname"
echo "$vw_link" >> "$HOME/agsbx/jh.txt"
echo "$vw_link"
echo
fi

# argo 节点
argodomain=$(cat "$HOME/agsbx/sbargoym.log" 2>/dev/null)
[ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$HOME/agsbx/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
if [ -n "$argodomain" ]; then
echo "💣【 Vless-ws-tls-argo 】节点信息如下："
echo "注：已应用您自定义的域名 ${cfip} 作为优选地址"
vwatls_link1="vless://$uuid@${cfip}:443?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome#${sxname}vless-ws-tls-argo-$hostname-443"
echo "$vwatls_link1" >> "$HOME/agsbx/jh.txt"
vwatls_link2="vless://$uuid@${cfip}:8443?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome#${sxname}vless-ws-tls-argo-$hostname-8443"
echo "$vwatls_link2" >> "$HOME/agsbx/jh.txt"
vwatls_link3="vless://$uuid@${cfip}:2053?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome#${sxname}vless-ws-tls-argo-$hostname-2053"
echo "$vwatls_link3" >> "$HOME/agsbx/jh.txt"
vwatls_link4="vless://$uuid@${cfip}:2083?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome#${sxname}vless-ws-tls-argo-$hostname-2083"
echo "$vwatls_link4" >> "$HOME/agsbx/jh.txt"
vwatls_link5="vless://$uuid@${cfip}:2087?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome#${sxname}vless-ws-tls-argo-$hostname-2087"
echo "$vwatls_link5" >> "$HOME/agsbx/jh.txt"
vwatls_link6="vless://$uuid@[2606:4700::0]:2096?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=tls&sni=$argodomain&fp=chrome#${sxname}vless-ws-tls-argo-$hostname-2096"
echo "$vwatls_link6" >> "$HOME/agsbx/jh.txt"
echo
echo "💣【 Vless-ws-argo (非TLS) 】节点信息如下："
vwa_link7="vless://$uuid@${cfip}:80?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-80"
echo "$vwa_link7" >> "$HOME/agsbx/jh.txt"
vwa_link8="vless://$uuid@${cfip}:8080?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-8080"
echo "$vwa_link8" >> "$HOME/agsbx/jh.txt"
vwa_link9="vless://$uuid@${cfip}:8880?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-8880"
echo "$vwa_link9" >> "$HOME/agsbx/jh.txt"
vwa_link10="vless://$uuid@${cfip}:2052?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-2052"
echo "$vwa_link10" >> "$HOME/agsbx/jh.txt"
vwa_link11="vless://$uuid@${cfip}:2082?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-2082"
echo "$vwa_link11" >> "$HOME/agsbx/jh.txt"
vwa_link12="vless://$uuid@${cfip}:2086?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-2086"
echo "$vwa_link12" >> "$HOME/agsbx/jh.txt"
vwa_link13="vless://$uuid@[2400:cb00:2049::0]:2095?encryption=none&flow=xtls-rprx-vision&type=ws&host=$argodomain&path=/$uuid-vw&security=none#${sxname}vless-ws-argo-$hostname-2095"
echo "$vwa_link13" >> "$HOME/agsbx/jh.txt"

sbtk=$(cat "$HOME/agsbx/sbargotoken.log" 2>/dev/null)
if [ -n "$sbtk" ]; then
nametn="Argo固定隧道token：$sbtk"
fi
argoshow=$(
echo "Argo隧道端口正在使用Vless-ws主协议端口：$(cat $HOME/agsbx/argoport.log 2>/dev/null)
Argo域名：$argodomain
$nametn

1、💣443端口的Vless-ws-tls-argo节点(优选IP与443系端口随便换)
${vwatls_link1}

2、💣80端口的Vless-ws-argo节点(优选IP与80系端口随便换)
${vwa_link7}
"
)
fi
echo "---------------------------------------------------------"
echo "$argoshow"
echo
echo "---------------------------------------------------------"
echo "聚合节点信息，请进入 $HOME/agsbx/jh.txt 文件目录查看或者运行 cat $HOME/agsbx/jh.txt 查看"
echo "========================================================="
showmode
}

# ===== 主入口 =====
if ! find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'agsbx/(s|x)' && ! pgrep -f 'agsbx/(s|x)' >/dev/null 2>&1; then
for P in /proc/[0-9]*; do if [ -L "$P/exe" ]; then TARGET=$(readlink -f "$P/exe" 2>/dev/null); if echo "$TARGET" | grep -qE '/agsbx/c|/agsbx/x'; then PID=$(basename "$P"); kill "$PID" 2>/dev/null && echo "Killed $PID ($TARGET)" || echo "Could not kill $PID ($TARGET)"; fi; fi; done
kill -15 $(pgrep -f 'agsbx/x' 2>/dev/null) $(pgrep -f 'agsbx/c' 2>/dev/null) >/dev/null 2>&1

v4orv6(){
if [ -z "$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null) )" ]; then
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
fi
if [ -n "$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) )" ]; then
xsdns="[2001:4860:4860::8888]"
xryx="ForceIPv6v4"
else
xsdns="8.8.8.8"
xryx="ForceIPv4v6"
fi
}
v4orv6
echo "CPU架构：$cpu"
echo "Argosbx脚本未安装，开始安装…………" && sleep 2
ins
cip
echo
else
echo "Argosbx脚本已安装"
echo
argosbxstatus
echo
showmode
exit
fi