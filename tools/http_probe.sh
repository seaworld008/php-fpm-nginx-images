#!/bin/bash
# 逐个请求域名，记录状态码、大小、内容类型和跳转地址，供 tools/probe_compare.py 对比变更前后的结果。
# 输入（标准输入）：scheme<TAB>port<TAB>host，可由 tools/nginx_targets.py --probe 生成
# 输出：scheme port host path code size content_type redirect（制表符分隔）
# 每个目标请求两个路径：/ 和一个不存在的地址（检验伪静态、try_files 和 404 处理）。
# 请求都发到本机（--resolve 到 127.0.0.1），只读 GET，不带 Cookie。
PATHS=${PROBE_PATHS:-"/ /__nginx_upgrade_check__.html"}
while IFS=$'\t' read -r scheme port host; do
  [ -n "$scheme" ] || continue
  for path in $PATHS; do
    if [ "$host" = 127.0.0.1 ]; then R=""; else R="--resolve $host:$port:127.0.0.1"; fi
    out=$(curl -s -k -o /dev/null -m 15 $R -A 'nginx-upgrade-check/1.0' \
      -w '%{http_code}\t%{size_download}\t%{content_type}\t%{redirect_url}' "$scheme://$host:$port$path" 2>/dev/null)
    printf '%s\t%s\t%s\t%s\t%s\n' "$scheme" "$port" "$host" "$path" "${out:-000}"
  done
done
