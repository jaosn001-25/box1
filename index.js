const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec, execSync } = require('child_process');

const PORT = process.env.PORT || 3000;
const workDir = path.join(process.env.HOME || '/root', 'xray');
const base64File = path.join(workDir, 'base64.txt');
const urlFile = path.join(workDir, 'url.txt');
const uuidFile = path.join(workDir, 'uuid');

let configuredUuid = process.env.UUID || process.env.uuid || '';
let ipCache = { ip: null, ts: 0 };

// 启动 start.sh 子进程
fs.chmod("start.sh", 0o777, (err) => {
    if (err) {
        console.error(`[ERROR] start.sh chmod failed: ${err}`);
        return;
    }
    console.log(`[INFO] start.sh empowerment successful, executing...`);
    const child = exec('bash start.sh');
    child.stdout.on('data', (data) => process.stdout.write(data));
    child.stderr.on('data', (data) => process.stderr.write(data));
    child.on('close', (code) => {
        console.log(`[INFO] start.sh process exited with code ${code}`);
        // 尝试更新启动后生成的实际 UUID
        if (fs.existsSync(uuidFile)) {
            configuredUuid = fs.readFileSync(uuidFile, 'utf8').trim();
            console.log(`[INFO] Active subscription UUID: ${configuredUuid}`);
            console.log(`[INFO] Subscription URL: http://<your-domain>:${PORT}/${configuredUuid}`);
        }
    });
});

// HTTP 服务与订阅分发
const server = http.createServer((req, res) => {
    const reqUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = reqUrl.pathname;

    // 1. 根路径伪装站点 (用于健康检查与伪装)
    if (pathname === '/') {
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
<p>If you see this page, the nginx web server is successfully installed and working. Further configuration is required.</p>
<p><em>Thank you for using nginx.</em></p>
</body>
</html>`);
        return;
    }

    // 2. 节点订阅地址：/${uuid}
    const currentUuid = configuredUuid || (fs.existsSync(uuidFile) ? fs.readFileSync(uuidFile, 'utf8').trim() : '');
    if (currentUuid && pathname === `/${currentUuid}`) {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        const wantRaw = reqUrl.searchParams.get('raw') === '1' || reqUrl.searchParams.get('plain') === '1';
        const targetFile = wantRaw ? urlFile : base64File;

        if (fs.existsSync(targetFile)) {
            fs.readFile(targetFile, 'utf8', (err, data) => {
                if (err) {
                    res.end('Error reading subscription file.');
                } else {
                    res.end(data.trim());
                }
            });
        } else if (fs.existsSync(urlFile)) {
            fs.readFile(urlFile, 'utf8', (err, data) => {
                res.end(data.trim());
            });
        } else {
            res.end('Generating nodes, please refresh in 5 seconds...');
        }
        return;
    }

    // 3. IP 查询地址：/${uuid}/ip
    if (currentUuid && pathname === `/${currentUuid}/ip`) {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        const now = Date.now();
        if (ipCache.ip && now - ipCache.ts < 86400000) {
            res.end(ipCache.ip);
        } else {
            try {
                const ip = execSync('curl -s4m5 -k https://icanhazip.com 2>/dev/null || curl -s6m5 -k https://icanhazip.com 2>/dev/null', { timeout: 6000 }).toString().trim();
                ipCache = { ip, ts: now };
                res.end(ip);
            } catch (e) {
                res.end(ipCache.ip || 'unknown');
            }
        }
        return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 Not Found');
});

server.listen(PORT, () => {
    console.log(`[INFO] Web Server is running on port ${PORT}`);
});