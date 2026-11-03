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

REM 既存の古いWebSlideSwitchプロセスがあれば通知
netstat -ano | findstr :3000 | findstr LISTENING > nul
if %errorlevel% equ 0 (
  echo [Notice] ポート3000が使用中です。既存のnodeプロセスを終了してから再起動してください。
)

echo [Info] サーバーを起動し、ブラウザを開きます...
REM サーバー起動
node server.js
pause
