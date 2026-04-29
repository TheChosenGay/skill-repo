#!/bin/bash
#
# install.sh — 将 skill-repo 中的 commands 安装到 ~/.claude/commands/
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_SRC="$SCRIPT_DIR/commands"
COMMANDS_DST="$HOME/.claude/commands"

if [ ! -d "$COMMANDS_SRC" ]; then
  echo "错误：找不到 commands 目录: $COMMANDS_SRC"
  exit 1
fi

mkdir -p "$COMMANDS_DST"

installed=0
skipped=0

for category_dir in "$COMMANDS_SRC"/*/; do
  [ -d "$category_dir" ] || continue

  category=$(basename "$category_dir")
  target="$COMMANDS_DST/$category"

  if [ -e "$target" ]; then
    if [ -L "$target" ]; then
      existing_link=$(readlink "$target")
      if [ "$existing_link" = "$category_dir" ] || [ "$existing_link" = "${category_dir%/}" ]; then
        echo "  跳过 $category/ （已安装，指向相同位置）"
        skipped=$((skipped + 1))
        continue
      fi
    fi

    echo -n "  $target 已存在，是否覆盖？[y/N] "
    read -r answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
      echo "  跳过 $category/"
      skipped=$((skipped + 1))
      continue
    fi
    rm -rf "$target"
  fi

  ln -s "${category_dir%/}" "$target"
  echo "  已安装 $category/ → $target"
  installed=$((installed + 1))
done

echo ""
echo "安装完成！已安装 $installed 个分类，跳过 $skipped 个。"
echo ""
echo "已安装的 skills："

for category_dir in "$COMMANDS_SRC"/*/; do
  [ -d "$category_dir" ] || continue
  category=$(basename "$category_dir")
  for skill_file in "$category_dir"*.md; do
    [ -f "$skill_file" ] || continue
    skill_name=$(basename "$skill_file" .md)
    echo "  /${category}-${skill_name}"
  done
done

echo ""
echo "在 Claude Code 中输入 skill 名称即可使用。"
