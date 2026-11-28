<#
Skein v2.0.5 技能安装脚本（Windows PowerShell 5.1 / 7，UTF-8 带 BOM）
- 默认安装 skein-cli 与纯 ASCII CRLF 的 skein-cli.cmd shim
- -Client all 仅安装到本机已存在配置目录的客户端，不创建未安装客户端目录
- 若用 skills-manager 管理技能，建议直接加 -CliOnly 只装 CLI
#>
[CmdletBinding()]
param(
    [ValidateSet('all','claude','codex','workbuddy','antigravity','qoder-cn','custom')]
    [string]$Client = 'all',
    [string]$Dir,
    [string]$Project,
    [switch]$AllSkills,
    [switch]$CliOnly,
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
    if (-not $existing) {
        Copy-Item -LiteralPath $source -Destination $target -Recurse
    } else {
        $parent = (Get-Item -LiteralPath $dest).FullName
        $sourcePath = (Get-Item -LiteralPath $source).FullName
        if ($existing.FullName -eq $sourcePath -or $existing.FullName.StartsWith($sourcePath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "安装目标与源目录重叠：$target"
        }
        $suffix = [Guid]::NewGuid().ToString('N')
        $stage = Join-Path $parent ".$s.new.$suffix"
        $backup = Join-Path $parent ".$s.old.$suffix"
        foreach ($path in @($existing.FullName, $stage, $backup)) {
            if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path)) -ne $parent) {
                throw "安装目标超出客户端技能目录：$path"
            }
        }
        Copy-Item -LiteralPath $source -Destination $stage -Recurse
        Rename-Item -LiteralPath $existing.FullName -NewName ([IO.Path]::GetFileName($backup))
        try {
            Rename-Item -LiteralPath $stage -NewName $s
        } catch {
            Rename-Item -LiteralPath $backup -NewName $s
            throw
        }
        Remove-Item -LiteralPath $backup -Recurse -Force
    }
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

if ($CliOnly) {
    Write-Host "已按 -CliOnly 跳过技能目录写入。"
    return
}

Write-Host "== 安装全局常驻技能（$GlobalSkill）=="
$clientRoots = [ordered]@{
    claude      = Join-Path $home_ '.claude'
    codex       = Join-Path $home_ '.codex'
    workbuddy   = Join-Path $home_ '.workbuddy'
    antigravity = Join-Path $home_ '.agents'
    'qoder-cn'  = Join-Path $home_ '.qoder-cn'
}
if ($Client -eq 'all') {
    foreach ($k in $clientRoots.Keys) {
        $base = $clientRoots[$k]
        if (Test-Path -LiteralPath $base) {
            Install-One (Join-Path $base 'skills') $GlobalSkill
        } else {
            Write-Host "  跳过（未检测到客户端目录）：$base"
        }
    }
} elseif ($Client -eq 'custom') {
    if (-not $Dir) { throw '-Client custom 必须同时给 -Dir' }
    Install-One $Dir $GlobalSkill
} else {
    Install-One (Join-Path $clientRoots[$Client] 'skills') $GlobalSkill
}

if ($Project) {
    if (-not (Test-Path -LiteralPath $Project)) { throw "项目目录不存在：$Project" }
    $Proj = (Resolve-Path -LiteralPath $Project).Path
    Write-Host "== 安装项目级技能 =="
    $pMap = [ordered]@{ claude='.claude'; codex='.codex'; workbuddy='.workbuddy'; antigravity='.agents'; 'qoder-cn'='.qoder-cn' }
    if ($Client -eq 'all') {
        foreach ($k in $pMap.Keys) {
            if (Test-Path -LiteralPath $clientRoots[$k]) {
                $dest = Join-Path $Proj "$($pMap[$k])\skills"
                foreach ($s in $ProjectSkills) { Install-One $dest $s }
            }
        }
    } elseif ($pMap.Contains($Client)) {
        $dest = Join-Path $Proj "$($pMap[$Client])\skills"
        foreach ($s in $ProjectSkills) { Install-One $dest $s }
    }
}

Write-Host "`n安装完成。重启客户端生效；建库时请通过 skills-manager 临时挂载 skein-init。"
