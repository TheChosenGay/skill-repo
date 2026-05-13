#!/bin/bash
#
# uninstall.sh — 移除 install.sh 创建的所有 symlink
# 支持：Claude Code、CodeBuddy Code、Cursor（自动检测）
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"

TARGETS=()
PLATFORM_NAMES=()
PLATFORM_TYPES=()

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
  echo "未检测到支持的平台，无需卸载。"
  exit 0
fi

total_removed=0

for i in "${!TARGETS[@]}"; do
  COMMANDS_DST="${TARGETS[$i]}"
  platform_name="${PLATFORM_NAMES[$i]}"
  platform_type="${PLATFORM_TYPES[$i]}"
  removed=0

  for category_dir in "$COMMANDS_SRC"/*/; do
    [ -d "$category_dir" ] || continue
    category=$(basename "$category_dir")

    if [ "$platform_type" = "file" ]; then
      # CodeBuddy Code：逐文件移除
      cat_dst="$COMMANDS_DST/$category"
      for skill_file in "$category_dir"*.md; do
        [ -f "$skill_file" ] || continue
        skill_name=$(basename "$skill_file")
        target="$cat_dst/$skill_name"
        if [ -L "$target" ]; then
          rm "$target"
          echo "  [$platform_name] 已移除 $target"
          removed=$((removed + 1))
        fi
      done
      [ -d "$cat_dst" ] && rmdir "$cat_dst" 2>/dev/null || true
    elif [ "$platform_type" = "dir" ]; then
      # Claude Code：移除目录级 symlink
      target="$COMMANDS_DST/$category"
      if [ -L "$target" ]; then
        rm "$target"
        echo "  [$platform_name] 已移除 $target"
        removed=$((removed + 1))
      elif [ -e "$target" ]; then
        echo "  [$platform_name] 跳过 $target （不是 symlink）"
      fi
    else
      # Cursor：移除 .mdc 文件 symlink
      for skill_file in "$category_dir"*.md; do
        [ -f "$skill_file" ] || continue
        skill_name=$(basename "$skill_file" .md)
        mdc_name="${category}-${skill_name}.mdc"
        target="$COMMANDS_DST/$mdc_name"
        if [ -L "$target" ]; then
          rm "$target"
          echo "  [$platform_name] 已移除 $target"
          removed=$((removed + 1))
        elif [ -e "$target" ]; then
          echo "  [$platform_name] 跳过 $target （不是 symlink）"
        fi
      done
    fi
  done

  echo "  [$platform_name] 完成：移除了 $removed 个 symlink"
  total_removed=$((total_removed + removed))
done

echo ""
echo "卸载完成！共移除 $total_removed 个 symlink。"
