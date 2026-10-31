@echo off
chcp 65001 > nul
title WebSlideSwitch - プレゼンコントローラー
cd /d "%~dp0"

echo ================================================================
echo   WebSlideSwitch を起動しています...
echo ================================================================

REM 依存関係のチェック
if not exist node_modules (
  echo [Info] 依存パッケージをインストール中...
  call npm install
)

REM サーバー起動（コンソールにスマホ接続用QRコードが直接表示されます）
node server.js
pause
