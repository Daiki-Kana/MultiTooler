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

REM 1.5秒後にブラウザでPCダッシュボードを開く
start "" cmd /c "timeout /t 2 /nobreak > nul & start http://localhost:3000"

REM サーバー起動
node server.js
pause
