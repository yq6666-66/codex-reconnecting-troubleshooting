# 其它 VPN 和代理工具怎么处理

这份文档不绑定 Clash Verge。只要你遇到 Codex Desktop 反复 `Reconnecting`，可以先判断你用的是哪一类工具，再选对应方案。

## 先分清三类工具

### 浏览器插件代理

典型例子：

- Chrome/Edge 里的代理插件。
- 只影响浏览器的 VPN 扩展。

特点：

- 浏览器能打开 ChatGPT 或 GitHub。
- Codex、PowerShell、Git、npm 不一定走这个代理。

处理：

- 浏览器插件通常救不了 Codex Desktop。
- 换成支持系统代理、本地 HTTP/SOCKS 端口或 TUN/VPN 模式的工具。

### 本地代理客户端

典型例子：

- Clash Verge / Clash Verge Rev
- v2rayN
- NekoRay / NekoBox
- sing-box GUI
- Hiddify
- Shadowsocks Windows 客户端

特点：

- 本机通常会有 `127.0.0.1:端口`。
- 可能提供 HTTP 端口、SOCKS 端口，或者两者都有。
- Codex 可以通过 `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY` 使用它。

处理：

1. 开启系统代理。
2. 找到 HTTP 或 SOCKS 端口。
3. 用本仓库的一键脚本设置环境变量。
4. 完全重启 Codex。

### 真 VPN / TUN / 全局接管

典型例子：

- Clash/Mihomo TUN
- sing-box TUN
- Hiddify VPN mode
- WireGuard
- OpenVPN
- Tailscale
- 公司 VPN

特点：

- 可能没有本地 HTTP 代理端口。
- 系统流量会被虚拟网卡或 VPN 适配器接管。
- 对不读代理环境变量的程序更有效。

处理：

- 如果它能稳定访问 OpenAI，Codex 通常也能受益。
- 如果公司 VPN 限制外网，可能反而会让 Codex 更不稳定。
- 公司 VPN 和代理工具同时开时，优先确认路由和 DNS 没有互相打架。

## 常见工具怎么配置

### Clash Verge / Clash Verge Rev

常见端口：

```text
HTTP: 7897 或 7890
SOCKS: 7898 或 7891
```

手动指定 HTTP：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

手动指定 SOCKS5：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "socks5h://127.0.0.1:7898"
```

### v2rayN

常见端口：

```text
SOCKS: 10808
HTTP: 10809
```

优先试 HTTP：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:10809"
```

如果只有 SOCKS：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "socks5h://127.0.0.1:10808"
```

### sing-box

sing-box 可能有两种用法：

- 本地 HTTP/SOCKS 入站。
- TUN 入站。

如果配置了本地端口，按 HTTP/SOCKS 方法处理。如果使用 TUN，确认 TUN 和 DNS 规则正常，然后完全重启 Codex。

### Hiddify

Hiddify 常见模式包括系统代理和 VPN 模式。

处理顺序：

1. 先用系统代理模式。
2. 运行一键脚本。
3. 如果 Codex 仍然重连，尝试 VPN/TUN 模式。
4. 如果 VPN 模式影响局域网或公司网络，关闭 VPN 模式并回到系统代理。

### NekoRay / NekoBox

处理方式和 v2rayN 类似：

1. 找到 HTTP 或 SOCKS 监听端口。
2. 优先用 HTTP 端口。
3. 如果只有 SOCKS，用 `socks5h://`。

示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "socks5h://127.0.0.1:2080"
```

端口以你的客户端实际显示为准。

### WireGuard / OpenVPN / 公司 VPN

这些通常不是本地 HTTP 代理，而是系统级 VPN。

处理建议：

- 如果 VPN 能直接访问 OpenAI，通常不用设置 `HTTP_PROXY`。
- 如果 VPN 不能访问 OpenAI，Codex 也会失败。
- 如果公司 VPN 劫持 DNS 或限制外网，可能需要断开公司 VPN 后使用代理工具。
- 如果必须同时使用公司 VPN 和代理，优先使用支持分流规则的工具，确保 OpenAI 相关域名走可用出口。

## HTTP 和 SOCKS 怎么选

优先级：

1. 有 HTTP 端口，优先用 `http://127.0.0.1:端口`。
2. 只有 SOCKS 端口，用 `socks5h://127.0.0.1:端口`。
3. 如果两者都失败，换节点或检查客户端是否真的在监听。

为什么 SOCKS 用 `socks5h://`：

- `socks5h` 表示让代理端处理域名解析。
- 这能减少本地 DNS 污染导致的失败。

## 判断是不是浏览器插件的问题

如果你看到这种情况：

- 浏览器能打开 ChatGPT。
- PowerShell 里 `curl https://api.openai.com/v1/models` 失败。
- 本地没有 `127.0.0.1` 代理端口。

那大概率是浏览器插件只管浏览器。Codex Desktop 不在浏览器里，所以不会自动走它。

解决：

- 换成有系统代理或 TUN 模式的客户端。
- 或者让插件/客户端提供本地 HTTP/SOCKS 端口，再用本仓库脚本设置环境变量。

## 推荐排查命令

手动测试 HTTP：

```powershell
curl.exe -sS -I --max-time 20 -x http://127.0.0.1:10809 https://api.openai.com/v1/models
```

手动测试 SOCKS5：

```powershell
curl.exe -sS -I --max-time 20 -x socks5h://127.0.0.1:10808 https://api.openai.com/v1/models
```

看到 `401 Unauthorized` 是好事，说明已经连到 OpenAI API。
