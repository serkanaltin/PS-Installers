@echo off
chcp 65001 >nul
title BT Hizli Kurulum Merkezi Baslatiliyor...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Baslat-KurulumMerkezi.ps1"
