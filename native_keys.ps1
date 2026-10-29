# ==============================================================================
# WebSlideSwitch - 高信頼キーストローク & スリープ抑止エンジン
# user32.dll keybd_event によるマルチツール操作 ＋ kernel32.dll PCスリープ防止
# ==============================================================================

$code = @"
using System;
using System.Runtime.InteropServices;

public class NativeKeys {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern uint MapVirtualKey(uint uCode, uint uMapType);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);

    public const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    // スリープ抑止用フラグ (Win32 API)
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;

    public static void PreventSleep() {
        SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
    }

    public static void AllowSleep() {
        SetThreadExecutionState(ES_CONTINUOUS);
    }

    public static void Press(byte vk, bool isExtended = true) {
        byte scan = (byte)MapVirtualKey((uint)vk, 0);
        uint flags = isExtended ? KEYEVENTF_EXTENDEDKEY : 0;
        keybd_event(vk, scan, flags, UIntPtr.Zero);
        System.Threading.Thread.Sleep(35);
        keybd_event(vk, scan, flags | KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
    [DllImport("user32.dll", SetLastError = true)]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    public const uint MOUSEEVENTF_MOVE      = 0x0001;
    public const uint MOUSEEVENTF_LEFTDOWN  = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP    = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP   = 0x0010;
    public const uint MOUSEEVENTF_WHEEL     = 0x0800;

    public static void MouseMove(int dx, int dy) {
        mouse_event(MOUSEEVENTF_MOVE, dx, dy, 0, UIntPtr.Zero);
    }

    public static void MouseLeftClick() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void MouseRightClick() {
        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(15);
        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void MouseLeftDown() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
    }

    public static void MouseLeftUp() {
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
    }

    public static void MouseScroll(int delta) {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta, UIntPtr.Zero);
    }

    public static void Copy() {
        keybd_event(0x11, 0, 0, UIntPtr.Zero); // VK_CONTROL
        keybd_event(0x43, 0, 0, UIntPtr.Zero); // VK_C
        System.Threading.Thread.Sleep(30);
        keybd_event(0x43, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        keybd_event(0x11, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public uint type;
        public InputUnion u;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_UNICODE = 0x0004;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    // Unicode文字（日本語漢字・ひらがな・英文・記号）を直接アクティブウィンドウへ送信
    public static void SendText(string text) {
        if (string.IsNullOrEmpty(text)) return;
        int inputSize = Marshal.SizeOf(typeof(INPUT));
        foreach (char c in text) {
            if (c == '\r') continue;
            if (c == '\n') {
                Press(0x0D, false); // VK_RETURN (改行)
                continue;
            }
            INPUT[] inputs = new INPUT[2];
            inputs[0].type = INPUT_KEYBOARD;
            inputs[0].u.ki.wVk = 0;
            inputs[0].u.ki.wScan = (ushort)c;
            inputs[0].u.ki.dwFlags = KEYEVENTF_UNICODE;
            inputs[0].u.ki.time = 0;
            inputs[0].u.ki.dwExtraInfo = UIntPtr.Zero;

            inputs[1].type = INPUT_KEYBOARD;
            inputs[1].u.ki.wVk = 0;
            inputs[1].u.ki.wScan = (ushort)c;
            inputs[1].u.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
            inputs[1].u.ki.time = 0;
            inputs[1].u.ki.dwExtraInfo = UIntPtr.Zero;

            SendInput(2, inputs, inputSize);
            System.Threading.Thread.Sleep(6);
        }
    }

    public const uint CF_UNICODETEXT = 13;
    public const uint GMEM_MOVEABLE = 0x0002;
    public const uint GMEM_ZEROINIT = 0x0040;
    public const uint GHND = 0x0042; // GMEM_MOVEABLE | GMEM_ZEROINIT

    public static void Paste() {
        // VK_CONTROL: 0x11, VK_V: 0x56
        byte scanCtrl = (byte)MapVirtualKey(0x11, 0);
        byte scanV = (byte)MapVirtualKey(0x56, 0);

        keybd_event(0x11, scanCtrl, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(40);
        keybd_event(0x56, scanV, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        keybd_event(0x56, scanV, KEYEVENTF_KEYUP, UIntPtr.Zero);
        System.Threading.Thread.Sleep(40);
        keybd_event(0x11, scanCtrl, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool OpenClipboard(IntPtr hWndNewOwner);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseClipboard();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool EmptyClipboard();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SetClipboardData(uint uFormat, IntPtr hMem);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GlobalAlloc(uint uFlags, UIntPtr dwBytes);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GlobalLock(IntPtr hMem);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GlobalUnlock(IntPtr hMem);

    public static bool SetClipboardText(string text) {
        if (text == null) return false;
        for (int i = 0; i < 5; i++) {
            if (OpenClipboard(IntPtr.Zero)) {
                try {
                    EmptyClipboard();
                    int bytes = (text.Length + 1) * 2;
                    IntPtr hMem = GlobalAlloc(GHND, (UIntPtr)bytes);
                    if (hMem != IntPtr.Zero) {
                        IntPtr pMem = GlobalLock(hMem);
                        if (pMem != IntPtr.Zero) {
                            Marshal.Copy(text.ToCharArray(), 0, pMem, text.Length);
                            Marshal.WriteInt16(pMem, text.Length * 2, 0);
                            GlobalUnlock(hMem);
                            SetClipboardData(CF_UNICODETEXT, hMem);
                        }
                    }
                    return true;
                } finally {
                    CloseClipboard();
                }
            }
            System.Threading.Thread.Sleep(25);
        }
        return false;
    }

    public static bool InjectText(string text) {
        if (string.IsNullOrEmpty(text)) return false;
        bool ok = SetClipboardText(text);
        if (ok) {
            System.Threading.Thread.Sleep(60);
            Paste();
            return true;
        } else {
            SendText(text);
            return true;
        }
    }
}
"@

Add-Type -TypeDefinition $code -Language CSharp
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# エンジン起動時にPCの自動スリープ・画面消灯を自動抑止
[NativeKeys]::PreventSleep()
Write-Output "NATIVE_KEY_ENGINE_READY"

try {
    while ($null -ne ($line = [Console]::ReadLine())) {
        $line = $line.Trim()
        if ($line -eq "QUIT") { break }

        # --- 1. スライド操作 ---
        if ($line -eq "NEXT") {
            # 右矢印キー (0x27)
            [NativeKeys]::Press(0x27)
            Write-Output "OK"
        } elseif ($line -eq "PREV") {
            # 左矢印キー (0x25)
            [NativeKeys]::Press(0x25)
            Write-Output "OK"
        } elseif ($line -eq "FIRST") {
            # Homeキー (0x24) - 最初のスライド
            [NativeKeys]::Press(0x24)
            Write-Output "OK"
        } elseif ($line -eq "LAST") {
            # Endキー (0x23) - 最後のスライド
            [NativeKeys]::Press(0x23)
            Write-Output "OK"
        } elseif ($line -eq "BLACK") {
            # Bキー (0x42)
            [NativeKeys]::Press(0x42, $false)
            Write-Output "OK"
        } elseif ($line -eq "WHITE") {
            # Wキー (0x57)
            [NativeKeys]::Press(0x57, $false)
            Write-Output "OK"
        } elseif ($line -eq "POINTER") {
            # Lキー (0x4C) - Googleスライドのレーザーポインター切り替え
            [NativeKeys]::Press(0x4C, $false)
            Write-Output "OK"

        # --- 2. メディア・音量操作 ---
        } elseif ($line -eq "VOL_UP") {
            # 音量アップ (0xAF)
            [NativeKeys]::Press(0xAF)
            Write-Output "OK"
        } elseif ($line -eq "VOL_DOWN") {
            # 音量ダウン (0xAE)
            [NativeKeys]::Press(0xAE)
            Write-Output "OK"
        } elseif ($line -eq "VOL_MUTE") {
            # 消音 / ミュート (0xAD)
            [NativeKeys]::Press(0xAD)
            Write-Output "OK"
        } elseif ($line -eq "PLAY_PAUSE") {
            # スペースキー (0x20) - 動画・スライド再生/停止
            [NativeKeys]::Press(0x20, $false)
            Write-Output "OK"

        # --- 3. プレゼン制御ショートカット ---
        } elseif ($line -eq "START_SLIDESHOW") {
            # F5キー (0x74) - スライドショー開始
            [NativeKeys]::Press(0x74, $false)
            Write-Output "OK"
        } elseif ($line -eq "EXIT_SLIDESHOW") {
            # Escキー (0x1B) - スライドショー終了
            [NativeKeys]::Press(0x1B, $false)
            Write-Output "OK"

        # --- 4. 電源管理制御 ---
        } elseif ($line -eq "PREVENT_SLEEP") {
            [NativeKeys]::PreventSleep()
            Write-Output "SLEEP_PREVENTED"
        } elseif ($line -eq "ALLOW_SLEEP") {
            [NativeKeys]::AllowSleep()
            Write-Output "SLEEP_ALLOWED"

        # --- 5. トラックパッド & マウス操作 ---
        } elseif ($line.StartsWith("MOUSE_MOVE ")) {
            $parts = $line.Split(" ")
            if ($parts.Length -ge 3) {
                [int]$dx = [int]$parts[1]
                [int]$dy = [int]$parts[2]
                [NativeKeys]::MouseMove($dx, $dy)
            }
        } elseif ($line -eq "MOUSE_CLICK_LEFT") {
            [NativeKeys]::MouseLeftClick()
            Write-Output "OK"
        } elseif ($line -eq "MOUSE_CLICK_RIGHT") {
            [NativeKeys]::MouseRightClick()
            Write-Output "OK"
        } elseif ($line -eq "MOUSE_DRAG_START") {
            [NativeKeys]::MouseLeftDown()
            Write-Output "OK"
        } elseif ($line -eq "MOUSE_DRAG_END") {
            [NativeKeys]::MouseLeftUp()
            Write-Output "OK"
        } elseif ($line.StartsWith("MOUSE_SCROLL ")) {
            $parts = $line.Split(" ")
            if ($parts.Length -ge 2) {
                [int]$delta = [int]$parts[1]
                [NativeKeys]::MouseScroll($delta)
            }
        } elseif ($line -eq "CMD_COPY") {
            [NativeKeys]::Copy()
            Write-Output "OK"
        } elseif ($line -eq "CMD_PASTE") {
            [NativeKeys]::Paste()
            Write-Output "OK"

        # --- 6. 遠隔キーボード・文字入力操作 ---
        } elseif ($line.StartsWith("KEY_TEXT ")) {
            $b64 = $line.Substring(9).Trim()
            if ($b64.Length -gt 0) {
                try {
                    $bytes = [System.Convert]::FromBase64String($b64)
                    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
                    $res = [NativeKeys]::InjectText($text)
                    Write-Output "OK_TEXT: $($text.Length) chars '$text' injected (res=$res)"
                } catch {
                    Write-Output "ERR_TEXT: $($_.Exception.Message)"
                }
            } else {
                Write-Output "ERR_TEXT: empty_payload"
            }
        } elseif ($line.StartsWith("KEY_SPECIAL ")) {
            $key = $line.Substring(12).Trim()
            if ($key -eq "ENTER") { [NativeKeys]::Press(0x0D, $false); Write-Output "OK" }
            elseif ($key -eq "BACKSPACE") { [NativeKeys]::Press(0x08, $false); Write-Output "OK" }
            elseif ($key -eq "TAB") { [NativeKeys]::Press(0x09, $false); Write-Output "OK" }
            elseif ($key -eq "ESCAPE") { [NativeKeys]::Press(0x1B, $false); Write-Output "OK" }
            elseif ($key -eq "SPACE") { [NativeKeys]::Press(0x20, $false); Write-Output "OK" }
            elseif ($key -eq "UP") { [NativeKeys]::Press(0x26, $true); Write-Output "OK" }
            elseif ($key -eq "DOWN") { [NativeKeys]::Press(0x28, $true); Write-Output "OK" }
            elseif ($key -eq "LEFT") { [NativeKeys]::Press(0x25, $true); Write-Output "OK" }
            elseif ($key -eq "RIGHT") { [NativeKeys]::Press(0x27, $true); Write-Output "OK" }
        }
    }
} finally {
    # 終了時は安全に通常省電力状態へ戻す
    [NativeKeys]::AllowSleep()
}
