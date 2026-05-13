# Windows Codex Reconnecting 排障手册

这份手册整理 Windows 上 Codex Desktop 反复出现 `Reconnecting` 的处理方法。重点覆盖 Clash Verge、本地代理、DNS 污染、环境变量代理和长连接不稳定。

## 现象

常见表现：

- 每次提问后显示多次 `Reconnecting` 才开始回答。
- 短回答偶尔正常，长回答更容易断。
- 浏览器能访问部分 OpenAI 页面，但 Codex Desktop 不稳定。
- `Test-NetConnection api.openai.com -Port 443` 失败。
- 通过 `curl -x http://127.0.0.1:7897 https://api.openai.com/v1/models` 能得到 `401 Unauthorized`。

## 判断标准

### 直连测试

```powershell
Test-NetConnection api.openai.com -Port 443
Resolve-DnsName api.openai.com
```

如果 TCP 失败，或者 DNS 返回明显异常的地址，说明直连路径不可靠。

### 代理测试

```powershell
curl.exe -I --max-time 20 -x http://127.0.0.1:7897 https://api.openai.com/v1/models
```

如果返回 `401 Unauthorized`，说明通过代理已经连到 OpenAI API。这里没有传 API key，`401` 是预期结果。

### 本地代理端口测试

```powershell
Test-NetConnection 127.0.0.1 -Port 7897
```

如果失败，说明 Clash 或代理客户端没有在该端口监听，或者端口写错。

## 方法一：设置用户级代理环境变量

适用场景：

- Windows 系统代理已经开启。
- 浏览器基本可用。
- Codex Desktop 仍然反复重连。

执行：

```powershell
.\scripts\set-proxy-env.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

这个方法会写入当前 Windows 用户的环境变量：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
NO_PROXY
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

## 方法三：换节点

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
- 不要只依赖系统 DNS。
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
.\scripts\clear-proxy-env.ps1
```

然后重启 Codex。

## 安全提醒

- 不要把 GitHub token、OpenAI API key、Clash 订阅链接提交到仓库。
- 分享排障输出前，检查是否包含用户名、内网地址、代理节点或 cookie。
- 如果需要贴日志，优先只贴错误类型、目标域名、端口和是否成功。
