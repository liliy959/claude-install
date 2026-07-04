# Claude Code 一键安装脚本

解决国内网络环境下 Claude Code 安装困难的问题。

## 快速使用

**Windows（PowerShell）：**

```powershell
irm https://liliy959.github.io/claude-install/cc.ps1 | iex
```

**macOS / Linux（终端）：**

```bash
curl -fsSL https://liliy959.github.io/claude-install/install.sh | bash
```

## 做了什么

1. 自动识别操作系统（Windows / macOS / Linux）
2. 从 GitHub 获取 Claude Code 最新版本
3. 通过国内镜像加速下载安装包
4. 自动完成安装

## 自己部署

1. Fork 本仓库
2. 在 Settings → Pages 中开启 GitHub Pages
3. 选 `main` 分支，保存
4. 你的地址就是 `https://你的用户名.github.io/这个仓库/cc.ps1`

> 推荐绑定自定义域名或用 Cloudflare Pages 托管，国内访问更稳定。

## 镜像列表

脚本内置了以下 GitHub 加速镜像（按顺序尝试）：

- `ghfast.top`
- `ghproxy.net`
- `github.moeyy.xyz`

全部失败则直连 GitHub。

## License

MIT
