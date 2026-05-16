# Clash Verge TUN 模式开启指南

这份文档给 Windows 用户使用，目标是解决这种情况：

- 浏览器能用代理，但 Codex、Git、npm、curl 等工具偶尔绕过代理。
- Codex 已经设置了 `HTTP_PROXY/HTTPS_PROXY`，但长回答还是反复 `Reconnecting`。
- 直连 OpenAI 失败，代理能连通，但连接稳定性不好。

## TUN 模式是什么

普通“系统代理”主要影响支持 HTTP/HTTPS 代理的应用。有些 Electron 应用、命令行工具或后台进程可能不会稳定读取系统代理。

TUN 模式会创建一块虚拟网卡，把系统出站流量先交给 Clash/Mihomo 规则引擎处理。它更像是在网络层接管流量，因此更适合处理“某些程序不走代理”的问题。

## 开启前检查

先确认：

1. Clash Verge 或 Clash Verge Rev 已经打开。
2. 订阅和节点可用。
3. 当前 Windows 账户有管理员权限。
4. 你能接受 Clash 临时接管更多系统流量。

建议先保存正在进行的下载、远程连接或会议。TUN 开关会改系统路由，少数网络环境会短暂断线。

## Windows 开启步骤

### 1. 以管理员身份启动 Clash Verge

如果后续安装服务失败：

1. 退出 Clash Verge。
2. 右键 Clash Verge 图标。
3. 选择“以管理员身份运行”。

### 2. 安装 Service Mode

在 Clash Verge 里：

1. 打开 `设置`。
2. 找到 `Service Mode`、`服务模式` 或类似选项。
3. 点击 `Install`、`安装` 或 `安装服务`。
4. Windows 弹出 UAC 权限确认时，点 `是`。
5. 等状态变成已安装或绿色。

Service Mode 的作用是让 Clash/Mihomo 有权限创建虚拟网卡和管理路由。

### 3. 开启 TUN Mode

在 Clash Verge 里：

1. 仍然进入 `设置`。
2. 找到 `TUN Mode` 或 `TUN 模式`。
3. 打开开关。
4. 如果提示授权，选择允许。

不同版本界面文字可能不同。常见位置是 `Settings`、`System Settings`、`Clash Core` 或代理设置附近。

### 4. 保持 System Proxy 开启还是关闭

新手建议先保持 `System Proxy` 和 `TUN Mode` 都开启，确认 Codex 稳定后再说。

如果你发现网页变慢、连接绕来绕去，后续可以只保留 TUN，关闭 System Proxy 做对比。

## 验证是否生效

### 方法 A：看虚拟网卡

按 `Win + R`，输入：

```text
ncpa.cpl
```

看是否出现类似这些名字的网卡：

- `Meta`
- `Mihomo`
- `Clash`
- `TUN`

不同版本名称不同，看到新增虚拟网卡通常就是好信号。

### 方法 B：运行诊断脚本

在本仓库里运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1
```

查看 `Possible TUN Adapters` 区域。如果能看到 `Meta`、`Mihomo`、`Clash` 或 `TUN` 相关网卡，说明系统里已经存在疑似 TUN 适配器。

### 方法 C：看 Clash 连接列表

打开 Clash Verge 的连接或日志页面，然后在 PowerShell 里运行：

```powershell
curl.exe -I https://api.openai.com/v1/models
```

如果 Clash 连接列表里出现 `api.openai.com`，说明这个命令行请求被 Clash 捕获了。

没有 API key 时，`api.openai.com/v1/models` 返回 `401 Unauthorized` 是正常的。

## 开启后仍然 Reconnecting

按顺序处理：

1. 换一个更稳定的节点。
2. 确认 Clash 连接列表能看到 `api.openai.com`、`chatgpt.com` 或相关 OpenAI 域名。
3. 完全退出 Codex，再重新打开。
4. 在 Clash 里确认 OpenAI、Cloudflare、GitHub 相关域名没有被直连规则放走。
5. 运行诊断脚本，把 `Proxy HTTPS Test` 和 `Codex TCP Connections` 两块结果拿出来看。

## 开启后网络异常

如果开 TUN 后浏览器、微信、局域网、公司 VPN 或内网服务异常：

1. 先关闭 `TUN Mode`。
2. 保留 `System Proxy`。
3. 重启 Clash Verge。
4. 如果网络仍异常，重启电脑。
5. 需要访问局域网时，在规则里把内网地址设为 `DIRECT`。

常见内网地址段：

```text
192.168.0.0/16
10.0.0.0/8
172.16.0.0/12
127.0.0.0/8
```

## 什么时候不建议开 TUN

这些情况先别开，或者开之前准备好回滚：

- 正在使用公司 VPN、网银控件或特殊内网软件。
- 电脑没有管理员权限。
- 安全软件会拦截虚拟网卡。
- 你只需要浏览器走代理，Codex 已经稳定。

## 最小回滚步骤

1. 关闭 Clash Verge 里的 `TUN Mode`。
2. 保留或重新打开 `System Proxy`。
3. 完全重启 Codex。
4. 如果还是异常，重启电脑。

如果之前设置过环境变量，也可以回滚：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clear-proxy-env.ps1
```

## 参考资料

- Clash Verge Rev FAQ: <https://clashvergerev.com/en/faq>
- Clash Verge Rev Bypass 文档: <https://www.clashverge.dev/guide/bypass.html>
- Clashhelp 的 TUN 模式教程: <https://clashhelp.com/zh-CN/blog/articles/clash-verge-rev-tun-mode-guide.html>
