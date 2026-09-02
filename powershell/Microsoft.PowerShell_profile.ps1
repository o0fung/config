# Cross-platform productivity profile for native Windows PowerShell.
# It deliberately uses built-in commands until optional replacements exist.

$env:Path = "$HOME\.local\bin;$env:Path"

function prompt {
    $success = $?
    $color = if ($success) { 'Green' } else { 'Red' }
    Write-Host "$env:USERNAME@$env:COMPUTERNAME " -ForegroundColor Green -NoNewline
    Write-Host "$(Get-Location) " -ForegroundColor Yellow -NoNewline
    Write-Host ($(if ($success) { '>' } else { '!' }) + ' ') -ForegroundColor $color -NoNewline
    return ' '
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& zoxide init powershell)
}
if (Get-Command direnv -ErrorAction SilentlyContinue) {
    Invoke-Expression (& direnv hook pwsh)
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ll { eza -l --git --git-repos --header --color-scale=all @args }
    function la { eza -la --git --git-repos --header --color-scale=all @args }
    function tree { eza --tree @args }
}
if (Get-Command bat -ErrorAction SilentlyContinue) { Set-Alias -Name cat -Value bat }
if (Get-Command micro -ErrorAction SilentlyContinue) { Set-Alias -Name nano -Value micro }
if (Get-Command python -ErrorAction SilentlyContinue) { Set-Alias -Name py -Value python }

function venv {
    param([string]$Name)
    $venvHome = if ($env:VENV_HOME) { $env:VENV_HOME } else { Join-Path $HOME 'venv' }

    if (-not $Name) {
        if (-not (Test-Path $venvHome)) {
            Write-Host "(no envs in $venvHome)"
            return
        }
        Get-ChildItem -LiteralPath $venvHome -Directory | Select-Object -ExpandProperty Name
        return
    }

    $activate = Join-Path $venvHome "$Name\Scripts\Activate.ps1"
    if (-not (Test-Path $activate)) {
        Write-Error "venv: not found: $activate"
        return
    }
    if (Get-Command deactivate -ErrorAction SilentlyContinue) { deactivate }
    . $activate
}

function ftxt {
    param([string]$Query = '')
    foreach ($tool in @('fzf', 'rg', 'bat', 'cursor')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Write-Error "ftxt requires $tool."
            return
        }
    }

    # Stream ripgrep results through fzf, then separate the selected path and
    # line number before handing Cursor its required path:line syntax.
    $selection = rg --line-number --no-heading --hidden --glob '!.git/*' --smart-case -- $Query |
        fzf --ansi --delimiter ':' --with-nth 3.. --preview 'bat --color=always --style=numbers --highlight-line {2} {1}'
    if ($selection -match '^(.*?):(\d+):') {
        cursor --goto "$($Matches[1]):$($Matches[2])"
    }
}
Set-Alias -Name ft -Value ftxt

function ffile {
    param([string]$Query = '')
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue) -or -not (Get-Command fd -ErrorAction SilentlyContinue)) {
        Write-Error 'ffile requires fzf and fd.'
        return
    }

    $selection = fd --type file --type directory --exclude .git --exclude node_modules --exclude dist --exclude build |
        fzf --prompt 'files> ' --query $Query
    if (-not $selection) { return }

    $item = Get-Item -LiteralPath $selection
    if ($item.PSIsContainer) {
        Set-Location -LiteralPath $item.FullName
        if (Get-Command zoxide -ErrorAction SilentlyContinue) { zoxide add -- $item.FullName }
    }
    else {
        if (Get-Command zoxide -ErrorAction SilentlyContinue) { zoxide add -- $item.DirectoryName }
        Invoke-Item -LiteralPath $item.FullName
    }
}
Set-Alias -Name ff -Value ffile

# Machine-specific commands and environment values belong here, outside Git.
$localProfile = Join-Path $PSScriptRoot 'local.ps1'
if (Test-Path $localProfile) { . $localProfile }
