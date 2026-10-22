#!/bin/bash
# supervisord 配置修复脚本
# 用途：修复外部 supervisord.conf 以兼容新的 PHP 7.2.34-66 镜像
# 使用：在 Jenkins 构建脚本中，docker_build 之前调用此函数

fix_supervisord_config(){
    echo "================================"
    echo "开始修复 supervisord 配置..."
    echo "================================"

    # 检查是否存在 supervisord.conf 配置文件
    local config_path="/data/docker_deploy/jwxt_test-config/${project_name##*_}/supervisord.conf"

    if ssh -p 10015 $destination_IP "[ -f $config_path ]"; then
        echo "✓ 发现配置文件: $config_path"

        # 备份原配置
        echo "→ 备份原配置..."
        ssh -p 10015 $destination_IP "cp $config_path ${config_path}.backup-\$(date +%Y%m%d-%H%M%S)"

        # 修复 1: 将 nodaemon=false 改为 nodaemon=true (容器中必须前台运行)
        echo "→ 修复 1: 设置 nodaemon=true..."
        ssh -p 10015 $destination_IP "sed -i 's/nodaemon=false/nodaemon=true/g' $config_path"

        # 修复 2: 删除不兼容的 eventlistener:stdout 配置
        echo "→ 修复 2: 删除 eventlistener:stdout..."
        ssh -p 10015 $destination_IP "sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path"

        # 修复 3: 确保日志输出到 stdout/stderr (可选，提高日志可见性)
        echo "→ 修复 3: 优化日志配置..."
        ssh -p 10015 $destination_IP "sed -i 's|logfile=/tmp/supervisord.log|logfile=/dev/stdout|g' $config_path"
        ssh -p 10015 $destination_IP "sed -i 's|logfile_maxbytes=50MB|logfile_maxbytes=0|g' $config_path"

        echo "✓ supervisord 配置修复完成"
        echo "✓ 备份文件: ${config_path}.backup-*"
    else
        echo "✓ 未发现自定义配置文件，将使用镜像内置配置"
    fi

    echo "================================"
}

# 如果直接执行脚本（非 source 引入），则显示使用说明
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║       supervisord 配置修复脚本 - 使用说明                            ║
╚══════════════════════════════════════════════════════════════════════╝

用途：
  修复外部 supervisord.conf 配置，使其兼容新的 PHP 7.2.34-66 镜像

修复内容：
  1. 将 nodaemon=false 改为 nodaemon=true (容器中必须前台运行)
  2. 删除不兼容的 [eventlistener:stdout] 配置
  3. 优化日志输出到 stdout/stderr

使用方法 1 - 在 Jenkins 脚本中添加：
──────────────────────────────────────────────────────────────────────

# 在发布脚本开头添加函数定义
fix_supervisord_config(){
    local config_path="/data/docker_deploy/jwxt_test-config/${project_name##*_}/supervisord.conf"

    if ssh -p 10015 $destination_IP "[ -f $config_path ]"; then
        echo "✓ 修复 supervisord 配置: $config_path"
        ssh -p 10015 $destination_IP "cp $config_path ${config_path}.bak-\$(date +%Y%m%d-%H%M%S)"
        ssh -p 10015 $destination_IP "sed -i 's/nodaemon=false/nodaemon=true/g' $config_path"
        ssh -p 10015 $destination_IP "sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path"
        echo "✓ 配置修复完成"
    else
        echo "✓ 使用镜像内置配置"
    fi
}

# 在发布逻辑中调用（在 docker_build 之前）
if [ "$deploy_env" == "deploy" ]
then
  create_docker_composefile
  code_compile
  fix_supervisord_config    # ← 在这里调用
  docker_file
  docker_build
  docker_push
  # ... 其他步骤
fi


使用方法 2 - 手动修复单个项目：
──────────────────────────────────────────────────────────────────────

ssh -p 10015 目标服务器IP << 'ENDSSH'
config_path="/data/docker_deploy/jwxt_test-config/项目名/supervisord.conf"
cp $config_path ${config_path}.backup
sed -i 's/nodaemon=false/nodaemon=true/g' $config_path
sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path
echo "修复完成"
ENDSSH


使用方法 3 - 批量修复所有项目：
──────────────────────────────────────────────────────────────────────

ssh -p 10015 目标服务器IP << 'ENDSSH'
for conf in /data/docker_deploy/jwxt_test-config/*/supervisord.conf; do
    if [ -f "$conf" ]; then
        echo "修复: $conf"
        cp "$conf" "${conf}.backup-$(date +%Y%m%d-%H%M%S)"
        sed -i 's/nodaemon=false/nodaemon=true/g' "$conf"
        sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' "$conf"
    fi
done
echo "所有项目配置修复完成"
ENDSSH


注意事项：
──────────────────────────────────────────────────────────────────────
  ✓ 此脚本会自动备份原配置文件
  ✓ 仅修复必要的配置项，保留所有业务 Worker 配置
  ✓ 如果没有外部配置文件，将自动使用镜像内置配置
  ✓ 适用于所有使用外部 supervisord.conf 的项目

验证方法：
──────────────────────────────────────────────────────────────────────
  docker exec 容器名 supervisorctl status
  # 应该看到所有进程都是 RUNNING 状态

╚══════════════════════════════════════════════════════════════════════╝
EOF
fi
