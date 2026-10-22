#!/bin/bash
# 一键推送和创建 PR
# 使用方法: bash quick-push.sh

set -e

echo "🚀 PHP 7.2.34 CVE 修复方案 - 快速推送"
echo "======================================"
echo ""

# 检查当前分支
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "feature/实际构建方案与验证-20261022" ]; then
    echo "❌ 错误: 当前不在正确的分支上"
    echo "   当前分支: $CURRENT_BRANCH"
    echo "   期望分支: feature/实际构建方案与验证-20261022"
    exit 1
fi

echo "✅ 分支检查通过: $CURRENT_BRANCH"
echo ""

# 检查是否有未提交的更改
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  警告: 有未提交的更改"
    git status -s
    echo ""
    read -p "是否继续推送? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 1
    fi
fi

# 显示将要推送的提交
echo "📝 将要推送的提交:"
echo "=================="
git log --oneline main..HEAD
echo ""

# 显示文件变更统计
echo "📊 文件变更统计:"
echo "================"
git diff --stat main..HEAD
echo ""

# 确认推送
read -p "确认推送到 GitHub? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 1
fi

# 推送到远程
echo ""
echo "🔄 正在推送到 origin/feature/实际构建方案与验证-20261022..."
if git push origin feature/实际构建方案与验证-20261022; then
    echo ""
    echo "✅ 推送成功！"
    echo ""
    echo "📝 下一步: 创建 Pull Request"
    echo "=============================="
    echo ""
    echo "方法 1: 使用浏览器 (推荐)"
    echo "  1. 访问: https://github.com/seaworld008/php-fpm-nginx-images"
    echo "  2. 点击 'Compare & pull request' 按钮"
    echo "  3. 复制 PR_BODY.md 的内容作为 PR 描述"
    echo "  4. 提交 PR"
    echo ""
    echo "方法 2: 使用 GitHub CLI"
    if command -v gh &> /dev/null; then
        echo "  检测到 gh CLI，可以运行:"
        echo "  gh pr create --title 'feat: PHP 7.2.34 CVE 修复完整实施方案' --body-file PR_BODY.md --base main"
        echo ""
        read -p "是否使用 gh CLI 创建 PR? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "🔄 正在创建 PR..."
            if gh pr create --title 'feat: PHP 7.2.34 CVE 修复完整实施方案' --body-file PR_BODY.md --base main; then
                echo ""
                echo "✅ PR 创建成功！"
                echo ""
                echo "📋 查看 PR:"
                gh pr view --web
            else
                echo ""
                echo "❌ PR 创建失败，请使用浏览器手动创建"
            fi
        fi
    else
        echo "  未检测到 gh CLI，请使用浏览器创建 PR"
    fi
    echo ""
    echo "📚 相关文档:"
    echo "  - 实施总结: IMPLEMENTATION_SUMMARY.md"
    echo "  - 部署指南: DEPLOYMENT_GUIDE.md"
    echo "  - 容器文档: docs/11-container-build-实施经验.md"
    echo "  - 本机文档: docs/10-native-repair-实施经验.md"
    echo ""
else
    echo ""
    echo "❌ 推送失败"
    echo ""
    echo "可能的原因:"
    echo "  1. 需要 GitHub 身份验证"
    echo "  2. 网络连接问题"
    echo "  3. 权限不足"
    echo ""
    echo "解决方法:"
    echo "  1. 配置 Personal Access Token:"
    echo "     git push https://<username>@github.com/seaworld008/php-fpm-nginx-images.git feature/实际构建方案与验证-20261022"
    echo ""
    echo "  2. 或使用 SSH:"
    echo "     git remote set-url origin git@github.com:seaworld008/php-fpm-nginx-images.git"
    echo "     git push origin feature/实际构建方案与验证-20261022"
    echo ""
    exit 1
fi
