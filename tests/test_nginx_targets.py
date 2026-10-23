import unittest

try:
    from tools import nginx_targets as nt
except ImportError:
    nt = None

SAMPLE = """# configuration file /usr/local/nginx/conf/nginx.conf:
http {
    include vhost/*.conf;
    server {
        listen 80 default_server;
        server_name _;
        root html;
    }
}
stream {
    server {
        listen 3307;
        proxy_pass 127.0.0.1:3306;
    }
}

# configuration file /usr/local/nginx/conf/enable-php.conf:
location ~ [^/]\\.php(/|$) {
    fastcgi_pass 127.0.0.1:9000;
    include fastcgi.conf;
}

# configuration file /usr/local/nginx/conf/vhost/a.conf:
server {
    listen 80;
    listen 443 ssl http2;
    server_name a.example.com www.a.example.com;
    root /data/wwwroot/a/public;
    include enable-php.conf;
}

# configuration file /usr/local/nginx/conf/vhost/b.conf:
server {
    listen 443;
    server_name b.example.com;   # same port as a.conf, which enables ssl for the socket
    root /data/wwwroot/b;
    location / { try_files $uri $uri/ /index.html; }
}

# configuration file /usr/local/nginx/conf/vhost/c.conf:
server {
    listen 8182 ssl;
    server_name c.example.com;
    root "/data/c/public";
    location ~ \\.php$ {
        fastcgi_pass 127.0.0.1:9000;
    }
}
"""


class NginxTargetsTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(nt, 'nginx_targets implementation is not present')

    def test_probe_targets_inherit_ssl_per_port(self):
        got = set(nt.probe_targets(SAMPLE))
        self.assertIn(('https', '443', 'b.example.com'), got)
        self.assertIn(('https', '443', 'www.a.example.com'), got)
        self.assertIn(('http', '80', 'a.example.com'), got)
        self.assertIn(('https', '8182', 'c.example.com'), got)
        self.assertIn(('http', '80', '127.0.0.1'), got)

    def test_stream_servers_are_not_http_targets(self):
        self.assertFalse([t for t in nt.probe_targets(SAMPLE) if t[1] == '3307'])

    def test_fcgi_targets_follow_includes_and_nested_locations(self):
        got = list(nt.fcgi_targets(SAMPLE))
        self.assertIn(('a.example.com', '/data/wwwroot/a/public', '/index.php'), got)
        self.assertIn(('c.example.com', '/data/c/public', '/index.php'), got)
        self.assertNotIn('b.example.com', [g[0] for g in got])
        self.assertEqual(len(got), 2)

    def test_comments_do_not_leak_into_directives(self):
        blocks = nt.server_blocks(SAMPLE)
        names = [v for b in blocks for k, v in b if k == 'server_name']
        self.assertIn(['b.example.com'], names)


if __name__ == '__main__':
    unittest.main()
