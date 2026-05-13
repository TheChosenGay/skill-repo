#!/bin/bash
#
# install.sh — 将 skill-repo 中的 skills 安装到对应平台
# 支持：Claude Code、CodeBuddy Code、Cursor
#
# 用法：
#   ./install.sh          交互式安装
#   ./install.sh --init   初始化检测：只安装缺失的 skill，不做覆盖询问
#   ./install.sh --force  强制覆盖所有已安装的 skill
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"
CURSOR_SRC="$SCRIPT_DIR/cursor-rules"

if [ ! -d "$COMMANDS_SRC" ]; then
  echo "错误：找不到 commands 目录: $COMMANDS_SRC"
  exit 1
fi

# 参数解析
MODE="interactive"   # interactive | init | force
case "${1:-}" in
  --init)   MODE="init" ;;
  --force)  MODE="force" ;;
esac

# 检测平台
TARGETS=()
PLATFORM_NAMES=()
PLATFORM_TYPES=()  # "file" 或 "dir"

if [ -d "$HOME/.codebuddy" ]; then
  TARGETS+=("$HOME/.codebuddy/commands")
  PLATFORM_NAMES+=("CodeBuddy Code")
  PLATFORM_TYPES+=("file")
fi

if [ -d "$HOME/.claude" ]; then
  TARGETS+=("$HOME/.claude/commands")
  PLATFORM_NAMES+=("Claude Code")
  PLATFORM_TYPES+=("dir")
fi

if [ -d "$HOME/.cursor" ]; then
  TARGETS+=("$HOME/.cursor/rules")
  PLATFORM_NAMES+=("Cursor")
  PLATFORM_TYPES+=("cursor")
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "未检测到支持的 AI 平台"
  echo "支持的平台：CodeBuddy Code（~/.codebuddy）、Claude Code（~/.claude）、Cursor（~/.cursor）"
  exit 1
fi

echo "检测到以下平台，将同步安装："
for i in "${!PLATFORM_NAMES[@]}"; do
  echo "  - ${PLATFORM_NAMES[$i]} → ${TARGETS[$i]}"
done
echo ""

# ---- 初始化检测：列出缺失的 skill ----
detect_missing() {
  local missing=0
  echo "=== 技能安装检测 ==="
  echo ""
  for category_dir in "$COMMANDS_SRC"/*/; do
    [ -d "$category_dir" ] || continue
    local category
    category=$(basename "$category_dir")

    for skill_file in "$category_dir"*.md; do
      [ -f "$skill_file" ] || continue
      local skill_name
      skill_name=$(basename "$skill_file")

      # 检查各平台是否已安装
      local installed_in=""
      for i in "${!TARGETS[@]}"; do
        if [ "${PLATFORM_TYPES[$i]}" = "file" ] || [ "${PLATFORM_TYPES[$i]}" = "cursor" ]; then
          local target="${TARGETS[$i]}/$category/$skill_name"
          if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_file" ]; then
            installed_in="${installed_in}${PLATFORM_NAMES[$i]}, "
          fi
        elif [ "${PLATFORM_TYPES[$i]}" = "dir" ]; then
          local cat_link="${TARGETS[$i]}/$category"
          if [ -L "$cat_link" ] && [ "$(readlink "$cat_link")" = "${category_dir%/}" ]; then
            installed_in="${installed_in}${PLATFORM_NAMES[$i]}, "
          fi
        fi
      done

      if [ -z "$installed_in" ]; then
        echo "  ✗ ${category}/${skill_name} — 未安装"
        missing=$((missing + 1))
      else
        echo "  ✓ ${category}/${skill_name} — 已安装到: ${installed_in%, }"
      fi
    done
  done

  if [ "$missing" -eq 0 ]; then
    echo ""
    echo "所有 skill 已安装，无需操作。"
    return 0
  else
    echo ""
    echo "共 $missing 个 skill 未安装。"
    return 1
  fi
}

# ---- 安装到 CodeBuddy Code：每个 .md 文件单独创建 symlink ----
install_file_symlinks() {
  local COMMANDS_DST="$1"
  local platform_name="$2"
  local installed=0
  local skipped=0

  for category_dir in "$COMMANDS_SRC"/*/; do
    [ -d "$category_dir" ] || continue
    local category
    category=$(basename "$category_dir")
    local cat_dst="$COMMANDS_DST/$category"
    mkdir -p "$cat_dst"

    for skill_file in "$category_dir"*.md; do
      [ -f "$skill_file" ] || continue
      local skill_name
      skill_name=$(basename "$skill_file")
      local target="$cat_dst/$skill_name"

      if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_file" ]; then
        echo "  [$platform_name] 跳过 $category/$skill_name （已安装）"
        skipped=$((skipped + 1))
        continue
      fi

      if [ -e "$target" ] && [ "$MODE" = "init" ]; then
        echo "  [$platform_name] 跳过 $category/$skill_name （目标已存在，非 symlink，请手动处理）"
        skipped=$((skipped + 1))
        continue
      fi

      [ -e "$target" ] && rm -f "$target"
      ln -s "$skill_file" "$target"
      echo "  [$platform_name] 已安装 $category/$skill_name → $target"
      installed=$((installed + 1))
    done
  done

  echo "  [$platform_name] 完成：已安装 $installed 个文件，跳过 $skipped 个"
}

# ---- 安装到 Claude Code：每个分类目录创建一个 symlink ----
install_dir_symlinks() {
  local COMMANDS_DST="$1"
  local platform_name="$2"
  local installed=0
  local skipped=0

  mkdir -p "$COMMANDS_DST"

  for category_dir in "$COMMANDS_SRC"/*/; do
    [ -d "$category_dir" ] || continue
    local category
    category=$(basename "$category_dir")
    local target="$COMMANDS_DST/$category"

    if [ -L "$target" ] && { [ "$(readlink "$target")" = "$category_dir" ] || [ "$(readlink "$target")" = "${category_dir%/}" ]; }; then
      echo "  [$platform_name] 跳过 $category/ （已安装）"
      skipped=$((skipped + 1))
      continue
    fi

    if [ -e "$target" ] && [ "$MODE" = "init" ]; then
      echo "  [$platform_name] 跳过 $category/ （目标已存在，非 symlink，请手动处理）"
      skipped=$((skipped + 1))
      continue
    fi

    [ -e "$target" ] && rm -rf "$target"
    ln -s "${category_dir%/}" "$target"
    echo "  [$platform_name] 已安装 $category/ → $target"
    installed=$((installed + 1))
  done

  echo "  [$platform_name] 完成：已安装 $installed 个分类，跳过 $skipped 个"
}

# ---- 安装到 Cursor：生成 .mdc 规则文件 ----
install_cursor_rules() {
  local CURSOR_DST="$1"
  local platform_name="Cursor"
  local installed=0
  local skipped=0

  mkdir -p "$CURSOR_DST"

  for category_dir in "$COMMANDS_SRC"/*/; do
    [ -d "$category_dir" ] || continue
    local category
    category=$(basename "$category_dir")

    for skill_file in "$category_dir"*.md; do
      [ -f "$skill_file" ] || continue
      local skill_name
      skill_name=$(basename "$skill_file" .md)
      local mdc_name="${category}-${skill_name}.mdc"
      local target="$CURSOR_DST/$mdc_name"

      if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_file" ]; then
        echo "  [$platform_name] 跳过 $mdc_name （已安装）"
        skipped=$((skipped + 1))
        continue
      fi

      if [ -e "$target" ] && [ "$MODE" = "init" ]; then
        echo "  [$platform_name] 跳过 $mdc_name （目标已存在，请手动处理）"
        skipped=$((skipped + 1))
        continue
      fi

      # 读取 skill 内容，提取标题和描述
      local title="${category}/${skill_name}"
      local description=""
      # 提取第一个 # 标题作为描述
      if head -1 "$skill_file" | grep -q "^# "; then
        title=$(head -1 "$skill_file" | sed 's/^# //')
      fi
      # 用前 200 字符作为 description
      description=$(head -20 "$skill_file" | grep -v "^#" | grep -v "^$" | head -1 | cut -c1-200)

      # 创建 .mdc wrapper 文件，symlink 到 skill 原始文件
      # Cursor .mdc 格式：YAML frontmatter + 内容
      local mdc_file="$CURSOR_SRC/$category/$skill_name.mdc"
      mkdir -p "$(dirname "$mdc_file")"

      cat > "$mdc_file" << MDCEOF
---
description: "${title} — ${description}"
globs: ["*.swift", "*.tsx", "*.ts", "*.js", "*.jsx", "*.vue"]
alwaysApply: false
---

MDCEOF
      # 追加原始 skill 内容（去掉第一行标题，因为 frontmatter 已包含）
      tail -n +2 "$skill_file" >> "$mdc_file"

      # symlink 到 Cursor rules 目录
      if [ -e "$target" ]; then rm -f "$target"; fi
      ln -s "$mdc_file" "$target"
      echo "  [$platform_name] 已安装 $mdc_name → $target"
      installed=$((installed + 1))
    done
  done

  echo "  [$platform_name] 完成：已安装 $installed 个规则，跳过 $skipped 个"
}

# ---- 执行安装 ----
echo "=== 安装模式：$MODE ==="
echo ""

# 先做检测
detect_missing
detect_result=$?

if [ "$MODE" = "interactive" ] && [ "$detect_result" -eq 0 ]; then
  echo "所有 skill 已安装，无需操作。"
  exit 0
fi

# force 或 init 模式：总是运行安装（安装函数自动跳过已安装的）

for i in "${!TARGETS[@]}"; do
  case "${PLATFORM_TYPES[$i]}" in
    file)
      install_file_symlinks "${TARGETS[$i]}" "${PLATFORM_NAMES[$i]}"
      ;;
    dir)
      install_dir_symlinks "${TARGETS[$i]}" "${PLATFORM_NAMES[$i]}"
      ;;
    cursor)
      install_cursor_rules "${TARGETS[$i]}"
      ;;
  esac
done

echo ""
echo "已安装的 skills："
for category_dir in "$COMMANDS_SRC"/*/; do
  [ -d "$category_dir" ] || continue
  category=$(basename "$category_dir")
  for skill_file in "$category_dir"*.md; do
    [ -f "$skill_file" ] || continue
    skill_name=$(basename "$skill_file" .md)
    if [ ${#TARGETS[@]} -gt 1 ]; then
      echo "  CodeBuddy: /${category}:${skill_name}  |  Claude: /${category}-${skill_name}  |  Cursor: @${category}-${skill_name}"
    else
      case "${PLATFORM_TYPES[0]}" in
        file)    echo "  /${category}:${skill_name}" ;;
        dir)     echo "  /${category}-${skill_name}" ;;
        cursor)  echo "  @${category}-${skill_name}" ;;
      esac
    fi
  done
done

echo ""
echo "在对应 AI 工具中输入 skill 名称即可使用。"
