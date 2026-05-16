# 新手操作指南

这份文档给完全不熟悉命令行的用户使用。你只需要按顺序复制命令。

## 适用场景

你遇到的是下面这种情况：

- Codex Desktop 回答前反复显示 `Reconnecting`。
- 每次要等很多次重连才有回答。
- 你在 Windows 上使用 Clash Verge、Clash Verge Rev 或类似代理软件。

## 准备工作

先确认三件事：

1. 代理软件已经打开。
2. 代理软件里的“系统代理”已经开启。
3. 浏览器能打开 GitHub。

如果浏览器都打不开 GitHub，先修复代理软件或网络。

## 方法 A：你会用 Git

打开 PowerShell，复制下面三行：

```powershell
git clone https://github.com/19306069208/codex-reconnecting-troubleshooting.git
cd codex-reconnecting-troubleshooting
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1
```

运行结束后，完全退出 Codex，再重新打开。

## 方法 B：你不会用 Git

1. 打开这个页面：<https://github.com/19306069208/codex-reconnecting-troubleshooting>
2. 点击绿色 `Code` 按钮。
3. 点击 `Download ZIP`。
4. 解压 ZIP 文件。
5. 进入解压后的文件夹。
6. 在文件夹空白处右键，选择“在终端中打开”或“在 PowerShell 中打开”。
7. 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1
```

运行结束后，完全退出 Codex，再重新打开。

## 如果脚本说没有找到代理

先尝试 Clash Verge 常见端口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

如果不行，再试：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7890"
```

如果还不行，打开 Clash Verge，找到 HTTP 代理端口，把端口替换进去。

## 如何完全重启 Codex

只点窗口右上角关闭有时不够。建议这样做：

1. 关闭 Codex 窗口。
2. 按 `Ctrl + Shift + Esc` 打开任务管理器。
3. 搜索 `Codex`。
4. 如果看到 `Codex.exe` 或 `codex.exe`，结束任务。
5. 重新打开 Codex。

## 如果重启后还是 Reconnecting

先不要慌，这通常说明配置已经生效，但代理节点或系统流量接管还不够稳。按顺序做：

1. 在 Clash Verge 里换一个节点。
2. 再完整重启 Codex。
3. 如果仍然反复重连，开启 TUN 模式。

TUN 开启方法看这里：

- [Clash Verge TUN 模式开启指南](./tun-mode-clash-verge.md)

## 什么时候需要 TUN

看到这些情况，就适合尝试 TUN：

- 诊断脚本显示 Codex 没有稳定连到 `127.0.0.1:7897`。
- `api.openai.com` 直连失败，但代理偶尔成功、偶尔 TLS 失败。
- 浏览器能用，Codex 还是重连。
- 换节点后只能短时间正常，长回答又断。

## 如何确认修复成功

重新打开 Codex 后，问一个稍长的问题。

如果回答开始得更稳定，不再反复 `Reconnecting`，就说明修复成功。

如果仍然重连，运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1
```

把输出中这几块保存下来：

- `Windows System Proxy`
- `Common Local Proxy Ports`
- `DNS Resolution`
- `Direct TCP Connectivity`
- `Proxy HTTPS Test`
- `Codex TCP Connections`
- `Possible TUN Adapters`

分享给别人排查时，先检查里面有没有 token、cookie、代理订阅链接等敏感信息。

## 常见结果怎么看

### api.openai.com 返回 401

这是好事。没有 API key 的情况下返回 `401 Unauthorized`，说明已经连到 OpenAI API。

### Direct TCP Connectivity 失败

这说明直连不可靠，需要继续使用代理、TUN 模式或远程 DNS。

### Proxy HTTPS Test 也失败

这说明代理本身不稳定，优先换节点，或者检查代理软件是否真的在监听对应端口。

### Possible TUN Adapters 为空

这通常说明 TUN 没开，或者虚拟网卡名称不是脚本能识别的常见名称。先按 TUN 指南检查 Clash Verge 里的开关。

## 回滚

如果修复后影响了其它工具，可以回滚环境变量：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clear-proxy-env.ps1
```

如果是 TUN 导致网络异常，关闭 Clash Verge 里的 `TUN Mode`，然后重启 Clash、Codex，必要时重启电脑。
