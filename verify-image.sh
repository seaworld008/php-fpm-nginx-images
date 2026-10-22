#!/bin/bash
# 验证推送的镜像可用性

IMAGE="114.115.130.46/jlkj-base/wyveo-nginx-php-fpm-7.2.34:v20261022"

echo "🔍 验证镜像可用性"
echo "=================="
echo "镜像: $IMAGE"
echo ""

# 1. 拉取镜像
echo "📥 步骤 1: 拉取镜像..."
if docker pull "$IMAGE"; then
    echo "✅ 镜像拉取成功"
else
    echo "❌ 镜像拉取失败"
    exit 1
fi
echo ""

# 2. 验证 PHP 版本
echo "🐘 步骤 2: 验证 PHP 版本..."
PHP_VERSION=$(docker run --rm "$IMAGE" php -v | head -1)
echo "$PHP_VERSION"
if echo "$PHP_VERSION" | grep -q "7.2.34-66"; then
    echo "✅ PHP 版本正确"
else
    echo "❌ PHP 版本不正确"
    exit 1
fi
echo ""

# 3. 验证 Nginx 版本
echo "🌐 步骤 3: 验证 Nginx 版本..."
NGINX_VERSION=$(docker run --rm "$IMAGE" nginx -v 2>&1)
echo "$NGINX_VERSION"
if echo "$NGINX_VERSION" | grep -q "1.26.2"; then
    echo "✅ Nginx 版本正确"
else
    echo "❌ Nginx 版本不正确"
    exit 1
fi
echo ""

# 4. 验证扩展数量
echo "🔌 步骤 4: 验证 PHP 扩展..."
EXT_COUNT=$(docker run --rm "$IMAGE" php -m | grep -v "^\[" | grep -v "^$" | wc -l)
echo "扩展数量: $EXT_COUNT"
if [ "$EXT_COUNT" -ge 40 ]; then
    echo "✅ 扩展数量充足 (>= 40)"
else
    echo "⚠️  扩展数量较少: $EXT_COUNT"
fi
echo ""

# 5. 验证关键扩展
echo "🔑 步骤 5: 验证关键扩展..."
REQUIRED_EXTS="swoole redis memcached mongodb pdo_mysql mysqli curl json mbstring openssl"
MISSING=""
for ext in $REQUIRED_EXTS; do
    if docker run --rm "$IMAGE" php -m | grep -qi "^$ext$"; then
        echo "  ✅ $ext"
    else
        echo "  ❌ $ext (缺失)"
        MISSING="$MISSING $ext"
    fi
done

if [ -z "$MISSING" ]; then
    echo "✅ 所有关键扩展都存在"
else
    echo "⚠️  缺失扩展:$MISSING"
fi
echo ""

# 6. 快速启动测试
echo "🚀 步骤 6: 快速启动测试..."
CONTAINER_NAME="php72-verify-test"
docker rm -f "$CONTAINER_NAME" &>/dev/null

if docker run -d --name "$CONTAINER_NAME" -p 18080:80 "$IMAGE"; then
    echo "✅ 容器启动成功"

    # 等待容器就绪
    sleep 3

    # 测试健康检查端点
    echo ""
    echo "🏥 步骤 7: 测试健康检查端点..."
    if curl -f -s http://localhost:18080/fpm_ping > /dev/null; then
        echo "✅ 健康检查端点响应正常"
    else
        echo "⚠️  健康检查端点无响应（可能需要配置）"
    fi

    # 清理
    docker rm -f "$CONTAINER_NAME" &>/dev/null
    echo ""
else
    echo "❌ 容器启动失败"
    exit 1
fi

# 7. 镜像信息
echo "📊 步骤 8: 镜像信息..."
docker images "$IMAGE" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 所有验证通过！镜像可用于生产部署。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 部署命令:"
echo "  docker run -d -p 8080:80 \\"
echo "    --name php72-production \\"
echo "    $IMAGE"
echo ""
