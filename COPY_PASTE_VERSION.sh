#!/bin/bash
# ============================================================================
# 复制粘贴版 - 添加到 Jenkins 脚本中
# ============================================================================
# 使用方法：
#   1. 复制下面的 fix_supervisord_config 函数到您的 Jenkins 脚本开头
#   2. 在发布逻辑中 docker_file 之前调用: fix_supervisord_config
#   3. 将 Dockerfile 中的基础镜像改为新版本
# ============================================================================


# ┌────────────────────────────────────────────────────────────────────────┐
# │ 第 1 部分：复制这个函数到脚本开头（变量定义后面）                        │
# └────────────────────────────────────────────────────────────────────────┘

fix_supervisord_config(){
    local config_name="${project_name#jwxt_}"
    local config_path="/data/docker_deploy/jwxt_test-config/${config_name}/supervisord.conf"

    if ssh -p 10015 $destination_IP "[ -f $config_path ]"; then
        echo "🔧 修复 supervisord 配置: $config_path"
        ssh -p 10015 $destination_IP "cp $config_path ${config_path}.bak-\$(date +%Y%m%d-%H%M%S)"
        ssh -p 10015 $destination_IP "sed -i 's/nodaemon=false/nodaemon=true/g' $config_path"
        ssh -p 10015 $destination_IP "sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path"
        echo "✅ 配置修复完成"
    else
        echo "✓ 使用镜像内置配置"
    fi
}


# ┌────────────────────────────────────────────────────────────────────────┐
# │ 第 2 部分：修改 docker_file 函数中的 Dockerfile                          │
# └────────────────────────────────────────────────────────────────────────┘

docker_file(){
# ... 前面的 default.conf 配置保持不变 ...

cat > Dockerfile << 'EOF'
FROM 114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022
COPY --chown=nginx:nginx . /usr/share/nginx/html/
COPY ./default.conf /etc/nginx/conf.d/default.conf
EOF

}


# ┌────────────────────────────────────────────────────────────────────────┐
# │ 第 3 部分：在发布逻辑中调用（在 docker_file 之前）                       │
# └────────────────────────────────────────────────────────────────────────┘

if [ "$deploy_env" == "deploy" ]
then
  create_docker_composefile
  code_compile
  fix_supervisord_config      # ← 添加这一行
  docker_file
  docker_build
  docker_push
  docker_rm_buildimage
  docker_pull
  docker_create_compose
  docker_devlop
  code_auth
  docker_rm_devlopimage
  check_port
else
  docker_rollback
  check_port
  docker_rm_rollbackimage
fi


# ============================================================================
# 完成！现在可以正常发布了
# ============================================================================
#
# 验证方法：
#   docker ps | grep 项目名
#   docker exec 容器名 supervisorctl status
#   docker logs -f 容器名
#
# 应该看到所有进程都是 RUNNING 状态：
#   nginx                            RUNNING
#   php-fpm7                         RUNNING
#   jxgl-copy-recruit-classes:00     RUNNING
#   jxgl-sync-lndx:00                RUNNING
#   jxgl_create_diploma:00           RUNNING
# ============================================================================
