# Codex Reconnecting Troubleshooting Guide

中文 | Windows | Codex Desktop | Clash Verge / local proxy

This repository collects practical ways to diagnose and fix repeated `Reconnecting` loops in Codex Desktop, especially when the root cause is unstable direct access, DNS pollution, or an app process that does not consistently inherit the Windows system proxy.

## Quick Fix

If you are on Windows and use Clash Verge or a similar local proxy, first find the local HTTP proxy port. Common ports are `7890`, `7897`, and `10809`.

Then run PowerShell:

```powershell
.\scripts\set-proxy-env.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

Fully quit Codex Desktop, confirm no `Codex.exe` or `codex.exe` process remains in Task Manager, then reopen Codex.

## Why This Happens

The `Reconnecting` message usually means the client is retrying a streaming connection. In affected environments, these are common causes:

- DNS returns polluted or unreachable IP addresses for OpenAI domains.
- Direct access to `api.openai.com:443` fails.
- Windows system proxy is enabled, but one Codex helper process does not consistently use it.
- The local proxy is running, but the selected proxy node is unstable for long-lived HTTPS streams.
- WebSocket, HTTP/2, or long-running TLS connections are interrupted by the network path.

## Diagnose

Run:

```powershell
.\scripts\diagnose-codex-network.ps1
```

The script checks:

- Windows system proxy.
- User environment proxy variables.
- Whether common local proxy ports are listening.
- DNS resolution for OpenAI domains.
- Direct TCP connectivity.
- Connectivity through the configured proxy.
- Current Codex network connections.

## Fix Methods

### 1. Set Proxy Environment Variables

Some desktop helper processes read `HTTP_PROXY`, `HTTPS_PROXY`, and `ALL_PROXY` more reliably than the Windows GUI proxy setting.

```powershell
.\scripts\set-proxy-env.ps1 -ProxyUrl "http://127.0.0.1:7897"
```

Restart Codex after running this.

### 2. Keep Localhost Out of Proxy

The scripts set:

```text
NO_PROXY=localhost,127.0.0.1,::1
```

This prevents local MCP tools, dev servers, and plugin helpers from being routed through the proxy.

### 3. Fix DNS or Avoid Direct DNS

If `Resolve-DnsName api.openai.com` returns an unexpected or unreachable IP, direct access may fail even if your browser appears to work.

Recommended actions:

- Prefer proxy mode that performs remote DNS resolution.
- In Clash Verge, try TUN mode if normal system proxy mode is not enough.
- Switch to a more reliable DNS provider in the proxy client.
- Avoid relying on direct system DNS for OpenAI domains in restricted networks.

### 4. Switch Proxy Node

If proxy tests connect but long answers still reconnect, switch to a node with better TLS and streaming stability. A node can pass a basic `curl -I` test but still drop long-lived response streams.

### 5. Restart Codex Completely

After changing proxy variables or system proxy settings, fully exit Codex. Environment variables are read when a process starts, so existing processes keep old values.

## Undo

To remove the user-level proxy environment variables:

```powershell
.\scripts\clear-proxy-env.ps1
```

Restart Codex after clearing them.

## Notes

- A `401 Unauthorized` response from `https://api.openai.com/v1/models` without an API key is a useful sign: it means the HTTPS route reached OpenAI correctly.
- A `403 Forbidden` response from a browser-only ChatGPT endpoint can be normal because Cloudflare may challenge non-browser clients.
- Do not commit API keys, tokens, proxy subscription URLs, or private node information.

## License

MIT
