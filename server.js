// ==============================================================================
// WebSlideSwitch - プレゼンコントローラー サーバー (Native API & Cloudflare Tunnel版 v1.1)
// Win32低レベルAPI・Unicodeクリップボード注入 & 物理キーストローク送信
// ==============================================================================

const http = require('http');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');
const express = require('express');
const { WebSocketServer } = require('ws');
const QRCode = require('qrcode');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

const PORT = process.env.PORT || 3000;

// PINコード認証は無効化（即時接続・操作許可）

// ------------------------------------------------------------------------------
// 1. Windows Native キーストローク送信管理 (user32.dll keybd_event)
// ------------------------------------------------------------------------------
let psProcess = null;
let isKeyEngineReady = false;

// 仮想キーコード (Virtual Key Codes)
const KEY_CODES = {
  next: '0x27',  // VK_RIGHT (右矢印キー -> Googleスライド「進む」)
  prev: '0x25',  // VK_LEFT  (左矢印キー -> Googleスライド「戻る」)
  black: '0x42', // VK_B     (Bキー -> プレゼン暗転)
  white: '0x57'  // VK_W     (Wキー -> プレゼン白転)
};

function initNativeKeyEngine() {
  const scriptPath = path.join(__dirname, 'native_keys.ps1');

  try {
    psProcess = spawn('powershell', [
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', scriptPath
    ], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    psProcess.stdout.on('data', (data) => {
      const output = data.toString().trim();
      if (output.includes('NATIVE_KEY_ENGINE_READY')) {
        isKeyEngineReady = true;
        console.log('[NativeKey] Windows Nativeキーストロークエンジン & PC画面スリープ防止が準備完了しました');
      } else if (output.startsWith('OK_TEXT')) {
        console.log(`[NativeKey] 貼り付け注入完了: ${output}`);
      }
    });

    psProcess.stderr.on('data', (data) => {
      console.error(`[NativeKey Error]: ${data.toString()}`);
    });

    psProcess.on('exit', (code) => {
      console.warn(`[NativeKey] プロセス終了 (code: ${code})。再起動します...`);
      isKeyEngineReady = false;
      setTimeout(initNativeKeyEngine, 1000);
    });
  } catch (err) {
    console.error('[NativeKey] 起動失敗:', err);
  }
}

// プロセス終了時にPowerShell子プロセスを確実に終了
process.on('exit', () => {
  if (psProcess) {
    try { psProcess.stdin.write("QUIT\n"); psProcess.kill(); } catch (e) {}
  }
});
process.on('SIGINT', () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));

// キー送信実行関数
function sendNativeKey(action) {
  const cmd = action.toUpperCase();

  if (!psProcess || !psProcess.stdin.writable) {
    console.warn('[NativeKey] プロセス再起動中...');
    initNativeKeyEngine();
    return false;
  }

  try {
    psProcess.stdin.write(`${cmd}\n`);
    console.log(`[NativeKey] キー送信実行: ${cmd}`);
    return true;
  } catch (err) {
    console.error(`[NativeKey] 送信失敗:`, err);
    return false;
  }
}

// 低レイテンシ マウス・コマンド送信関数
function sendNativeMouse(cmd) {
  if (!psProcess || !psProcess.stdin.writable) {
    initNativeKeyEngine();
    return false;
  }
  try {
    psProcess.stdin.write(`${cmd}\n`);
    return true;
  } catch (err) {
    return false;
  }
}

// 初期化実行
initNativeKeyEngine();

// ------------------------------------------------------------------------------
// 2. Cloudflare Tunnel 自動連携
// ------------------------------------------------------------------------------
let cloudflaredProcess = null;
let currentTunnelUrl = '';

function startCloudflareTunnel() {
  const exePath = path.join(__dirname, 'cloudflared.exe');

  try {
    console.log('[Cloudflare] クイックトンネルを起動しています...');
    cloudflaredProcess = spawn(exePath, [
      'tunnel',
      '--url',
      `http://localhost:${PORT}`
    ]);

    cloudflaredProcess.stderr.on('data', (data) => {
      const text = data.toString();
      const match = text.match(/https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/);
      if (match && !currentTunnelUrl) {
        currentTunnelUrl = match[0];
        console.log('================================================================');
        console.log(`  [Cloudflare] トンネルURLが正常に発行されました:`);
        console.log(`  👉 ${currentTunnelUrl}/remote`);
        console.log('================================================================');
      }
    });

    cloudflaredProcess.on('exit', (code) => {
      console.warn(`[Cloudflare] トンネルが終了しました (code: ${code})。再接続を試みます...`);
      currentTunnelUrl = '';
      setTimeout(startCloudflareTunnel, 4000);
    });

    cloudflaredProcess.on('error', (err) => {
      console.error('[Cloudflare] プロセスエラー:', err.message);
    });
  } catch (err) {
    console.error('[Cloudflare] 起動エラー:', err.message);
  }
}

startCloudflareTunnel();

// ------------------------------------------------------------------------------
// 3. ネットワーク情報
// ------------------------------------------------------------------------------
function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];

  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push({
          name,
          address: net.address,
          isWifi: /wi-?fi|wlan|wireless/i.test(name)
        });
      }
    }
  }

  addresses.sort((a, b) => (b.isWifi ? 1 : 0) - (a.isWifi ? 1 : 0));
  return addresses;
}

function getPrimaryIp() {
  const ips = getLocalIpAddresses();
  return ips.length > 0 ? ips[0].address : 'localhost';
}

// ------------------------------------------------------------------------------
// CORS許可（Cloudflare Pages等の外部ホストからのAPI・情報取得を許可）
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

app.use(express.static(path.join(__dirname, 'public')));

// スマホ・PC共通の単一アプリを提供 (/remote へのアクセスも同一アプリへ)
app.get('/remote', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/info', async (req, res) => {
  try {
    const primaryIp = getPrimaryIp();
    const allIps = getLocalIpAddresses();
    // 単一Webアプリの共通ルートURL
    const localRemoteUrl = `http://${primaryIp}:${PORT}/`;
    const tunnelRemoteUrl = currentTunnelUrl ? `${currentTunnelUrl}/` : '';

    const localQrDataUrl = await QRCode.toDataURL(localRemoteUrl, {
      margin: 2,
      width: 260,
      color: { dark: '#181818', light: '#ffffff' }
    });

    let tunnelQrDataUrl = '';
    if (tunnelRemoteUrl) {
      tunnelQrDataUrl = await QRCode.toDataURL(tunnelRemoteUrl, {
        margin: 2,
        width: 260,
        color: { dark: '#181818', light: '#ffffff' }
      });
    }

    res.json({
      port: PORT,
      primaryIp,
      allIps,
      localRemoteUrl,
      localQrDataUrl,
      tunnelRemoteUrl,
      tunnelQrDataUrl,
      hasTunnel: !!currentTunnelUrl,
      connectedClients: wss.clients.size,
      sleepPrevention: isKeyEngineReady
    });
  } catch (err) {
    res.status(500).json({ error: '接続情報の生成に失敗しました' });
  }
});

// PINコード再生成API（無効化・互換ダミー）
app.post('/api/regenerate-pin', (req, res) => {
  res.json({ success: true });
});

// ------------------------------------------------------------------------------
// 5. WebSocket通信によるリモコン操作ハンドリング
// ------------------------------------------------------------------------------
const clients = new Map();

function broadcastStatus() {
  let mobileCount = 0;
  let pcCount = 0;

  for (const info of clients.values()) {
    if (info.type === 'mobile') mobileCount++;
    if (info.type === 'pc') pcCount++;
  }

  const payload = JSON.stringify({
    type: 'status_update',
    mobileCount,
    pcCount,
    totalCount: clients.size,
    timestamp: Date.now()
  });

  for (const client of wss.clients) {
    if (client.readyState === client.OPEN) {
      client.send(payload);
    }
  }
}

wss.on('connection', (ws, req) => {
  const clientInfo = {
    type: 'unknown',
    ip: req.headers['cf-connecting-ip'] || req.headers['x-forwarded-for'] || req.socket.remoteAddress,
    connectedAt: Date.now(),
    authenticated: true // PIN認証無効化のため常時認証済み
  };
  clients.set(ws, clientInfo);

  broadcastStatus();

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());

      if (data.type === 'register') {
        clientInfo.type = data.clientType || 'unknown';
        clientInfo.authenticated = true;
        clients.set(ws, clientInfo);
        ws.send(JSON.stringify({ type: 'auth_success' }));
        console.log(`[WebSocket] クライアント接続: ${clientInfo.type} (${clientInfo.ip})`);
        broadcastStatus();
        return;
      }

      // PINコード認証要求（互換性のため即時成功を返却）
      if (data.type === 'auth') {
        clientInfo.authenticated = true;
        ws.send(JSON.stringify({ type: 'auth_success' }));
        return;
      }

      if (data.type === 'mouse_move') {
        const dx = Math.round(data.dx);
        const dy = Math.round(data.dy);
        if (dx !== 0 || dy !== 0) {
          sendNativeMouse(`MOUSE_MOVE ${dx} ${dy}`);
        }
        return;
      }

      if (data.type === 'mouse_click') {
        if (data.button === 'right') sendNativeMouse('MOUSE_CLICK_RIGHT');
        else sendNativeMouse('MOUSE_CLICK_LEFT');
        return;
      }

      if (data.type === 'mouse_drag') {
        if (data.state === 'start') sendNativeMouse('MOUSE_DRAG_START');
        else sendNativeMouse('MOUSE_DRAG_END');
        return;
      }

      if (data.type === 'mouse_scroll') {
        sendNativeMouse(`MOUSE_SCROLL ${Math.round(data.delta)}`);
        return;
      }

      if (data.type === 'clipboard') {
        if (data.action === 'copy') sendNativeMouse('CMD_COPY');
        else if (data.action === 'paste') sendNativeMouse('CMD_PASTE');
        return;
      }

      if (data.type === 'keyboard_text') {
        const text = String(data.text || '');
        if (text) {
          const b64 = Buffer.from(text, 'utf-8').toString('base64');
          console.log(`[Keyboard] テキスト入力送信: "${text}"`);
          sendNativeMouse(`KEY_TEXT ${b64}`);
        }
        return;
      }

      if (data.type === 'keyboard_key') {
        const key = String(data.key || '').toUpperCase();
        if (key) {
          console.log(`[Keyboard] 特殊キー送信: ${key}`);
          sendNativeMouse(`KEY_SPECIAL ${key}`);
        }
        return;
      }

      if (data.type === 'command') {
        const action = data.action;
        let success = false;

        if (action === 'copy') {
          success = sendNativeMouse('CMD_COPY');
        } else if (action === 'paste') {
          success = sendNativeMouse('CMD_PASTE');
        } else if (action === 'drag_start') {
          success = sendNativeMouse('MOUSE_DRAG_START');
        } else if (action === 'drag_end') {
          success = sendNativeMouse('MOUSE_DRAG_END');
        } else {
          success = sendNativeKey(action);
        }

        let actionLabel = '';
        if (action === 'next') actionLabel = 'Next Slide';
        else if (action === 'prev') actionLabel = 'Previous Slide';
        else if (action === 'first') actionLabel = 'First Slide [Home]';
        else if (action === 'last') actionLabel = 'Last Slide [End]';
        else if (action === 'black') actionLabel = 'Blank Screen (Black)';
        else if (action === 'white') actionLabel = 'Blank Screen (White)';
        else if (action === 'pointer') actionLabel = 'Laser Pointer [L]';
        else if (action === 'vol_up') actionLabel = 'Volume Up';
        else if (action === 'vol_down') actionLabel = 'Volume Down';
        else if (action === 'vol_mute') actionLabel = 'Volume Mute';
        else if (action === 'play_pause') actionLabel = 'Play / Pause [Space]';
        else if (action === 'start_slideshow') actionLabel = 'Start Slideshow [F5]';
        else if (action === 'exit_slideshow') actionLabel = 'Exit Slideshow [Esc]';

        const logPayload = JSON.stringify({
          type: 'action_log',
          action,
          actionLabel,
          success,
          timestamp: Date.now(),
          clientIp: clientInfo.ip
        });

        for (const [socket, info] of clients.entries()) {
          if (socket.readyState === socket.OPEN && info.type === 'pc') {
            socket.send(logPayload);
          }
        }

        if (ws.readyState === ws.OPEN) {
          ws.send(JSON.stringify({
            type: 'command_ack',
            action,
            success,
            timestamp: Date.now()
          }));
        }
      }
    } catch (err) {
      console.error('[WebSocket] メッセージ解析エラー:', err);
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
    console.log(`[WebSocket] クライアント切断 (${clientInfo.type})`);
    broadcastStatus();
  });

  ws.on('error', (err) => {
    console.error('[WebSocket] エラー:', err);
  });
});

process.on('SIGINT', () => {
  if (psProcess) psProcess.kill();
  if (cloudflaredProcess) cloudflaredProcess.kill();
  process.exit();
});

process.on('exit', () => {
  if (psProcess) psProcess.kill();
  if (cloudflaredProcess) cloudflaredProcess.kill();
});

// ------------------------------------------------------------------------------
// 6. サーバーリッスン開始
// ------------------------------------------------------------------------------
server.listen(PORT, '0.0.0.0', () => {
  const primaryIp = getPrimaryIp();
  console.log('================================================================');
  console.log(`  WebSlideSwitch サーバーが起動しました`);
  console.log(`  ローカル アプリ:  http://localhost:${PORT}`);
  console.log(`  ネットワークURL:  http://${primaryIp}:${PORT}/`);
  console.log('================================================================');
});
