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


# nginx started with "-p /application/nginx/ -c conf/nginx.conf": roots are relative to the prefix
PREFIXED = """# configuration file /application/nginx/conf/nginx.conf:
http {
    include vhost/*.conf;
}

# configuration file /application/nginx/conf/vhost/app.conf:
server {
    listen 80;
    server_name app.example.com 10.0.0.5;
    location / {
        root   html/app/public/;
    }
    location ~ \\.php(.*)$ {
        root   html/app/public;
        fastcgi_pass 127.0.0.1:9000;
    }
}
"""


class NginxTargetsTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(nt, 'nginx_targets implementation is not present')

    def test_relative_roots_are_resolved_against_prefix(self):
        self.assertEqual(nt.fcgi_targets(PREFIXED), [])
        self.assertEqual(nt.fcgi_targets(PREFIXED, prefix='/application/nginx/'),
                         [('app.example.com', '/application/nginx/html/app/public', '/index.php')])
        self.assertIn(('a.example.com', '/data/wwwroot/a/public', '/index.php'),
                      nt.fcgi_targets(SAMPLE, prefix='/usr/local/nginx/'))

    def test_cli_accepts_prefix(self):
        import contextlib, io, os, tempfile
        with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False) as fh:
            fh.write(PREFIXED)
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                self.assertEqual(nt.main(['--fcgi', '--prefix', '/application/nginx', fh.name]), 0)
        finally:
            os.unlink(fh.name)
        self.assertEqual(out.getvalue(), 'app.example.com\t/application/nginx/html/app/public\t/index.php\n')

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
