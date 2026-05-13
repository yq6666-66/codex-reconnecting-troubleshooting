# Windows Codex Reconnecting 排障手册

这份手册整理 Windows 上 Codex Desktop 反复出现 `Reconnecting` 的处理方法。重点覆盖 Clash Verge、本地代理、DNS 污染、环境变量代理和长连接不稳定。

如果你是新手，先看 [beginner-guide.md](./beginner-guide.md)。

## 现象

常见表现：

- 每次提问后显示多次 `Reconnecting` 才开始回答。
- 短回答偶尔正常，长回答更容易断。
- 浏览器能访问部分 OpenAI 或 ChatGPT 页面，但 Codex Desktop 不稳定。
- `Test-NetConnection api.openai.com -Port 443` 失败。
- 通过代理访问 `https://api.openai.com/v1/models` 能得到 `401 Unauthorized`。

## 推荐处理顺序

按这个顺序做，能减少反复试错：

1. 确认代理软件已开启，系统代理已开启。
2. 运行 `scripts/fix-codex-reconnecting.ps1`。
3. 完全重启 Codex。
4. 如果仍然重连，运行 `scripts/diagnose-codex-network.ps1`。
5. 根据诊断结果换节点、开启 TUN、修复 DNS 或手动指定代理端口。

## 一键修复

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1
```

这个脚本会：

- 尝试读取 Windows 系统代理。
- 如果没有系统代理，尝试检测常见本地代理端口。
- 测试代理是否能连接 OpenAI API。
- 写入当前 Windows 用户的代理环境变量。
- 提醒你完全重启 Codex。

手动指定代理：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-codex-reconnecting.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

## 详细诊断

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1
```

如果你已经知道代理地址：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\diagnose-codex-network.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

## 结果怎么看

| 诊断区域 | 结果 | 含义 | 下一步 |
| --- | --- | --- | --- |
| `Common Local Proxy Ports` | 某个端口 `True` | 本地代理在监听 | 可以用这个端口设置代理 |
| `Direct TCP Connectivity` | `False` | 直连 OpenAI 不可靠 | 需要代理、TUN 或远程 DNS |
| `Proxy HTTPS Test` | OpenAI API 返回 `401` | 代理路径能连到 OpenAI | 设置环境变量并重启 Codex |
| `Proxy HTTPS Test` | curl 超时或 TLS 失败 | 代理节点或端口不稳定 | 换节点或检查端口 |
| `Codex TCP Connections` | 连到 `127.0.0.1:端口` | Codex 正在走本地代理 | 继续观察是否稳定 |
| `Codex TCP Connections` | 直接连外部 IP 且卡住 | 有进程可能绕过代理 | 开 TUN 或重启 Codex |

## 方法一：设置用户级代理环境变量

适用场景：

- Windows 系统代理已经开启。
- 浏览器基本可用。
- Codex Desktop 仍然反复重连。

执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\set-proxy-env.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

它会写入当前 Windows 用户：

```text
HTTP_PROXY=http://127.0.0.1:7897
HTTPS_PROXY=http://127.0.0.1:7897
ALL_PROXY=http://127.0.0.1:7897
NO_PROXY=localhost,127.0.0.1,::1
```

写入后必须完全重启 Codex。

## 方法二：开启 Clash Verge TUN 模式

适用场景：

- 设置环境变量后仍有进程直连。
- 连接偶尔绕过系统代理。
- DNS 解析明显不可靠。

建议：

- 开启 TUN 模式。
- 开启远程 DNS 或 fake-ip/enhanced-mode。
- 确认 OpenAI 相关域名命中代理规则。

注意：TUN 模式会影响整个系统网络。开启后先测试浏览器、Git、npm、MCP 本地服务是否正常。

## 方法三：换代理节点

适用场景：

- 代理可以 CONNECT。
- 偶发 TLS 握手失败。
- 长回答更容易中断。

处理：

- 换延迟更低、丢包更少的节点。
- 优先选择对 Cloudflare 和 OpenAI API 稳定的节点。
- 避免高峰期拥堵节点。

## 方法四：修复 DNS

适用场景：

- `Resolve-DnsName api.openai.com` 返回异常地址。
- 直连 TCP 总是失败。
- 不开代理时 OpenAI 域名解析不稳定。

处理：

- 让代理客户端接管 DNS。
- 使用代理客户端的远程 DNS。
- 避免手动写死 hosts，除非你能长期维护正确地址。

## 方法五：完全重启 Codex

修改环境变量、系统代理、Clash 模式后，需要完全关闭 Codex。

PowerShell 查看残留进程：

```powershell
Get-Process | Where-Object { $_.ProcessName -match '^Codex$|^codex$' }
```

如果仍有进程，退出应用或在任务管理器中结束，再重新打开。

## 回滚

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\clear-proxy-env.ps1
```

然后重启 Codex。

## 安全提醒

- 不要把 GitHub token、OpenAI API key、Clash 订阅链接提交到仓库。
- 分享排障输出前，检查是否包含用户名、内网地址、代理节点、cookie 或 token。
- 如果需要贴日志，优先只贴错误类型、目标域名、端口和是否成功。
