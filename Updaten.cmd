@echo off
rem Dubbelklik in een NIEUW gedownloade versie om bij te werken. Je API-sleutel blijft behouden.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Update
echo.
pause
