#!/bin/bash
# ============================================================================
# Jenkins PHP 项目发布脚本 - 适配 PHP 7.2.34-66 新镜像
# ============================================================================
# 使用说明：
#   1. 将基础镜像从旧版本改为: 114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022
#   2. 添加 fix_supervisord_config 函数到脚本开头
#   3. 在发布逻辑中，docker_file 之前调用 fix_supervisord_config
# ============================================================================

#环境归属：
workflow=test
#发布的目标服务器IP地址：
destination_IP=172.18.151.165
#服务端口：
svc_port=8083
#代码项目名称：
project_name=jwxt_gaungxi_lndx
#项目路径：
project_path=/data/docker_deploy/$project_name
#harbor仓库项目名称：
harbor_pname=jlkj-$workflow
#定义一个构建时间(用它来代替版本号)：
time=$(date +%Y-%m-%d_%H%M%S)


# ============================================================================
# 新增：supervisord 配置修复函数
# ============================================================================
fix_supervisord_config(){
    echo "========================================"
    echo "🔧 开始修复 supervisord 配置..."
    echo "========================================"

    # 根据项目名提取配置路径（例如：jwxt_gaungxi_lndx → guangxi_lndx）
    local config_name="${project_name#jwxt_}"
    local config_path="/data/docker_deploy/jwxt_test-config/${config_name}/supervisord.conf"

    echo "→ 项目名称: $project_name"
    echo "→ 配置路径: $config_path"

    # 检查配置文件是否存在
    if ssh -p 10015 $destination_IP "[ -f $config_path ]"; then
        echo "✓ 发现自定义配置文件"

        # 备份原配置（带时间戳）
        echo "→ 备份原配置..."
        ssh -p 10015 $destination_IP "cp $config_path ${config_path}.backup-\$(date +%Y%m%d-%H%M%S)"

        # 修复 1: nodaemon 必须为 true (容器中必须前台运行)
        echo "→ [修复 1/3] 设置 nodaemon=true..."
        ssh -p 10015 $destination_IP "sed -i 's/nodaemon=false/nodaemon=true/g' $config_path"

        # 修复 2: 删除不兼容的 eventlistener:stdout
        echo "→ [修复 2/3] 删除 eventlistener:stdout..."
        ssh -p 10015 $destination_IP "sed -i '/^\[eventlistener:stdout\]/,/^result_handler.*event_handler/d' $config_path"

        # 修复 3: 优化日志输出（可选）
        echo "→ [修复 3/3] 优化日志配置..."
        ssh -p 10015 $destination_IP "sed -i 's|logfile=/tmp/supervisord.log|logfile=/dev/stdout|g' $config_path"
        ssh -p 10015 $destination_IP "sed -i 's|logfile_maxbytes=50MB|logfile_maxbytes=0|g' $config_path"

        echo "✅ supervisord 配置修复完成"
        echo "✅ 备份文件: ${config_path}.backup-*"
    else
        echo "✓ 未发现自定义配置文件"
        echo "✓ 将使用镜像内置配置 (PHP-FPM + Nginx)"
        echo "✓ 如需添加 Worker 进程，请创建配置文件: $config_path"
    fi

    echo "========================================"
    echo ""
}


# 1、创建docker-compose的发布文件
create_docker_composefile(){
#提前判断目录是否存在：
[ -d $project_path ] && echo '目录存在不用创建' || mkdir -p $project_path

cat > $project_path/docker-compose-$project_name.yml << 'EOF'
version: '3.0'
services:
  project_name:
    image: 172.18.151.153:9080/harbor_pname/project_name:$git_version
    container_name: project_name
    restart: always
    ports:
      - 8083:80
    environment:
      TZ: Asia/Shanghai
    volumes:
      - /data/docker_deploy/jwxt_test-config/guangxi_lndx/supervisord.conf:/etc/supervisord.conf
      - /data/file_service/nginx_logs/workflow_project_name:/usr/share/nginx/logs
      - /data/docker_deploy/project_name/workflow_project_name/runtime:/usr/share/nginx/html/runtime
      - /data/docker_deploy/project_name/workflow_project_name/uploads:/usr/share/nginx/html/public/uploads
EOF

#替换docker-compose里面的项目名称
sed -i "s#project_name#$project_name#g" $project_path/docker-compose-$project_name.yml
sed -i "s#harbor_pname#$harbor_pname#g" $project_path/docker-compose-$project_name.yml
sed -i "s#workflow#$workflow#g" $project_path/docker-compose-$project_name.yml
}


# 2.代码编译&打包
code_compile(){
    source /etc/profile
    /data/php/bin/php composer.phar install
}


# 3.编写Dockerfile
docker_file(){
cat > default.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root   /usr/share/nginx/html/public;
    index  index.php index.html index.htm;
    client_max_body_size 50m;

    # reduce the data that needs to be sent over network
    gzip on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml application/json text/javascript application/x-javascript application/xml;
    gzip_disable "MSIE [1-6]\.";

    location / {
        if (!-e $request_filename) {
            rewrite ^(.*)$ /index.php?s=$1 last;
            break;
        }
    }

    location ~ .+\.php($|/) {
        root   /usr/share/nginx/html/public;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 30d;
        access_log off;
    }

    location ~ .*\.(js|css)?$ {
        expires 7d;
        access_log off;
    }

    location ~ /\.(ht|git|vscode|idea) {
        deny all;
    }
}
EOF

cat > Dockerfile << 'EOF'
# ============================================================================
# 使用新的 PHP 7.2.34-66 安全修复镜像
# ============================================================================
FROM 114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022

# 复制应用代码
COPY --chown=nginx:nginx . /usr/share/nginx/html/

# 复制 Nginx 配置
COPY ./default.conf /etc/nginx/conf.d/default.conf

# ============================================================================
# 镜像信息：
#   - PHP: 7.2.34-66+0~20261021.122+debian12~1.gbpe0bcd4 (Debian 12 Sury)
#   - Nginx: 1.26.2
#   - 扩展: 43 个 (含 Swoole 4.8.13)
#   - CVE 修复: CVE-2026-109618, CVE-2026-109619
#   - 镜像摘要: sha256:38092ea491c07d10aa980cd9d3f53ebf1da52cdfdeef1bcc4207f938106c73f2
# ============================================================================
EOF

}


# 4.构建镜像
docker_build(){
    docker build --no-cache -t 172.18.151.153:9080/$harbor_pname/$project_name:$time .
}


# 5.推送镜像
docker_push(){
    docker push 172.18.151.153:9080/$harbor_pname/$project_name:$time
}


# 6.清理本地构建的镜像
docker_rm_buildimage(){
    docker rmi 172.18.151.153:9080/$harbor_pname/$project_name:$time
}


# 7.开发服务器远程拉取镜像
docker_pull(){
    ssh -p 10015 $destination_IP "docker pull 172.18.151.153:9080/$harbor_pname/$project_name:$time"
}


# 8.开发服务器创建docker-compose文件
docker_create_compose(){
    #提前判断目录是否存在：
    ssh -p 10015 $destination_IP "[ -d $project_path/ ] && echo '目录存在不用创建' || mkdir -p $project_path"

    #把docker-compose文件发送到开发服务器上的文件夹里
    scp -P 10015 $project_path/docker-compose-$project_name.yml root@$destination_IP:$project_path/
}


# 9、配置环境变量并启动容器
docker_devlop(){
    #备份旧的版本号
    ssh -p 10015 $destination_IP "[ -f $project_path/.env ] && (cat $project_path/.env > $project_path/.oldenv) || echo '第一次请创建'"
    #把新的版本号追加到文件里
    ssh -p 10015 $destination_IP "echo git_version=$time > $project_path/.env"
    #以新的版本启动容器
    ssh -p 10015 $destination_IP "cd $project_path && docker-compose -f docker-compose-$project_name.yml down && docker-compose -f docker-compose-$project_name.yml up -d "
}


# 10、发布完成后清理旧版本镜像
docker_rm_devlopimage(){
    ssh -p 10015 $destination_IP "[ -f $project_path/.oldenv ] && docker rmi 172.18.151.153:9080/$harbor_pname/$project_name:\$(awk -F= '{print \$2}' $project_path/.oldenv) || echo '第一次发布不用清理'"
}


# 11.回滚容器
docker_rollback(){
    #把回滚前版本号追加到文件里
    ssh -p 10015 $destination_IP "cat $project_path/.env > $project_path/.rollbackenv"
    #把备份的老版本号追加到文件里
    ssh -p 10015 $destination_IP "cat $project_path/.oldenv > $project_path/.env"
    #启动老版本的容器
    ssh -p 10015 $destination_IP "cd $project_path && docker-compose -f docker-compose-$project_name.yml down && docker-compose -f docker-compose-$project_name.yml up -d "
}


# 12、回滚完成后清理旧版本镜像
docker_rm_rollbackimage(){
    ssh -p 10015 $destination_IP "[ -f $project_path/.oldenv ] && docker rmi 172.18.151.153:9080/$harbor_pname/$project_name:\$(awk -F= '{print \$2}' $project_path/.rollbackenv) || echo '第一次发布不用清理'"
}


# 13、检查端口查看是否发布成功和服务启动的时间
check_port(){
ssh -Tq -p 10015 $destination_IP << EOF
count=0
while ((count <= 60))
do
    netstat -lntup |grep $svc_port
    if [ \$? == 0 ];then
        echo "服务启动时间为：\$count 秒"
        break
    fi
    ((count++))
    sleep 1
done
EOF
}


# 14、给代码目录授权
code_auth(){
    ssh -p 10015 $destination_IP "chown -R www:www $project_path"
}


# ============================================================================
# 发布逻辑 - 注意调用顺序
# ============================================================================
if [ "$deploy_env" == "deploy" ]
then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🚀 开始发布项目: $project_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  create_docker_composefile
  code_compile
  fix_supervisord_config      # ✅ 关键：在构建前修复配置
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

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ 项目发布完成: $project_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "↩️  开始回滚项目: $project_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  docker_rollback
  check_port
  docker_rm_rollbackimage

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ 项目回滚完成: $project_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
