# Hysteria2 Domain Manager

这是一个面向新手的一键安装与管理脚本项目。

我不是专业的 Linux / Shell 开发者。这个脚本也不是我一开始就能独立写出来的，而是我参考了网上很多一键脚本，结合自己的实际使用场景，通过 AI 辅助、多轮修改、反复测试和不断踩坑后整理出来的版本。

做这个项目的原因很简单：

很多一键脚本只告诉你“复制这条命令运行”，但很少告诉你：

- 这一步为什么要做？
- 出错了应该怎么看？
- 哪些地方可能不适合你的服务器？
- 哪些操作可能有风险？
- 如何根据自己的使用场景修改？

对于小白来说，最大的问题不是不会复制命令，而是脚本一旦报错，就不知道下一步该怎么办。

所以这个项目不仅提供一键安装脚本，也尽量把每一项优化的原因、作用和排查思路写清楚。希望你在复现工具的同时，也能知道它为什么这样设计。

我的想法是：

> 与其盲目堆砌各种看不懂的一键脚本，不如学会把自己的需求讲清楚，再利用 AI 帮助自己生成、检查、优化一个更适合自己场景的脚本。

请注意：

本项目适合学习、测试和自用。  
运行任何脚本前，请先阅读脚本内容和 README。  
不要在不了解风险的情况下，把脚本直接运行在重要服务器上。

## 为什么做这个项目？

我最开始也是一个小白。

我不会独立写复杂的 Bash 脚本，也看不懂很多网上的一键脚本。刚开始的时候，我只能照着别人给的命令复制粘贴。能运行成功还好，一旦失败，就不知道是系统问题、域名问题、端口问题、证书问题，还是脚本本身的问题。

后来我发现，很多一键脚本虽然方便，但也有几个问题：

1. 只给命令，不讲原理。
2. 只管安装，不管出错排查。
3. 不一定适合自己的系统环境。
4. 有些脚本把很多功能堆在一起，但小白不知道哪些是必要的。
5. 脚本出错后，普通用户很难判断问题在哪里。

于是我开始尝试一种新的方式：

先收集和参考已有脚本，再结合自己的真实使用场景，把需求讲给 AI，让 AI 帮我生成、解释、检查和优化。然后我自己不断测试，遇到问题就把报错继续反馈给 AI，再一点点修正。

这个项目就是这样整理出来的。

它不是一个“大神随手写的完美脚本”，而是一个“小白借助 AI 不断踩坑后整理出的可复现脚本”。

我希望它能帮助和我一样的人少走弯路：

- 不只是复制命令。
- 也能理解每一步为什么这样做。
- 出错时知道从哪里开始排查。
- 学会用 AI 辅助自己改造脚本。
- 最终做出适合自己场景的工具。

---

## 项目内容

```text
Hysteria2-Domain-Manager/
├── README.md
├── LICENSE
├── .gitattributes
├── scripts/
│   └── hy2-domain-manager.sh
└── prompts/
    └── clash-verge-rev-hy2-clean-config-prompt.md
```

---

## 一键安装命令

通过 FinalShell、Xshell、Termius 等工具连接 VPS 后，执行：

```bash
apt update -y && apt install -y wget sed ca-certificates && wget -O hy2-domain-manager.sh https://raw.githubusercontent.com/yazige/Hysteria2-Domain-Manager/main/scripts/hy2-domain-manager.sh && sed -i 's/\r$//' hy2-domain-manager.sh && chmod +x hy2-domain-manager.sh && sudo bash hy2-domain-manager.sh
```

---

## 适配系统

推荐系统：

```text
Ubuntu 24.04 LTS
Ubuntu 22.04 LTS
Debian 12
Debian 11
服务器需要拥有公网 IPv4。
不要启用防火墙
不需要加密硬盘

---

### 2. 准备域名

你需要提前准备一个二级域名，例如：

```text
jp.example.com
node1.example.com
us.example.com
```

并在 DNS 服务商处添加 A 记录，指向你的 VPS 公网 IPv4。

示例：

```text
类型：A
主机记录：jp
记录值：你的服务器公网 IPv4
```

---

## 脚本功能概览

脚本提供交互式菜单：

```text
A. 部署单用户
B. 部署多用户
C. 修改多用户密码
D. 底层网络优化检测
0. 退出脚本
```

---

## 菜单功能说明

### A. 部署单用户

适合个人使用或单设备使用。

执行后脚本会：

1. 要求输入完整域名。
2. 检测域名是否解析到当前服务器公网 IP。
3. 自动安装依赖。
4. 自动配置 Swap。
5. 自动启用 BBR 和网络参数优化。
6. 自动放行防火墙端口。
7. 使用 acme.sh 申请 Let’s Encrypt ECC 证书。
8. 下载 Hysteria2 服务端程序。
9. 生成 `/etc/hysteria/config.yaml`。
10. 创建并启动 systemd 服务。
11. 输出手机端 hysteria2 直连链接。
12. 输出 Clash / Mihomo 代理配置块。

---

### B. 部署多用户

适合团队、多账号、多设备、跨境电商业务分流等场景。

执行后脚本会：

1. 要求输入用户数量，默认 15 个。
2. 要求输入真实域名。
3. 检测域名解析是否正确。
4. 自动申请证书。
5. 生成多个独立账号。
6. 为每个账号生成独立 hysteria2 链接。
7. 为每个账号生成 Clash / Mihomo 配置块。
8. 所有用户共用一个 salamander obfs 密码。
9. 用户名和密码使用 `userpass` 方式写入 Hysteria2 配置文件。

---

### C. 修改多用户密码

仅适用于已经通过多用户模式部署的节点。

该功能会：

1. 自动读取当前多用户配置。
2. 列出所有用户。
3. 选择需要修改的用户编号。
4. 支持手动输入新密码。
5. 如果直接回车，则自动生成随机密码。
6. 自动修改 `/etc/hysteria/config.yaml`。
7. 自动重启 Hysteria2 服务。
8. 输出新的 hysteria2 连接链接。

---

### D. 底层网络优化检测

该功能用于检查当前服务器基础优化是否生效。

检测内容包括：

1. Hysteria2 服务是否能正常重启。
2. Swap 是否达到兜底要求。
3. BBR 是否已经启用。

---

## 脚本做了哪些优化

### 1. 真实域名证书模式

脚本使用 acme.sh 自动申请 Let’s Encrypt ECC 证书。

优点：

- 避免自签证书警告。
- 客户端可以使用 `skip-cert-verify: false`。
- 更适合长期稳定使用。
- 更适合 Clash Verge Rev / Mihomo 配置。

---

### 2. 域名解析预检查

脚本会自动获取当前服务器公网 IPv4，并与输入域名的解析 IP 对比。

可以预防：

- 域名没有解析到当前机器。
- DNS 记录填错。
- 证书申请失败。
- 用户把节点部署到错误服务器。
- 80 端口申请证书时无法通过验证。

---

### 3. 自动申请证书

脚本会自动使用 acme.sh 申请证书，并安装到：

```text
/etc/hysteria/server.crt
/etc/hysteria/server.key
```

Hysteria2 配置文件会直接引用这两个证书文件。

---

### 4. BBR 网络优化

脚本会写入 BBR 优化参数：

```text
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

可以改善高延迟线路下的传输表现。

---

### 5. Swap 兜底

如果服务器 Swap 小于约 2GB，脚本会自动创建 2GB Swap 文件。

可以预防：

- 小内存 VPS 安装依赖时失败。
- 服务运行中因内存不足异常退出。
- 多用户场景下系统稳定性下降。

---

### 6. 文件句柄优化

脚本会设置较高的文件句柄限制：

```text
fs.file-max = 1048576
DefaultLimitNOFILE=1048576
LimitNOFILE=1048576
```

可以提升多连接场景下的稳定性。

---

### 7. QUIC 窗口优化

脚本会在 Hysteria2 配置中加入：

```yaml
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
```

用于提升高带宽、高延迟网络下的传输表现。

---

### 8. 多端口 UDP 支持

默认使用：

```text
443,20000-20200
```

对应客户端参数：

```text
mport=20000-20200
```

可以提升连接灵活性和可用性。

---

### 9. Salamander 混淆

脚本启用 Hysteria2 的 salamander obfs：

```yaml
obfs:
  type: salamander
  salamander:
    password: 随机密码
```

可以降低裸协议特征暴露的风险。

---

### 10. 伪装站点

默认使用：

```yaml
masquerade:
  type: proxy
  proxy:
    url: https://news.ycombinator.com
    rewriteHost: true
```

---

## 能预防哪些常见问题

### 1. 证书错误

通过真实域名和 Let’s Encrypt 证书，减少客户端出现证书不可信、SNI 不匹配、TLS 握手失败等问题。

---

### 2. 域名解析错误

部署前会检查域名解析 IP 是否等于当前服务器公网 IP，减少证书申请失败和部署到错误机器的问题。

---

### 3. Windows 换行符错误

一键安装命令中包含：

```bash
sed -i 's/\r$//' hy2-domain-manager.sh
```

可以清理 Windows CRLF 换行符，预防：

```text
bad interpreter: /bin/bash^M
syntax error near unexpected token
command not found
```

仓库中也提供 `.gitattributes`，强制 `.sh` 文件使用 LF 换行。

---

### 4. 小内存 VPS 部署失败

脚本自动添加 2GB Swap，降低低配 VPS 安装依赖或运行服务时失败的概率。

---

### 5. 多用户密码混乱

多用户模式会自动生成用户和密码，并且支持后续通过菜单修改指定用户密码。

---

### 6. DNS 泄漏

配套 Prompt 强制生成 `dns` 和 `tun` 配置，使用 fake-ip 模式和 TUN 接管，降低系统 DNS 走物理网卡泄漏的风险。

---

### 7. 节点故障导致业务中断

配套 Prompt 会生成自动容灾策略组，并将自动容灾放在节点选择组第一位。

---

## 配套 Prompt

Prompt 文件路径：

```text
prompts/clash-verge-rev-hy2-clean-config-prompt.md
```

该 Prompt 用于让 AI 根据多个 hysteria2 节点链接，生成适用于 Clash Verge Rev / Mihomo 内核的完整 YAML 配置。

主要特性：

1. 强制 DNS fake-ip 防泄漏配置。
2. 强制 TUN 接管。
3. 节点强制加入 `up: 20` 和 `down: 50`。
4. 根据 IP 尾号或域名前缀生成节点名称。
5. 自动生成 url-test 容灾组。
6. 针对 Amazon Japan / Seller Central Japan 做精准代理分流。
7. 国内流量直连。
8. 最终兜底规则可控。
---

## 安全提醒

1. 不要把真实生成的节点链接、密码、证书私钥提交到 GitHub。
2. 不要公开 `/etc/hysteria/config.yaml`。
3. 不要公开 `/etc/hysteria/.env_multi`。
4. 不要公开 `/etc/hysteria/server.key`。
5. 建议给不同人员或不同业务使用独立用户。
6. 多用户模式下，如果某个账号泄露，可以通过菜单 C 单独修改密码。
7. 请遵守当地法律法规和云服务商服务条款。

---

## License

本项目使用 MIT License。

---

## 免责声明

本项目仅用于合法的网络服务部署、跨境业务路由、远程办公和安全研究场景。  
使用者需要自行承担部署、使用和网络环境合规责任。  
作者不对任何滥用行为、账号风险、网络封禁、服务器封禁或数据损失承担责任。
