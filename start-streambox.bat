@echo off
cd /d "%~dp0"
title StreamBox
if not exist node_modules call npm install
call npm run build
start "" cmd /c "timeout /t 3 /nobreak >nul & start http://localhost:3001"
node server/index.js
pause
