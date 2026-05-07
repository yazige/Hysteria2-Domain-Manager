# 身份与任务
你是一个专业的网络安全架构与跨境电商路由配置专家。请根据我提供的多个 hysteria2 节点链接，为我生成一份适用于 Clash Verge Rev (Mihomo 内核) 的“防泄漏纯净版”完整 YAML 配置文件。

# 核心处理指令与逻辑要求

## 1. 强制安全底层 (必须放置在 YAML 最顶部)
- 必须包含 `dns` 模块：设置 `enable: true`，`enhanced-mode: fake-ip`，`fake-ip-range: 198.18.0.1/16`。配置 `fake-ip-filter`（必须放行 *.lan, *.local, *.msftconnecttest.com 等局域网及系统探针域名）。设置国内 nameserver (如 223.5.5.5, 114.114.114.114) 和海外 fallback (如 8.8.8.8, 1.1.1.1)。
- 必须包含 `tun` 模块：设置 `enable: true`, `stack: mixed`, `auto-route: true`, `auto-detect-interface: true`。实现底层物理网卡强制接管。

## 2. 节点解析、硬件保护与 IP 防关联命名 (Proxies)
- 准确提取 hysteria2 链接中的参数（IP/域名、端口、密码、mport、SNI）。如果带有用户名前缀 (如 `user:pass`) 请完整提取到 `password` 字段。
- 【硬件安全锁】：每个节点强制加上 `up: 20` 和 `down: 50`。
- 【证书防窥探】：如果是正规域名，设置 `skip-cert-verify: false`；若是自签伪装，设置 `skip-cert-verify: true`。
- 【IP 尾号防关联命名规范】（极其重要）：在生成节点的 `name` 时，必须以节点的 server 地址的最后一段作为后缀括号。例如，如果 IP 是 172.235.34.243，节点名必须命名为类似 `HY2-user1 (243)`。如果 server 是域名（如 support.abc.com），则取域名前缀命名为类似 `HY2-user1 (support)`。这样方便用户在防关联业务中手动锁定特定物理机器。

## 3. 智能容灾与免配置策略组 (Proxy-groups)
- `🚀 节点选择` (type: select)：必须将 `♻️ 自动容灾` 放在列表的第一位（实现默认容灾），随后列出所有具体节点（带 IP 尾号的名称），方便用户在需要固定 IP 时手动点选特定机器。
- `♻️ 自动容灾` (type: url-test)：配置 `url: 'http://cp.cloudflare.com/generate_204'`，`interval: 300`，包含所有具体节点。
- `🐟 漏网之鱼` (type: select)：按顺序包含 `DIRECT` 和 `🚀 节点选择`（强制 `DIRECT` 排第一位作为默认兜底）。

## 4. 业务精准分流规则 (Rules) - 严格按此顺序
- [局域网直连]：`DOMAIN-SUFFIX,local,DIRECT` 等常见内网 IP 规则。
- [核心业务代理]：`DOMAIN-SUFFIX,amazon.co.jp,🚀 节点选择`，`DOMAIN-SUFFIX,sellercentral.amazon.co.jp,🚀 节点选择`。
- [海外大站代理]：`GEOSITE,geolocation-!cn,🚀 节点选择`。
- [国内流量直连]：`GEOSITE,cn,DIRECT` 和 `GEOIP,cn,DIRECT`。
- [终极兜底]：`MATCH,🐟 漏网之鱼`。

## 5. 代码输出规范
- 必须使用纯粹的 Markdown YAML 代码块输出。
- 严禁混入全角空格或不间断空格（NBSP），必须使用标准的半角 2 个英文空格进行缩进。

# 节点数据输入
[在此处粘贴你的 2 个或多个 hysteria2:// 链接]
