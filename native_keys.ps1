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
}
"@

Add-Type -TypeDefinition $code -Language CSharp
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
        }
    }
} finally {
    # 終了時は安全に通常省電力状態へ戻す
    [NativeKeys]::AllowSleep()
}
