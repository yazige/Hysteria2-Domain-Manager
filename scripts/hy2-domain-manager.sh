#!/bin/bash

# ================= 颜色和前缀定义 =================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
PREFIX="**"

# ================= 基础环境检查 =================
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 请使用 root 用户运行，或使用 sudo bash 执行本脚本。${NC}"
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo -e "${RED}❌ 当前系统不支持 apt-get。本脚本仅支持 Debian / Ubuntu 系统。${NC}"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
    echo -e "${RED}❌ 当前系统不支持 systemctl。本脚本需要 systemd 环境。${NC}"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ 未检测到 curl，正在安装...${NC}"
    apt-get update -y -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl >/dev/null 2>&1
fi

# ================= 交互式域名检测与环境搭建 =================
function prepare_env_with_domain() {
    echo -e "\n${YELLOW}🚨 域名配置：请确保你已将二级域名解析到本机IP！${NC}"
    read -p "👉 请输入完整域名 (例如 jp.abc.xyz): " DOMAIN
    if [ -z "$DOMAIN" ]; then echo -e "${RED}❌ 域名为空，中止。${NC}"; sleep 2; return 1; fi

    echo -e "${CYAN}正在检查域名解析...${NC}"
    PUBLIC_IP=$(curl -4 -s --connect-timeout 5 icanhazip.com)
    RESOLVED_IP=$(ping -c 1 -W 2 $DOMAIN 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

    if [ "$RESOLVED_IP" == "$PUBLIC_IP" ]; then
        echo -e "${GREEN}✅ 解析正常 ($PUBLIC_IP)。${NC}"
    else
        echo -e "${RED}⚠️ 警告: 域名解析IP ($RESOLVED_IP) 与本机 ($PUBLIC_IP) 不符！${NC}"
        read -p "是否强制继续申请证书? (y/n): " force_cont
        if [[ "$force_cont" != "y" && "$force_cont" != "Y" ]]; then return 1; fi
    fi

    echo -e "${YELLOW}${PREFIX} 正在清理环境、配置Swap与底层优化...${NC}"
    systemctl stop hysteria-server 2>/dev/null || true
    apt-get update -y -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget socat openssl iptables ufw > /dev/null 2>&1

    # Swap 兜底
    SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
    if [ -z "$SWAP_TOTAL" ] || [ "$SWAP_TOTAL" -lt 1900 ]; then
        swapoff -a 2>/dev/null; rm -f /swapfile
        fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
        chmod 600 /swapfile; mkswap /swapfile > /dev/null 2>&1; swapon /swapfile 2>/dev/null
        grep -q "/swapfile" /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # BBR+并发优化
    cat << SYSCTL_EOF > /etc/sysctl.d/99-hysteria.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
fs.file-max = 1048576
SYSCTL_EOF
    sysctl --system > /dev/null 2>&1
    sed -i 's/.*DefaultLimitNOFILE.*/DefaultLimitNOFILE=1048576/g' /etc/systemd/system.conf 2>/dev/null

    echo -e "${YELLOW}${PREFIX} 放行防火墙 (80用于证书申请)...${NC}"
    ufw allow 80/tcp 2>/dev/null || true
    ufw allow 443/tcp 2>/dev/null || true
    ufw allow 443/udp 2>/dev/null || true
    ufw allow ${PORT_RANGE}/udp 2>/dev/null || true

    echo -e "${YELLOW}${PREFIX} 启动 ACME 自动签发证书...${NC}"
    mkdir -p /etc/hysteria
    curl -s https://get.acme.sh | sh > /dev/null 2>&1
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1
    systemctl stop nginx 2>/dev/null || true

    ~/.acme.sh/acme.sh --issue -d "${DOMAIN}" --standalone -k ec-256 --force
    if [ $? -ne 0 ]; then echo -e "${RED}❌ 证书申请失败！${NC}"; sleep 3; return 1; fi
    ~/.acme.sh/acme.sh --installcert -d "${DOMAIN}" --fullchain-file /etc/hysteria/server.crt --key-file /etc/hysteria/server.key --ecc --force > /dev/null 2>&1
    echo -e "${GREEN}✅ 证书安装成功！${NC}"

    if [ ! -f "/usr/local/bin/hysteria" ]; then
ARCH=$(uname -m)

case "$ARCH" in
    x86_64|amd64)
        HY2_ARCH="amd64"
        ;;
    aarch64|arm64)
        HY2_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}❌ 不支持的系统架构: ${ARCH}${NC}"
        return 1
        ;;
esac

if [ ! -f "/usr/local/bin/hysteria" ]; then
    wget -q -O /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${HY2_ARCH}"
    chmod +x /usr/local/bin/hysteria
fi
    fi
    return 0
}

function configure_systemd() {
    cat << EOF_SERVICE > /etc/systemd/system/hysteria-server.service
[Unit]
Description=Hysteria 2 Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
WorkingDirectory=/etc/hysteria
User=root
Group=root
Restart=always
RestartSec=3
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF_SERVICE
    systemctl daemon-reload
    systemctl enable hysteria-server.service > /dev/null 2>&1
    systemctl restart hysteria-server.service
    sleep 2
}

# ================= A. 单用户安装 (真域名) =================
function install_single() {
    clear; echo -e "${CYAN}单用户部署 (真域名模式)...${NC}"
    prepare_env_with_domain || return
    PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    
    cat << EOF2 > /etc/hysteria/config.yaml
listen: :443,${PORT_RANGE}
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
obfs:
  type: salamander
  salamander:
    password: ${PASSWORD}
auth:
  type: password
  password: ${PASSWORD}
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com
    rewriteHost: true
bandwidth:
  up: ${SERVER_BW}
  down: ${SERVER_BW}
EOF2
    configure_systemd
    clear; echo -e "${GREEN}🎉 部署完成！以下为节点直连与配置块：${NC}\n"
    echo -e "${YELLOW}【手机端直连链接 (无不安全提示)】${NC}"
    echo -e "${GREEN}hysteria2://${PASSWORD}@${DOMAIN}:443/?mport=${PORT_RANGE}&sni=${DOMAIN}&obfs=salamander&obfsParam=${PASSWORD}#Team-HY2-Node${NC}\n"
    
    echo -e "${YELLOW}【电脑端 Clash 代理块】${NC}"
    cat << EOF3
proxies:
  - name: "Team-HY2-Node"
    type: hysteria2
    server: ${DOMAIN}
    port: 443
    ports: ${PORT_RANGE}
    password: ${PASSWORD}
    sni: ${DOMAIN}
    skip-cert-verify: false
    obfs: salamander
    obfs-password: ${PASSWORD}
    up: ${CLIENT_UP}
    down: ${CLIENT_DOWN}
EOF3
    echo ""; read -n 1 -s -r -p "按任意键返回..."
}

# ================= B. 多用户独立账号安装 (真域名) =================
function install_multi() {
    clear; echo -e "${CYAN}多用户部署 (真域名防封锁模式)...${NC}"
    read -p "👉 请输入要创建的用户数量 (默认15): " USER_COUNT
    USER_COUNT=${USER_COUNT:-15}
    prepare_env_with_domain || return

    OBFS_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    echo "DOMAIN=${DOMAIN}" > /etc/hysteria/.env_multi
    echo "OBFS_PASSWORD=${OBFS_PASSWORD}" >> /etc/hysteria/.env_multi

    cat << EOF2_HEAD > /etc/hysteria/config.yaml
listen: :443,${PORT_RANGE}
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
obfs:
  type: salamander
  salamander:
    password: ${OBFS_PASSWORD}
auth:
  type: userpass
  userpass:
EOF2_HEAD

    declare -a M_NAMES; declare -a M_PASSES
    for i in $(seq 1 $USER_COUNT); do
        UNAME="user${i}"; UPASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)
        M_NAMES[$i]=$UNAME; M_PASSES[$i]=$UPASS
        echo "    ${UNAME}: ${UPASS}" >> /etc/hysteria/config.yaml
    done

    cat << EOF2_TAIL >> /etc/hysteria/config.yaml
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com
    rewriteHost: true
bandwidth:
  up: ${SERVER_BW}
  down: ${SERVER_BW}
EOF2_TAIL
    configure_systemd

    clear; echo -e "${GREEN}🎉 多用户防封锁版本大功告成！${NC}\n"
    for i in $(seq 1 $USER_COUNT); do
        name="${M_NAMES[$i]}"; pass="${M_PASSES[$i]}"
        echo -e "👤 用户 ${CYAN}[${name}]${NC} :"
        echo -e "${GREEN}hysteria2://${name}:${pass}@${DOMAIN}:443/?mport=${PORT_RANGE}&sni=${DOMAIN}&obfs=salamander&obfsParam=${OBFS_PASSWORD}#HY2-${name}${NC}"
        echo -e " 👇 Clash 组装配置块 👇"
        cat << EOF_YAML_SINGLE
  - name: "HY2-${name}"
    type: hysteria2
    server: ${DOMAIN}
    port: 443
    ports: ${PORT_RANGE}
    password: "${name}:${pass}"
    sni: ${DOMAIN}
    skip-cert-verify: false
    obfs: salamander
    obfs-password: ${OBFS_PASSWORD}
    up: ${CLIENT_UP}
    down: ${CLIENT_DOWN}
EOF_YAML_SINGLE
        echo -e "\n"
    done
    echo ""; read -n 1 -s -r -p "按任意键返回主菜单..."
}

# ================= C & D. 改密与调优 =================
function update_multi_user() {
    clear; echo -e "${CYAN}修改多用户密码...${NC}"
    if [ ! -f "/etc/hysteria/config.yaml" ] || ! grep -q "type: userpass" /etc/hysteria/config.yaml; then
        echo -e "${RED}❌ 当前不是多用户模式！${NC}"; read -n 1 -s -r -p "按任意键返回..."; return
    fi
    source /etc/hysteria/.env_multi 2>/dev/null
    declare -a u_names; declare -a u_passes; count=0
    users_raw=$(awk '/^[[:space:]]*userpass:/{flag=1; next} /^[a-zA-Z]/{flag=0} flag {print}' /etc/hysteria/config.yaml | grep ":")
    while IFS=":" read -r name pass; do
        name=$(echo "$name" | tr -d ' '); pass=$(echo "$pass" | tr -d ' ')
        count=$((count+1)); u_names[$count]=$name; u_passes[$count]=$pass
        echo -e " [${CYAN}${count}${NC}] 用户: ${GREEN}${name}${NC} | 密码: ${YELLOW}${pass}${NC}"
    done <<< "$users_raw"

    echo ""; read -p "👉 请输入修改编号 (1-$count, 0返回): " sel_idx
    if [[ "$sel_idx" -ge 1 && "$sel_idx" -le "$count" ]]; then
        target_user=${u_names[$sel_idx]}
        read -p "👉 输入新密码 (回车随机): " new_pass
        new_pass=${new_pass:-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)}
        sed -i "s/^[[:space:]]*${target_user}:.*/    ${target_user}: ${new_pass}/" /etc/hysteria/config.yaml
        systemctl restart hysteria-server.service
        echo -e "${GREEN}✅ 密码已更新！新链接：${NC}"
        echo -e "${GREEN}hysteria2://${target_user}:${new_pass}@${DOMAIN}:443/?mport=${PORT_RANGE}&sni=${DOMAIN}&obfs=salamander&obfsParam=${OBFS_PASSWORD}#HY2-${target_user}${NC}"
    fi
    echo ""; read -n 1 -s -r -p "按任意键返回主菜单..."
}

function optimize_old_node() {
    clear; echo -e "${CYAN}正在执行底层网络调优检测...${NC}"
    systemctl restart hysteria-server.service 2>/dev/null
    FINAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')
    if [ -n "$FINAL_SWAP" ] && [ "$FINAL_SWAP" -ge 1900 ]; then echo -e "${GREEN}[✔] 内存兜底正常${NC}"; else echo -e "${RED}[❌] 内存兜底失败${NC}"; fi
    BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "$BBR_STATUS" == "bbr" ]]; then echo -e "${GREEN}[✔] BBR激活正常${NC}"; else echo -e "${RED}[❌] BBR失败${NC}"; fi
    echo -e "${CYAN}=========================================================${NC}\n"
    read -n 1 -s -r -p "按任意键返回..."
}

# ================= 主菜单 =================
while true; do
    clear
    echo -e "${CYAN}=================================================================${NC}"
    echo -e "${CYAN}🚀 Hysteria 2 真域名交互管理面板 (多节点组装版)${NC}"
    echo -e "${CYAN}=================================================================${NC}"
    echo -e " ${GREEN}A.${NC} 部署单用户 (交互填域名)"
    echo -e " ${GREEN}B.${NC} 部署多用户 (交互填域名)"
    echo -e " ${YELLOW}C.${NC} 修改多用户密码"
    echo -e " ${YELLOW}D.${NC} 底层网络优化检测"
    echo -e " ${RED}0.${NC} 退出脚本"
    echo -e "${CYAN}=================================================================${NC}"
    read -p "👉 请输入选项 [A/B/C/D/0]: " menu_choice
    case $menu_choice in
        A|a) install_single ;;
        B|b) install_multi ;;
        C|c) update_multi_user ;;
        D|d) optimize_old_node ;;
        0) exit 0 ;;
        *) sleep 1 ;;
    esac
done
