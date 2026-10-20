# Codex Reconnecting Troubleshooting Guide

Windows 上 Codex Desktop 反复显示 `Reconnecting` 的排障和修复指南，适合使用 Clash Verge、Clash Verge Rev、Mihomo、V2RayN、sing-box、Hiddify、NekoRay、WireGuard、OpenVPN、公司 VPN 等代理或 VPN 工具的用户。

目标很朴素：让新手也能照着做，不需要先理解一堆网络术语。

## 新手优先路线

### 1. 下载仓库

会用 Git：

```powershell
git clone https://github.com/yq6666-66/codex-reconnecting-troubleshooting.git
cd codex-reconnecting-troubleshooting
```

不会用 Git：

1. 打开仓库页面。
2. 点绿色 `Code` 按钮。
3. 点 `Download ZIP`。
4. 解压后，在文件夹空白处右键，选择“在终端中打开”。

### 2. 先跑一键修复

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1
```

如果你知道代理工具的 HTTP 端口，比如 `7897`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

如果你的工具只有 SOCKS5 端口，比如 v2rayN 常见的 `10808`：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "socks5h://127.0.0.1:10808"
```

### 3. 完全重启 Codex

关闭 Codex 窗口后，再打开任务管理器，确认没有 `Codex.exe` 或 `codex.exe`。然后重新打开 Codex。

## 如果还是 Reconnecting

按这个顺序继续：

1. 在代理软件里换一个稳定节点。
2. 完全重启 Codex。
3. 运行诊断脚本。
4. 如果 Codex 已经走代理但仍然断，开启 TUN 模式。

诊断脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1
```

如果直连测试等很久，可以用快速模式跳过直连 TCP：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1 -SkipDirectTcp
```

TUN 模式新手指南：

- [Clash Verge TUN 模式开启指南](./docs/tun-mode-clash-verge.md)
- [其它 VPN 和代理工具怎么处理](./docs/other-vpn-and-proxy-tools.md)

## 怎么判断问题在哪里

| 现象 | 大概率原因 | 处理 |
| --- | --- | --- |
| `api.openai.com` 直连失败 | DNS 或直连网络不可用 | 使用代理或 TUN，不要依赖直连 |
| 代理访问 OpenAI 返回 `401 Unauthorized` | 代理路径能连到 OpenAI API | 这是好结果，重启 Codex 后再试 |
| 代理偶发 TLS 握手失败 | 节点或长连接不稳定 | 换节点，必要时开 TUN |
| Codex 连接到外部 IP 而不是 `127.0.0.1` | 有进程绕过代理 | 开 TUN，或重启 Codex |
| Codex 已连接 `127.0.0.1:7897` 但仍重连 | 节点、规则或长连接稳定性问题 | 换节点，开 TUN，检查规则 |
| 浏览器能用但 Codex 不能用 | 可能只是浏览器插件代理 | 换系统代理、本地端口或 TUN/VPN |
| 只有 VPN 没有本地端口 | 不是 HTTP 代理模式 | 确认 VPN 能访问 OpenAI，必要时配置分流 |

## 脚本说明

- `scripts/fix-codex-reconnecting.ps1`：新手优先使用的一键修复脚本。
- `scripts/diagnose-codex-network.ps1`：检查系统代理、环境变量、常见 HTTP/SOCKS 端口、DNS、OpenAI 连通性、Codex 连接和疑似 TUN 网卡。
- `scripts/set-proxy-env.ps1`：手动设置代理环境变量。
- `scripts/clear-proxy-env.ps1`：回滚代理环境变量。

## 文档说明

- [新手操作指南](./docs/beginner-guide.md)
- [Windows Codex Reconnecting 排障手册](./docs/windows-codex-reconnecting.md)
- [Clash Verge TUN 模式开启指南](./docs/tun-mode-clash-verge.md)
- [其它 VPN 和代理工具怎么处理](./docs/other-vpn-and-proxy-tools.md)

## 一键修复做了什么

脚本会检测可用代理，然后写入当前 Windows 用户的环境变量：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
NO_PROXY
```

这会让更多命令行程序和后台进程明确走本地代理。`NO_PROXY=localhost,127.0.0.1,::1` 会避免本地开发服务、MCP 工具和插件服务被错误送进代理。

## TUN 模式什么时候用

先别急着开 TUN。一般先用一键修复和重启 Codex。

需要 TUN 的典型情况：

- Codex 明明设置了代理，还是会绕过代理。
- 代理测试成功，但长回答持续重连。
- DNS 返回异常地址，直连 OpenAI 一直失败。
- 你希望命令行、Electron 应用和后台进程都更稳定地走代理规则。

详细步骤看：[Clash Verge TUN 模式开启指南](./docs/tun-mode-clash-verge.md)。

如果你用的不是 Clash Verge，看：[其它 VPN 和代理工具怎么处理](./docs/other-vpn-and-proxy-tools.md)。

## 回滚

如果修复后影响了其它工具：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clear-proxy-env.ps1
```

如果是 TUN 导致网络异常，先关闭 Clash Verge 里的 `TUN Mode`，再重启 Clash 和 Codex。

## 安全提醒

- 不要提交 OpenAI API key、GitHub token、Clash 订阅链接、代理节点信息。
- 分享诊断输出前，检查是否包含用户名、内网 IP、cookie 或 token。
- 本仓库脚本只修改当前 Windows 用户的代理环境变量，不会修改系统文件。

## License

MIT
