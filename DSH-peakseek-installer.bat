@echo off
setlocal EnableExtensions
title DSH-peakseek Installer

rem Put this file beside the existing deepseek-harness folder and run it.
rem Example:
rem   E:\DSH\DSH-peakseek-installer.bat
rem   E:\DSH\deepseek-harness\

set "DSH_DIR=%~dp0deepseek-harness"
set "PATCH_FILE=%~dp0dsh-peakseek.patch"
set "PATCH_URL=https://github.com/ROOOOOYczx/DSH-peakseek/releases/latest/download/dsh-peakseek.patch"

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

rem Re-running the script is safe: an installed plugin only needs rebuilding.
if exist "%DSH_DIR%\packages\client\ui-peak-pricing\package.json" goto :build

rem Do not overwrite unrelated uncommitted changes in the existing DSH.
for /f "delims=" %%A in ('git -C "%DSH_DIR%" status --porcelain') do set "DSH_DIRTY=1"
if defined DSH_DIRTY (
    echo [错误] DSH 目录存在未提交修改，请先备份或提交后再运行。
    goto :failed
)

if not exist "%PATCH_FILE%" (
    set "PATCH_FILE=%TEMP%\dsh-peakseek-%RANDOM%.patch"
    echo 正在下载插件补丁...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%PATCH_URL%' -OutFile '%PATCH_FILE%'"
    if errorlevel 1 (
        echo [错误] 插件补丁下载失败。
        goto :failed
    )
)

echo 正在修补现有 DSH...
git -C "%DSH_DIR%" apply --3way --whitespace=nowarn "%PATCH_FILE%"
if errorlevel 1 (
    echo [错误] 补丁无法应用，可能是 DSH 版本不兼容。
    goto :failed
)

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
