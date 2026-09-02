# VSCode settings installer for Windows
# Usage:
#   .\Install-VSCodeSettings.ps1                     # 設定ファイルのみ配置
#   .\Install-VSCodeSettings.ps1 -InstallExtensions  # 拡張機能もインストール
#   .\Install-VSCodeSettings.ps1 -Export             # 現在の環境を管理元へ書き戻す

param(
    [switch]$InstallExtensions,
    [switch]$Export
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$UserDir         = Join-Path $env:APPDATA "Code\User"
$SettingsSource  = Join-Path $ScriptDir "settings.json"
$KeybindsSource  = Join-Path $ScriptDir "keybindings.json"
$ExtensionsList  = Join-Path $ScriptDir "extensions.txt"
$SettingsDest    = Join-Path $UserDir "settings.json"
$KeybindsDest    = Join-Path $UserDir "keybindings.json"
$Stamp           = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "VSCode settings installer" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# code CLI の解決（PATH 優先、無ければ既定の導入先を探す）
function Resolve-CodeCli {
    # PATH 上の code は拡張子なしのシェルスクリプトが引っかかることがあるため、
    # .cmd / .exe に限定し、実ファイルとして存在するものだけを採用する。
    $fromPath = Get-Command code -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -match '\.(cmd|exe)$' -and (Test-Path -LiteralPath $_.Source -PathType Leaf) } |
        Select-Object -First 1
    if ($fromPath) { return $fromPath.Source }

    $roots = @(
        $env:ProgramFiles,
        [Environment]::GetEnvironmentVariable("ProgramFiles(x86)"),
        (Join-Path $env:LOCALAPPDATA "Programs")
    )
    $candidates = $roots |
        Where-Object { $_ } |
        ForEach-Object { Join-Path $_ "Microsoft VS Code\bin\code.cmd" }
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    return $null
}

# --- Export モード: 現在の環境を管理元へ書き戻す ------------------------
if ($Export) {
    Write-Host "Exporting current VSCode configuration..." -ForegroundColor Green

    foreach ($pair in @(
        @{ From = $SettingsDest; To = $SettingsSource; Name = "settings.json" },
        @{ From = $KeybindsDest; To = $KeybindsSource; Name = "keybindings.json" }
    )) {
        if (Test-Path $pair.From) {
            Copy-Item $pair.From $pair.To -Force
            Write-Host "  - $($pair.Name)" -ForegroundColor Gray
        }
        else {
            Write-Host "  - $($pair.Name) (存在しないためスキップ)" -ForegroundColor DarkGray
        }
    }

    $codeCli = Resolve-CodeCli
    if ($codeCli) {
        $installed = & $codeCli --list-extensions
        $exportPath = Join-Path $ScriptDir "extensions.installed.txt"
        $installed | Set-Content $exportPath -Encoding UTF8
        Write-Host "  - extensions.installed.txt ($($installed.Count) 件)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "extensions.txt との差分を確認して手動で反映してください。" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Export completed." -ForegroundColor Cyan
    return
}

# --- Install モード ------------------------------------------------------
if (-not (Test-Path $UserDir)) {
    Write-Host "VSCode のユーザーディレクトリが見つかりません: $UserDir" -ForegroundColor Red
    Write-Host "VSCode を一度起動してから再実行してください。" -ForegroundColor Red
    exit 1
}

Write-Host "Installing configuration files..." -ForegroundColor Green
foreach ($pair in @(
    @{ Source = $SettingsSource; Dest = $SettingsDest; Name = "settings.json" },
    @{ Source = $KeybindsSource; Dest = $KeybindsDest; Name = "keybindings.json" }
)) {
    if (-not (Test-Path $pair.Source)) {
        Write-Host "  - $($pair.Name) (管理元に存在しないためスキップ)" -ForegroundColor DarkGray
        continue
    }

    # 既存ファイルはタイムスタンプ付きでバックアップ
    if (Test-Path $pair.Dest) {
        $backup = "$($pair.Dest).backup.$Stamp"
        Copy-Item $pair.Dest $backup -Force
        Write-Host "  - $($pair.Name) をバックアップ: $(Split-Path -Leaf $backup)" -ForegroundColor Yellow
    }

    Copy-Item $pair.Source $pair.Dest -Force
    Write-Host "  - $($pair.Name)" -ForegroundColor Gray
}

# --- 拡張機能 ------------------------------------------------------------
if ($InstallExtensions) {
    Write-Host ""
    Write-Host "Installing extensions..." -ForegroundColor Green

    $codeCli = Resolve-CodeCli
    if (-not $codeCli) {
        Write-Host "  code CLI が見つかりません。拡張機能のインストールをスキップします。" -ForegroundColor Red
    }
    elseif (-not (Test-Path $ExtensionsList)) {
        Write-Host "  extensions.txt が見つかりません。スキップします。" -ForegroundColor Red
    }
    else {
        $installed = @(& $codeCli --list-extensions)
        $wanted = Get-Content $ExtensionsList |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith("#") }

        $added = 0
        $skipped = 0
        foreach ($ext in $wanted) {
            if ($installed -contains $ext) {
                $skipped++
                continue
            }

            Write-Host "  + $ext" -ForegroundColor Gray
            & $codeCli --install-extension $ext --force | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $added++
            }
            else {
                Write-Host "    インストールに失敗しました: $ext" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "  新規 $added 件 / 導入済み $skipped 件" -ForegroundColor Gray
    }
}
else {
    Write-Host ""
    Write-Host "拡張機能もインストールする場合は -InstallExtensions を付けて実行してください。" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Installation completed." -ForegroundColor Cyan
Write-Host "VSCode を再起動すると設定が反映されます。" -ForegroundColor Cyan
