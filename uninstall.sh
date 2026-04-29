#!/bin/bash
#
# uninstall.sh — 移除 install.sh 创建的 symlink
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"
COMMANDS_DST="$HOME/.claude/commands"

removed=0

for category_dir in "$COMMANDS_SRC"/*/; do
  [ -d "$category_dir" ] || continue

  category=$(basename "$category_dir")
  target="$COMMANDS_DST/$category"

  if [ -L "$target" ]; then
    rm "$target"
    echo "  已移除 $target"
    removed=$((removed + 1))
  elif [ -e "$target" ]; then
    echo "  跳过 $target （不是 symlink，可能是手动创建的）"
  fi
done

echo ""
echo "卸载完成！移除了 $removed 个 symlink。"
