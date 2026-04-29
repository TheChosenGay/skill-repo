# skill-repo

个人 Claude Code 自定义 Skill 集合。通过 symlink 安装到 `~/.claude/commands/`，所有项目全局可用。

## 安装

```bash
git clone https://github.com/<your-username>/skill-repo.git
cd skill-repo
chmod +x install.sh
./install.sh
```

## 卸载

```bash
./uninstall.sh
```

## 更新

```bash
cd skill-repo
git pull
```

Symlink 会自动指向最新文件，无需重新安装。

## 已有 Skills

| 命令 | 分类 | 说明 |
|------|------|------|
| `/dev-flow` | dev | iOS 需求开发全流程（代码分析 → 方案设计 → 迭代开发 → CR → 文档沉淀） |
| `/biz-store-setup` | biz | 电商线上店铺开店流程（需求梳理 → 搭建 → 验证 → 上线） |

## 目录结构

```
skill-repo/
├── commands/
│   ├── dev/              # 开发相关 skills
│   │   └── flow.md       → /dev-flow
│   └── biz/              # 业务相关 skills
│       └── store-setup.md → /biz-store-setup
├── install.sh            # 安装脚本
├── uninstall.sh          # 卸载脚本
└── README.md
```

## 新增 Skill

1. 选择或创建分类目录（如 `commands/ops/`）
2. 在目录中添加 `.md` 文件（如 `deploy.md`）
3. 命名规则：调用时为 `/<分类>-<文件名>`，例如 `commands/ops/deploy.md` → `/ops-deploy`
4. 提交并推送
5. 其他机器上 `git pull` 即可生效（已安装的 symlink 自动更新）

## 在新机器上使用

```bash
# 1. 克隆仓库（建议放在固定位置）
git clone https://github.com/<your-username>/skill-repo.git ~/skill-repo

# 2. 安装
cd ~/skill-repo && ./install.sh

# 3. 打开 Claude Code，输入 /dev-flow 即可使用
```
