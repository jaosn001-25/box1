const os = require('os');
const http = require('http');
const fs = require('fs');
const net = require('net');
const { exec, execSync } = require('child_process');
function ensureModule(name) {
    try {
        require.resolve(name);
    } catch (e) {
        console.log(`Module '${name}' not found. Installing...`);
        execSync(`npm install ${name}`, { stdio: 'inherit' });
    }
}
const { WebSocket, createWebSocketStream } = require('ws');
const subtxt = `${process.env.HOME}/agsbx/jh.txt`;
const NAME = process.env.NAME || os.hostname();
const PORT = process.env.PORT || 3000;
const uuid = process.env.uuid || '79411d85-b0dc-4cd2-b46c-01789a18c650';
let ipCache = { ip: null, ts: 0 };
const DOMAIN = process.env.DOMAIN || 'YOUR.DOMAIN';
const vlessInfo = `vless://${uuid}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&fp=chrome&type=ws&host=${DOMAIN}&path=%2F#Vl-ws-tls-${NAME}`;
console.log(`vless-ws-tls节点分享: ${vlessInfo}`);

fs.chmod("start.sh", 0o777, (err) => {
    if (err) {
        console.error(`start.sh empowerment failed: ${err}`);
        return;
    }
    console.log(`start.sh empowerment successful`);
    const child = exec('bash start.sh');
    child.stdout.on('data', (data) => console.log(data));
    child.stderr.on('data', (data) => console.error(data));
    child.on('close', (code) => {
        console.log(`child process exited with code ${code}`);
        if (code === 0) {
            console.log(`Proxy startup script completed`);
        } else {
            console.error(`Proxy startup failed; check the errors above`);
        }
    });
});

const server = http.createServer((req, res) => {
    if (req.url === '/') {
        res.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8',
            'Server': 'nginx/1.27.4'
        });
        res.end(`<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto; font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>`);
        return;
    }

    if (req.url === `/${uuid}`) {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        if (fs.existsSync(subtxt)) {
            fs.readFile(subtxt, 'utf8', (err, data) => {
                if (err) {
                    console.error(err);
                    res.end(`${vlessInfo}`);
                } else {
                    res.end(`${vlessInfo}\n${data}`);
                }
            });
        } else {
            res.end(`${vlessInfo}`);
        }
        return;
    }

    if (req.url === `/${uuid}/ip`) {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        const now = Date.now();
        if (ipCache.ip && now - ipCache.ts < 86400000) {
            res.end(ipCache.ip);
        } else {
            try {
                const ip = execSync('curl -s4m5 -k https://icanhazip.com 2>/dev/null', { timeout: 6000 }).toString().trim();
                ipCache = { ip, ts: now };
                res.end(ip);
            } catch (e) {
                res.end(ipCache.ip || 'error');
            }
        }
        return;
    }


    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 Not Found');
});

server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

const wss = new (require('ws').Server)({ server });
const uuidkey = uuid.replace(/-/g, "");
wss.on('connection', ws => {
    ws.once('message', msg => {
        const [VERSION] = msg;
        const id = msg.slice(1, 17);
        if (!id.every((v, i) => v == parseInt(uuidkey.substr(i * 2, 2), 16))) return;
        let i = msg.slice(17, 18).readUInt8() + 19;
        const port = msg.slice(i, i += 2).readUInt16BE(0);
        const ATYP = msg.slice(i, i += 1).readUInt8();
        const host = ATYP == 1 ? msg.slice(i, i += 4).join('.') :
            (ATYP == 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg.slice(i, i + 1).readUInt8())) :
                (ATYP == 3 ? msg.slice(i, i += 16)
                    .reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), [])
                    .map(b => b.readUInt16BE(0).toString(16)).join(':') : ''));
        ws.send(new Uint8Array([VERSION, 0]));
        const duplex = createWebSocketStream(ws);
        net.connect({ host, port }, function () {
            this.write(msg.slice(i));
            duplex.on('error', () => { }).pipe(this).on('error', () => { }).pipe(duplex);
        }).on('error', () => { });
    }).on('error', () => { });
});
