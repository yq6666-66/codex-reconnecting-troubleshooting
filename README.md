# Codex Reconnecting Troubleshooting Guide

Windows 上 Codex Desktop 反复显示 `Reconnecting` 的排障和修复指南，适合使用 Clash Verge、Mihomo、V2RayN、Sing-box 等本地代理的用户。

目标是让新手也能照着做：先跑一键修复，再按结果排查。

## 新手直接操作

### 第 1 步：下载这个仓库

打开 PowerShell，运行：

```powershell
git clone https://github.com/19306069208/codex-reconnecting-troubleshooting.git
cd codex-reconnecting-troubleshooting
```

如果没有安装 Git，也可以在 GitHub 页面点 `Code` -> `Download ZIP`，解压后在文件夹空白处右键，选择“在终端中打开”。

### 第 2 步：确认代理软件已打开

先打开 Clash Verge 或其它代理软件，并确认：

- 系统代理已经开启。
- 能正常访问 GitHub 或 ChatGPT 网页。
- 常见本地代理端口是 `7897`、`7890`、`10809` 或 `1080`。

不知道端口也没关系，下一步脚本会自动检测。

### 第 3 步：运行一键修复

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1
```

如果你已经知道自己的代理端口，例如 Clash Verge 是 `7897`，可以指定：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

### 第 4 步：完全重启 Codex

脚本执行完成后，必须完全退出 Codex Desktop。

建议：

1. 关闭 Codex 窗口。
2. 打开任务管理器。
3. 确认没有 `Codex.exe` 或 `codex.exe`。
4. 重新打开 Codex。

## 怎么判断成功

再次向 Codex 提问。如果不再反复 `Reconnecting`，说明已经修复。

如果仍然重连，运行诊断脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1
```

重点看两处：

- `Direct TCP Connectivity` 如果失败，说明直连 OpenAI 不可靠。
- `Proxy HTTPS Test` 如果 `api.openai.com/v1/models` 返回 `401 Unauthorized`，说明代理路径可以连到 OpenAI API。这里没有传 API key，`401` 是正常结果。

## 常见问题

### 为什么会一直 Reconnecting

通常不是模型在“思考很多次”，而是 Codex 和后端的流式连接断开后自动重试。常见原因包括：

- DNS 返回了不可用或被污染的 OpenAI 地址。
- 直连 `api.openai.com:443` 失败。
- Windows 系统代理开了，但某些 Codex 后台进程没有稳定走系统代理。
- 代理节点能打开网页，但长连接不稳定。
- HTTP/2、WebSocket 或 TLS 长连接被网络路径中断。

### 一键修复脚本做了什么

脚本会检测可用代理，然后写入当前 Windows 用户的环境变量：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
NO_PROXY
```

这会让更多命令行程序和后台进程明确走本地代理。

### 为什么要设置 NO_PROXY

`NO_PROXY=localhost,127.0.0.1,::1` 可以避免本地开发服务、MCP 工具、插件服务被错误送进代理。

### 运行脚本提示禁止执行怎么办

用下面这种方式运行，不需要永久修改系统策略：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1
```

### 脚本找不到代理怎么办

手动指定端口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

如果还是失败，打开代理软件检查 HTTP 端口，或者尝试 `7890`、`10809`。

### 代理测试通过但还是重连怎么办

优先尝试：

1. 换一个更稳定的代理节点。
2. 在 Clash Verge 开启 TUN 模式。
3. 确认 OpenAI、GitHub、Cloudflare 相关域名命中代理规则。
4. 完全重启 Codex，而不是只关闭窗口。

## 文件说明

- `scripts/fix-codex-reconnecting.ps1`：新手优先使用的一键修复脚本。
- `scripts/diagnose-codex-network.ps1`：详细诊断网络、DNS、代理和 Codex 连接。
- `scripts/set-proxy-env.ps1`：手动设置代理环境变量。
- `scripts/clear-proxy-env.ps1`：清理代理环境变量并回滚。
- `docs/beginner-guide.md`：图文式的新手操作流程。
- `docs/windows-codex-reconnecting.md`：更详细的原理和排障手册。

## 回滚

如果你想撤销这个仓库设置过的用户级代理环境变量：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clear-proxy-env.ps1
```

然后完全重启 Codex。

## 安全提醒

- 不要提交 OpenAI API key、GitHub token、Clash 订阅链接、代理节点信息。
- 分享诊断输出前，检查是否包含用户名、内网 IP、cookie 或 token。
- 本仓库脚本只修改当前 Windows 用户的代理环境变量，不会修改系统文件。

## License

MIT
