@echo off
setlocal EnableExtensions
title DSH-peakseek Installer

rem Put this file beside the existing deepseek-harness folder and run it.
rem Example:
rem   E:\DSH\DSH-peakseek-installer.bat
rem   E:\DSH\deepseek-harness\

set "DSH_DIR=%~dp0deepseek-harness"
set "PATCH_FILE=%~dp0dsh-peakseek.patch"
set "PLUGIN_ARCHIVE=%~dp0dsh-peakseek-plugin.zip"
set "PATCH_URL=https://github.com/ROOOOOYczx/DSH-peakseek/releases/latest/download/dsh-peakseek.patch"
set "PLUGIN_ARCHIVE_URL=https://github.com/ROOOOOYczx/DSH-peakseek/releases/latest/download/dsh-peakseek-plugin.zip"

rem Make common user-local tool locations available without elevation.
set "PATH=%LOCALAPPDATA%\Programs\nodejs-portable;%LOCALAPPDATA%\pnpm\bin;%PATH%"

echo.
echo DSH-peakseek 一键补丁程序
echo 目标目录：%DSH_DIR%
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Git，请先安装 Git for Windows。
    goto :failed
)

where node >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Node.js，请先安装 Node.js 22 或更高版本。
    goto :failed
)

where pnpm >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 pnpm，请先执行：npm install --global pnpm@11.7.0
    goto :failed
)

if not exist "%DSH_DIR%\package.json" (
    echo [错误] 脚本必须放在 deepseek-harness 文件夹的上一级目录。
    goto :failed
)

if not exist "%DSH_DIR%\.git" (
    echo [错误] 目标 DSH 不是 Git 仓库，无法安全应用补丁。
    goto :failed
)

if exist "%DSH_DIR%\packages\client\ui-peak-pricing\package.json" goto :upgrade

rem Do not overwrite unrelated uncommitted changes in the existing DSH.
for /f "delims=" %%A in ('git -C "%DSH_DIR%" status --porcelain') do set "DSH_DIRTY=1"
if defined DSH_DIRTY (
    echo [错误] DSH 目录存在未提交修改，请先备份或提交后再运行。
    goto :failed
)

if not exist "%PATCH_FILE%" goto :download_patch
goto :apply_patch

:download_patch
set "PATCH_FILE=%TEMP%\dsh-peakseek-%RANDOM%.patch"
echo 正在下载插件补丁...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%PATCH_URL%' -OutFile '%PATCH_FILE%'"
if errorlevel 1 (
    echo [错误] 插件补丁下载失败。
    goto :failed
)

:apply_patch
echo 正在修补现有 DSH...
git -C "%DSH_DIR%" apply --3way --whitespace=nowarn "%PATCH_FILE%"
if errorlevel 1 (
    echo [错误] 补丁无法应用，可能是 DSH 版本不兼容。
    goto :failed
)
goto :prepare

:upgrade
echo 检测到已安装的 DSH-peakseek，正在升级插件文件...
if not exist "%PLUGIN_ARCHIVE%" goto :download_plugin_archive
goto :backup_plugin

:download_plugin_archive
set "PLUGIN_ARCHIVE=%TEMP%\dsh-peakseek-plugin-%RANDOM%%RANDOM%.zip"
echo 正在下载最新插件文件...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%PLUGIN_ARCHIVE_URL%' -OutFile '%PLUGIN_ARCHIVE%'"
if errorlevel 1 (
    echo [错误] 最新插件文件下载失败。
    goto :failed
)

:backup_plugin
set "BACKUP_DIR=%TEMP%\DSH-peakseek-backup-%RANDOM%%RANDOM%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '%DSH_DIR%\packages\client\ui-peak-pricing' -Destination '%BACKUP_DIR%' -Recurse -Force"
if errorlevel 1 (
    echo [错误] 无法备份现有插件文件。
    goto :failed
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%PLUGIN_ARCHIVE%' -DestinationPath '%DSH_DIR%' -Force"
if errorlevel 1 (
    echo [错误] 最新插件文件无法解压到 DSH 目录。
    echo 已有插件备份：%BACKUP_DIR%
    goto :failed
)
echo 已有插件备份：%BACKUP_DIR%

:prepare
echo 正在关闭旧的 DSH Web 进程...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$listeners = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue; foreach ($listener in $listeners) { $processId = $listener.OwningProcess; $process = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $processId) -ErrorAction SilentlyContinue; if ($null -ne $process -and $process.CommandLine -match 'apps[\\/]cli[\\/]src[\\/]bin\.ts.+web') { Stop-Process -Id $processId -Force -ErrorAction Stop; Write-Host ('已停止 DSH Web 进程：' + $processId) } }"
if errorlevel 1 echo [警告] 旧 DSH 进程未能自动关闭；若端口被占用，请手动关闭旧窗口后重试。

:build
echo 正在安装依赖并重新构建 Web UI，这一步可能需要几分钟...
cd /d "%DSH_DIR%"
call pnpm install --frozen-lockfile
if errorlevel 1 goto :failed

call pnpm run build
if errorlevel 1 goto :failed

echo 修补完成，正在启动 DSH Web UI...
if exist "%DSH_DIR%\start-dsh.bat" (
    call "%DSH_DIR%\start-dsh.bat"
) else (
    call pnpm dsh web
)
goto :done

:failed
echo.
echo 修补未完成，请根据上面的提示处理后重新运行。
pause
exit /b 1

:done
endlocal
