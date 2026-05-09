#!/bin/bash
#
# install.sh — 将 skill-repo 中的 commands 安装到对应平台的 commands 目录
# 支持：CodeBuddy Code（文件级 symlink）、Claude Code（目录级 symlink）
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"

if [ ! -d "$COMMANDS_SRC" ]; then
  echo "错误：找不到 commands 目录: $COMMANDS_SRC"
  exit 1
fi

# 检测平台
TARGETS=()
PLATFORM_NAMES=()
PLATFORM_TYPES=()  # "file" 或 "dir"

if [ -d "$HOME/.codebuddy" ]; then
  TARGETS+=("$HOME/.codebuddy/commands")
  PLATFORM_NAMES+=("CodeBuddy Code")
  PLATFORM_TYPES+=("file")  # CodeBuddy Code 需要文件级 symlink
fi

if [ -d "$HOME/.claude" ]; then
  TARGETS+=("$HOME/.claude/commands")
  PLATFORM_NAMES+=("Claude Code")
  PLATFORM_TYPES+=("dir")   # Claude Code 用目录级 symlink
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "未检测到支持的 AI 平台（~/.codebuddy 或 ~/.claude 均不存在）"
  exit 1
fi

echo "检测到以下平台，将同步安装："
for i in "${!PLATFORM_NAMES[@]}"; do
  echo "  - ${PLATFORM_NAMES[$i]} → ${TARGETS[$i]}"
done
echo ""

# 安装到 CodeBuddy Code：每个 .md 文件单独创建 symlink
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

      [ -e "$target" ] && rm -f "$target"
      ln -s "$skill_file" "$target"
      echo "  [$platform_name] 已安装 $category/$skill_name → $target"
      installed=$((installed + 1))
    done
  done

  echo "  [$platform_name] 完成：已安装 $installed 个文件，跳过 $skipped 个"
}

# 安装到 Claude Code：每个分类目录创建一个 symlink
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

    [ -e "$target" ] && rm -rf "$target"
    ln -s "${category_dir%/}" "$target"
    echo "  [$platform_name] 已安装 $category/ → $target"
    installed=$((installed + 1))
  done

  echo "  [$platform_name] 完成：已安装 $installed 个分类，跳过 $skipped 个"
}

for i in "${!TARGETS[@]}"; do
  if [ "${PLATFORM_TYPES[$i]}" = "file" ]; then
    install_file_symlinks "${TARGETS[$i]}" "${PLATFORM_NAMES[$i]}"
  else
    install_dir_symlinks "${TARGETS[$i]}" "${PLATFORM_NAMES[$i]}"
  fi
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
      echo "  CodeBuddy Code: /${category}:${skill_name}  |  Claude Code: /${category}-${skill_name}"
    elif [ "${PLATFORM_TYPES[0]}" = "file" ]; then
      echo "  /${category}:${skill_name}"
    else
      echo "  /${category}-${skill_name}"
    fi
  done
done

echo ""
echo "在对应 AI 工具中输入 skill 名称即可使用。"
