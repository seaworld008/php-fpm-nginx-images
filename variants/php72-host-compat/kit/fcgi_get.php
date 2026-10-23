<?php
// Minimal FastCGI GET client: php fcgi_get.php ADDR SCRIPT_FILENAME (ADDR = HOST:PORT or /path/to.sock)
$addr = $argv[1];
$script = $argv[2];
$sock = @stream_socket_client(($addr[0] === '/' ? 'unix://' : 'tcp://') . $addr, $errno, $errstr, 5);
if (!$sock) {
    fwrite(STDERR, "connect $addr failed: $errstr\n");
    exit(2);
}
stream_set_timeout($sock, 20);
function fcgi_record($type, $content)
{
    return pack('CCnnCx', 1, $type, 1, strlen($content), 0) . $content;
}
function fcgi_len($n)
{
    return $n < 128 ? chr($n) : pack('N', $n | 0x80000000);
}
$params = array(
    'GATEWAY_INTERFACE' => 'CGI/1.1', 'REQUEST_METHOD' => 'GET', 'QUERY_STRING' => '',
    'SCRIPT_FILENAME' => $script, 'SCRIPT_NAME' => '/' . basename($script), 'REQUEST_URI' => '/' . basename($script),
    'DOCUMENT_ROOT' => dirname($script), 'SERVER_PROTOCOL' => 'HTTP/1.1', 'SERVER_NAME' => 'localhost',
    'SERVER_PORT' => '80', 'HTTP_HOST' => 'localhost', 'REMOTE_ADDR' => '127.0.0.1',
);
$body = '';
foreach ($params as $k => $v) {
    $body .= fcgi_len(strlen($k)) . fcgi_len(strlen($v)) . $k . $v;
}
fwrite($sock, fcgi_record(1, pack('nCx5', 1, 0)) . fcgi_record(4, $body) . fcgi_record(4, '') . fcgi_record(5, ''));
$out = '';
while (!feof($sock)) {
    $head = stream_get_contents($sock, 8);
    if (strlen($head) < 8) {
        break;
    }
    $r = unpack('Cversion/Ctype/nid/nlen/Cpad/Creserved', $head);
    $content = $r['len'] ? stream_get_contents($sock, $r['len']) : '';
    if ($r['pad']) {
        stream_get_contents($sock, $r['pad']);
    }
    if ($r['type'] == 6) {
        $out .= $content;
    } elseif ($r['type'] == 7) {
        fwrite(STDERR, $content);
    } elseif ($r['type'] == 3) {
        break;
    }
}
$pos = strpos($out, "\r\n\r\n");
echo $pos === false ? $out : substr($out, $pos + 4), "\n";
