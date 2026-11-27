<#
Skein v2.0.1 技能安装脚本（Windows PowerShell 5.1 / 7）
默认只装全局常驻技能 task-checkpoint、skein-cli 与纯 ASCII CRLF 的 skein-cli.cmd shim；
项目级默认只装 agent-handoff。其余低频技能建议用 skills-manager 按需开关。
#>
[CmdletBinding()]
param(
    [ValidateSet('all','claude','codex','workbuddy','antigravity','qoder-cn','custom')]
    [string]$Client = 'all',
    [string]$Dir,
    [string]$Project,
    [switch]$AllSkills,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$Repo = Split-Path -Parent $PSScriptRoot
$GlobalSkill = 'task-checkpoint'
$ProjectSkills = @('agent-handoff')
if ($AllSkills) { $ProjectSkills += @('skein-init','kb-retrieval','agent-collab') }

function Install-One([string]$dest, [string]$s) {
    $source = Join-Path $Repo "skills\$s"
    $target = Join-Path $dest $s
    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing -and ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        if ($Force) { throw "拒绝用 -Force 拆除符号链接：$target（请通过 skills-manager 管理）" }
        Write-Host "  跳过（符号链接）：$target"
        return
    }
    if ($existing -and (-not $Force)) {
        Write-Host "  跳过（已存在）：$target"
        return
    }
    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
    Write-Host "  已装：$target"
}

$home_ = $env:USERPROFILE
$binDir = Join-Path $home_ '.local\bin'
if (-not (Test-Path -LiteralPath $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
Copy-Item -LiteralPath (Join-Path $Repo 'bin\skein-cli') -Destination (Join-Path $binDir 'skein-cli') -Force

# 生成纯 ASCII + CRLF 的 .cmd shim，避免 Windows cmd.exe 按 GBK 解析 UTF-8 路径乱码
$shimPath = Join-Path $binDir 'skein-cli.cmd'
$shimContent = "@echo off`r`nsetlocal`r`nset `"GIT_BASH=%ProgramFiles%\Git\bin\bash.exe`"`r`nif not exist `"%GIT_BASH%`" set `"GIT_BASH=bash.exe`"`r`n`"%GIT_BASH%`" `"%USERPROFILE%\.local\bin\skein-cli`" %*`r`n"
[System.IO.File]::WriteAllText($shimPath, $shimContent, [System.Text.Encoding]::ASCII)
Write-Host "已装 CLI：$binDir\skein-cli 与 $shimPath"
Write-Host "提示：把 $binDir 加入用户 PATH 即可在 TRAE / PowerShell 终端直接运行裸命令 skein-cli。"

Write-Host "== 安装全局常驻技能（$GlobalSkill）=="
$map = @{
    claude      = Join-Path $home_ '.claude\skills'
    codex       = Join-Path $home_ '.codex\skills'
    workbuddy   = Join-Path $home_ '.workbuddy\skills'
    antigravity = Join-Path $home_ '.agents\skills'
    'qoder-cn'  = Join-Path $home_ '.qoder-cn\skills'
}
if ($Client -eq 'all') {
    foreach ($k in $map.Keys) { Install-One $map[$k] $GlobalSkill }
} elseif ($Client -eq 'custom') {
    if (-not $Dir) { throw '-Client custom 必须同时给 -Dir' }
    Install-One $Dir $GlobalSkill
} else {
    Install-One $map[$Client] $GlobalSkill
}

if ($Project) {
    if (-not (Test-Path -LiteralPath $Project)) { throw "项目目录不存在：$Project" }
    $Proj = (Resolve-Path -LiteralPath $Project).Path
    Write-Host "== 安装项目级技能 =="
    $pMap = @{ claude='.claude'; codex='.codex'; workbuddy='.workbuddy'; antigravity='.agents'; 'qoder-cn'='.qoder-cn' }
    $targets = if ($Client -eq 'all') { $pMap.Values } elseif ($pMap.ContainsKey($Client)) { @($pMap[$Client]) } else { @() }
    foreach ($c in $targets) {
        $dest = Join-Path $Proj "$c\skills"
        foreach ($s in $ProjectSkills) { Install-One $dest $s }
    }
}

Write-Host "`n安装完成。重启客户端生效；建库时请通过 skills-manager 临时挂载 skein-init。"
