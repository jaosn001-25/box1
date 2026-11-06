#!/bin/bash

export LANG=en_US.UTF-8
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
red() { echo -e "\e[1;91m$1\033[0m"; }

work_dir="${HOME:-/root}/xray"
mkdir -p "${work_dir}"

# 打印接收到的环境变量状态
echo "================ 环境变量检查 ================"
echo "UUID          : ${UUID:-${uuid:-<未设置，将自动随机生成>}}"
echo "ARGO_DOMAIN   : ${ARGO_DOMAIN:-${AGN:-${agn:-${argo_domain:-<未设置>}}}}"
echo "ARGO_PORT     : ${ARGO_PORT:-${VMPT:-${vmpt:-${argo_port:-8001}}}}"
echo "ARGO_PROTOCOL : ${ARGO_PROTOCOL:-${argo_protocol:-quic}}"
echo "CFIP (优选)   : ${CFIP:-${cfip:-<默认域名>}}"
echo "REALITY_PORT  : ${REALITY_PORT:-${VLPT:-${vlpt:-${reality_port:-<未启用>}}}}"
echo "H3_PORT       : ${H3_PORT:-${h3_port:-<未启用>}}"
echo "=============================================="

# Github Cloudflare安全代理
GITHUB_PROXY=('https://ess.ieshare.workers.dev/')

download_file() {
    local output_path="$1"
    local official_url="$2"
    
    echo "连接Github官方源中: $official_url"
    if curl -sL --connect-timeout 5 --max-time 60 -o "$output_path" "$official_url"; then
        if [ -s "$output_path" ]; then
            green "下载成功！"
            return 0
        fi
    fi
    
    yellow "Github直连失败，转向Cloudflare安全代理..."
    for proxy in "${GITHUB_PROXY[@]}"; do
        local proxy_url="${proxy}${official_url}"
        if curl -sL --connect-timeout 5 --max-time 60 -o "$output_path" "$proxy_url"; then
            if [ -s "$output_path" ]; then
                green "代理下载成功！"
                return 0
            fi
        fi
    done
    
    red "错误：官方源及镜像代理下载均告失败！"
    return 1
}

# 1. 解析参数与环境变量（支持环境变量与命令行参数混合使用）
uuid="${UUID:-${uuid}}"
argo_token="${ARGO_TOKEN:-${AGK:-${agk:-${argo_token}}}}"
argo_domain="${ARGO_DOMAIN:-${AGN:-${agn:-${argo_domain}}}}"
argo_port="${ARGO_PORT:-${VMPT:-${vmpt:-${argo_port:-8001}}}}"
argo_protocol="${ARGO_PROTOCOL:-${argo_protocol:-quic}}"
cfip="${CFIP:-${cfip}}"
cfip_h2="${CFIP_H2:-${cfip:-www.visa.com.hk}}"
cfip_h3="${CFIP_H3:-www.teamviewer.com}"
cfport="${CFPORT:-${cfport:-443}}"
h3_port="${H3_PORT:-${h3_port}}"
reality_port="${REALITY_PORT:-${VLPT:-${vlpt:-${reality_port}}}}"
ym_vl_re="${REYM:-${reym:-www.apple.com}}"

# 支持命令行参数覆盖
for arg in "$@"; do
    clean_arg="${arg//\"/}"
    clean_arg="${clean_arg//\'/}"
    
    if [[ "$clean_arg" =~ ^[hH]3(.*)$ ]]; then
        h3_port="${BASH_REMATCH[1]}"
    elif [[ "$clean_arg" =~ ^[rR][eE][aA][lL][iI][tT][yY](.*)$ ]]; then
        reality_port="${BASH_REMATCH[1]}"
    elif [[ "$clean_arg" =~ ^argo[pP][rR][oO][tT][oO][cC][oO][lL](.*)$ ]] || [[ "$clean_arg" =~ ^[pP][rR][oO][tT][oO][cC][oO][lL](.*)$ ]]; then
        argo_protocol="${BASH_REMATCH[1]}"
    elif [[ "$clean_arg" =~ ^argo[pP][oO][rR][tT](.*)$ ]] || [[ "$clean_arg" =~ ^[pP][oO][rR][tT](.*)$ ]]; then
        argo_port="${BASH_REMATCH[1]}"
    elif [[ "$clean_arg" =~ ^argo[dD][oO][mM][aA][iI][nN](.*)$ ]] || [[ "$clean_arg" =~ ^[dD][oO][mM][aA][iI][nN](.*)$ ]]; then
        argo_domain="${BASH_REMATCH[1]}"
    elif [[ "$clean_arg" =~ ^argo[tT][oO][kK][eE][nN](.*)$ ]] || [[ "$clean_arg" =~ ^[tT][oO][kK][eE][nN](.*)$ ]]; then
        argo_token="${BASH_REMATCH[1]}"
    fi
done

enable_argo=false
if [ -n "$argo_domain" ] && [ -n "$argo_token" ]; then
    enable_argo=true
fi

if [ -z "$h3_port" ] && [ -z "$reality_port" ] && [ "$enable_argo" = false ]; then
    yellow "提示：未检测到任何有效配置（H3、REALITY及Argo隧道均未启用）。"
    echo "请配置 ARGO_DOMAIN 和 ARGO_TOKEN 环境变量，或通过命令行参数传入！"
    exit 0
fi

# 2. 清理旧进程
pkill -f "${work_dir}/xray" 2>/dev/null || true
pkill -f "${work_dir}/cloudflared" 2>/dev/null || true
sleep 1

# 3. 下载 Xray-core
if [ ! -f "${work_dir}/xray" ]; then
    green "正在下载 Xray-core..."
    ARCH_RAW=$(uname -m)
    case "${ARCH_RAW}" in
        'x86_64' | 'amd64') ARCH='64' ;;
        'aarch64' | 'arm64') ARCH='arm64-v8a' ;;
        *) ARCH='64' ;;
    esac

    download_file "${work_dir}/xray.zip" "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip" || exit 1
    unzip -qo "${work_dir}/xray.zip" -d "${work_dir}/" && rm -f "${work_dir}/xray.zip"
    chmod +x "${work_dir}/xray"
fi

# 4. 下载 cloudflared
if [ "$enable_argo" = true ] && [ ! -f "${work_dir}/cloudflared" ]; then
    green "正在下载 Cloudflared..."
    ARCH_CF=$(uname -m)
    case "${ARCH_CF}" in
        'x86_64' | 'amd64') CF_ARCH='amd64' ;;
        'aarch64' | 'arm64') CF_ARCH='arm64' ;;
        *) CF_ARCH='amd64' ;;
    esac
    download_file "${work_dir}/cloudflared" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" || exit 1
    chmod +x "${work_dir}/cloudflared"
fi

# 5. 生成 UUID 与密钥对
if [ -z "$uuid" ]; then
    if [ -s "${work_dir}/uuid" ]; then
        uuid=$(cat "${work_dir}/uuid")
    else
        uuid=$("${work_dir}/xray" uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-"$5"-"$6"-"$7$8$9}')
    fi
fi
echo "$uuid" > "${work_dir}/uuid"
green "UUID 密码: $uuid"

h3_path="${uuid}-xu" 
argo_path="${uuid}-argo"

# H3 自签证书
if [ -n "$h3_port" ] && [ ! -f "${work_dir}/cert.pem" ]; then
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -new -x509 -days 3650 -key "${work_dir}/private.key" -out "${work_dir}/cert.pem" -subj "/CN=bing.com"
fi

# Reality 密钥对
if [ -n "$reality_port" ]; then
    key_pair=$("${work_dir}/xray" x25519)
    private_key_x=$(echo "$key_pair" | awk -F':' '/PrivateKey/ {print $2}' | xargs)
    public_key_x=$(echo "$key_pair" | awk -F':' '/Password/ {print $2}' | xargs)
    short_id_x=$(date +%s%N | sha256sum | cut -c 1-8)
fi

# 6. 构建 Xray inbounds 配置
inbounds_arr=()

if [ -n "$reality_port" ]; then
    inbounds_arr+=( "{
      \"tag\": \"tcp-reality\",
      \"listen\": \"::\",
      \"port\": $reality_port,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [{\"id\": \"$uuid\", \"flow\": \"xtls-rprx-vision\"}],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"reality\",
        \"realitySettings\": {
          \"fingerprint\": \"chrome\",
          \"target\": \"$ym_vl_re:443\",
          \"serverNames\": [\"$ym_vl_re\"],
          \"privateKey\": \"$private_key_x\",
          \"shortIds\": [\"$short_id_x\"]
        }
      },
      \"sniffing\": {\"enabled\": true, \"destOverride\": [\"http\", \"tls\", \"quic\"], \"metadataOnly\": false}
    }" )
fi

if [ -n "$h3_port" ]; then
    inbounds_arr+=( "{
      \"tag\": \"xhttp-h3\",
      \"listen\": \"::\",
      \"port\": $h3_port,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [{\"id\": \"$uuid\", \"flow\": \"\"}],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"xhttp\",
        \"security\": \"tls\",
        \"xhttpSettings\": {
          \"mode\": \"auto\",
          \"path\": \"/$h3_path\"
        },
        \"tlsSettings\": {
          \"alpn\": [\"h3\"],
          \"certificates\": [{\"certificateFile\": \"$work_dir/cert.pem\", \"keyFile\": \"$work_dir/private.key\"}]
        }
      },
      \"sniffing\": {\"enabled\": true, \"destOverride\": [\"http\", \"tls\", \"quic\"], \"metadataOnly\": false}
    }" )
fi

if [ "$enable_argo" = true ]; then
    inbounds_arr+=( "{
      \"tag\": \"xhttp-argo\",
      \"listen\": \"127.0.0.1\",
      \"port\": $argo_port,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [{\"id\": \"$uuid\"}],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"xhttp\",
        \"security\": \"none\",
        \"xhttpSettings\": {
          \"path\": \"/$argo_path\",
          \"mode\": \"auto\"
        }
      },
      \"sniffing\": {\"enabled\": true, \"destOverride\": [\"http\", \"tls\", \"quic\"], \"metadataOnly\": false}
    }" )
fi

inbounds_json=$(IFS=,; echo "${inbounds_arr[*]}")

cat > "${work_dir}/config.json" << EOF
{
  "log": {
    "loglevel": "warning",
    "error": "${work_dir}/xray.log"
  },
  "inbounds": [
    $inbounds_json
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
EOF

# 7. 启动 Xray-core
green "正在启动 Xray-core..."
nohup "${work_dir}/xray" run -config "${work_dir}/config.json" > "${work_dir}/xray.log" 2>&1 &
sleep 2

if pgrep -f "${work_dir}/xray" >/dev/null 2>&1; then
    green "Xray-core 启动成功！"
else
    red "Xray-core 启动失败，最近错误日志："
    cat "${work_dir}/xray.log" 2>/dev/null
fi

# 8. 启动 Cloudflare Argo 固定隧道
if [ "$enable_argo" = true ]; then
    argo_connections="1"
    argo_proto_lower=$(echo "$argo_protocol" | tr '[:upper:]' '[:lower:]')
    if [ "$argo_proto_lower" = "http2" ]; then
        argo_connections="4"
    fi
    green "正在启动 Cloudflare Argo 固定隧道 (协议: ${argo_protocol}, 连接数: ${argo_connections})..."
    nohup "${work_dir}/cloudflared" tunnel --no-autoupdate --retries 5 --grace-period 1s --protocol "${argo_protocol}" --ha-connections "${argo_connections}" run --token "${argo_token}" > "${work_dir}/cloudflared.log" 2>&1 &
    sleep 3
    if pgrep -f "${work_dir}/cloudflared" >/dev/null 2>&1; then
        green "Cloudflared Argo 进程运行中！"
    else
        yellow "Cloudflared 隧道启动状态异常，日志："
        tail -n 10 "${work_dir}/cloudflared.log" 2>/dev/null
    fi
fi

# 9. 生成节点链接与订阅文件
raw_ip=$(curl -4 -sm 2 ip.sb 2>/dev/null || curl -6 -sm 2 ip.sb 2>/dev/null || echo "127.0.0.1")
if [[ "$raw_ip" =~ : ]]; then
    server_ip="[$raw_ip]"
else
    server_ip="$raw_ip"
fi

declare -A sc=([A]=ᴀ [B]=ʙ [C]=ᴄ [D]=ᴅ [E]=ᴇ [F]=ꜰ [G]=ɢ [H]=ʜ [I]=ɪ [J]=ᴊ [K]=ᴋ [L]=ʟ [M]=ᴍ [N]=ɴ [O]=ᴏ [P]=ᴘ [Q]=ꞯ [R]=ʀ [S]=ꜱ [T]=ᴛ [U]=ᴜ [V]=ᴠ [W]=ᴡ [X]=x [Y]=ʏ [Z]=ᴢ)
uc=$(curl -sm 3 "https://ipinfo.io/country" 2>/dev/null | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
if [ -z "$uc" ] || [ ${#uc} -ne 2 ]; then
    uc=$(curl -sm 3 "https://api.ip.sb/geoip" 2>/dev/null | grep -o '"country_code":"[^"]*"' | cut -d'"' -f4 | tr '[:lower:]' '[:upper:]')
fi
isp="${sc[${uc:0:1}]}${sc[${uc:1:1}]}"
[[ -z "$isp" ]] && isp="ɴᴅ"

ESS="ᴇꜱꜱ"
> "${work_dir}/url.txt"

[ -n "$reality_port" ] && echo "vless://${uuid}@${server_ip}:${reality_port}?encryption=none&security=reality&sni=${ym_vl_re}&fp=chrome&pbk=${public_key_x}&sid=${short_id_x}&type=tcp&flow=xtls-rprx-vision#${isp}%20Reality Vision%20${ESS}" >> "${work_dir}/url.txt"
[ -n "$h3_port" ] && echo "vless://${uuid}@${server_ip}:${h3_port}?encryption=none&security=tls&sni=bing.com&alpn=h3&fp=chrome&type=xhttp&mode=auto&path=/${h3_path}&allowInsecure=1#${isp}%20H3-XHTTP%20${ESS}" >> "${work_dir}/url.txt"
if [ "$enable_argo" = true ]; then
    echo "vless://${uuid}@${cfip_h2}:${cfport}?encryption=none&security=tls&alpn=h2&sni=${argo_domain}&fp=chrome&type=xhttp&mode=auto&host=${argo_domain}&path=/${argo_path}#${isp}%20H2-Argo XHTTP%20${ESS}" >> "${work_dir}/url.txt"
    echo "vless://${uuid}@${cfip_h3}:${cfport}?encryption=none&security=tls&alpn=h3&sni=${argo_domain}&fp=chrome&type=xhttp&mode=auto&host=${argo_domain}&path=/${argo_path}#${isp}%20H3-Argo XHTTP%20${ESS}" >> "${work_dir}/url.txt"
fi

base64_str=$(cat "${work_dir}/url.txt" | base64 | tr -d '\n' | tr -d '\r')
echo "$base64_str" > "${work_dir}/base64.txt"

green "=========================================================================================="
green " Base64 订阅链接生成成功 (VLESS-XHTTP + Reality) "
green "=========================================================================================="
cat "${work_dir}/url.txt"
green "=========================================================================================="
green "Base64 内容："
green "$base64_str"
green "=========================================================================================="