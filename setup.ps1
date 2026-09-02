<#
.SYNOPSIS
Installs the Windows portion of this dotfiles repository.

.DESCRIPTION
Installs optional command-line tools with winget or Chocolatey, backs up an
existing PowerShell profile, links this repository's profile, and includes the
shared non-secret Git configuration. GitHub authentication is opt-in because
the browser/device approval must be completed by the account owner.

.EXAMPLE
Set-ExecutionPolicy -Scope Process Bypass -Force
.\setup.ps1 -GitHub
#>
[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$GitHub,
    [switch]$CreateSshKey,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path -Parent $PSCommandPath
$Done = [System.Collections.Generic.List[string]]::new()
$Skipped = [System.Collections.Generic.List[string]]::new()
$Pending = [System.Collections.Generic.List[string]]::new()

function Add-SetupStatus {
    param(
        [ValidateSet('Done', 'Skipped', 'Pending')][string]$Category,
        [string]$Message
    )
    switch ($Category) {
        'Done' { $Done.Add($Message) }
        'Skipped' { $Skipped.Add($Message) }
        'Pending' { $Pending.Add($Message) }
    }
}

function Show-SetupSummary {
    Write-Host "`nSetup summary"
    Write-Host 'Done:'
    if ($Done.Count) { $Done | ForEach-Object { Write-Host "  - $_" } } else { Write-Host '  - Nothing was changed.' }
    Write-Host 'Skipped:'
    if ($Skipped.Count) { $Skipped | ForEach-Object { Write-Host "  - $_" } } else { Write-Host '  - Nothing.' }
    Write-Host 'Still to do:'
    if ($Pending.Count) { $Pending | ForEach-Object { Write-Host "  - $_" } } else { Write-Host '  - Nothing.' }
}

function Invoke-SetupCommand {
    param([scriptblock]$Command, [string]$Description)

    if ($DryRun) {
        Write-Host "[dry-run] $Description"
        return
    }
    & $Command
}

function Install-Tools {
    $wingetPackages = @(
        'Git.Git', 'GitHub.cli', 'junegunn.fzf', 'BurntSushi.ripgrep.MSVC',
        'sharkdp.fd', 'sharkdp.bat', 'eza-community.eza', 'ajeetdsouza.zoxide',
        'zyedidia.micro', 'dandavison.delta', 'direnv.direnv', 'astral-sh.uv'
    )

    # Each tool is optional. Continue after a single catalog or install failure
    # so a newly provisioned machine still gets the rest of the configuration.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($package in $wingetPackages) {
            try {
                Invoke-SetupCommand { winget install --id $package --exact --accept-package-agreements --accept-source-agreements } "Install $package"
                if (-not $DryRun -and $LASTEXITCODE -ne 0) { throw "winget returned exit code $LASTEXITCODE" }
                if ($DryRun) { Add-SetupStatus Pending "Would install: $package" } else { Add-SetupStatus Done "Installed or already present: $package" }
            }
            catch {
                Write-Warning "Skipped $package: $($_.Exception.Message)"
            }
        }
    }
    elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        $chocoPackages = @('git', 'gh', 'fzf', 'ripgrep', 'fd', 'bat', 'eza', 'zoxide', 'micro', 'delta', 'direnv', 'uv')
        foreach ($package in $chocoPackages) {
            try {
                Invoke-SetupCommand { choco install $package --yes } "Install $package"
                if (-not $DryRun -and $LASTEXITCODE -ne 0) { throw "Chocolatey returned exit code $LASTEXITCODE" }
                if ($DryRun) { Add-SetupStatus Pending "Would install: $package" } else { Add-SetupStatus Done "Installed or already present: $package" }
            }
            catch {
                Write-Warning "Skipped $package: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Warning 'Neither winget nor Chocolatey is available. Install the tools listed in README.md manually.'
        Add-SetupStatus Skipped 'Package installation: no supported package manager'
    }
}

function Install-Profile {
    $profileDirectory = Split-Path -Parent $PROFILE
    $backupDirectory = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $sourceProfile = Join-Path $RepoDir 'powershell\Microsoft.PowerShell_profile.ps1'

    if ((Test-Path -LiteralPath $PROFILE) -and -not ((Get-Item -LiteralPath $PROFILE).LinkType -eq 'SymbolicLink')) {
        Invoke-SetupCommand { New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null } "Create backup directory"
        Invoke-SetupCommand { Move-Item -LiteralPath $PROFILE -Destination $backupDirectory } "Back up existing PowerShell profile"
        Write-Host "Backed up $PROFILE to $backupDirectory"
    }
    Invoke-SetupCommand { New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null } "Create PowerShell profile directory"
    if (Test-Path -LiteralPath $PROFILE) {
        Invoke-SetupCommand { Remove-Item -LiteralPath $PROFILE -Force } "Replace existing profile link"
    }
    try {
        Invoke-SetupCommand { New-Item -ItemType SymbolicLink -Path $PROFILE -Target $sourceProfile | Out-Null } "Link PowerShell profile"
        Write-Host "Linked $PROFILE"
        if ($DryRun) { Add-SetupStatus Pending "Would link: $PROFILE" } else { Add-SetupStatus Done "Linked: $PROFILE" }
    }
    catch {
        # Some Windows installations disallow symlinks without Developer Mode
        # or elevation. A tiny loader preserves live updates from this repo.
        $loader = ". '$($sourceProfile.Replace("'", "''"))'"
        Invoke-SetupCommand { Set-Content -LiteralPath $PROFILE -Value $loader -Encoding utf8 } "Create PowerShell profile loader"
        Write-Warning "Could not create a symbolic link; created a profile loader instead."
        Add-SetupStatus Done "Created profile loader: $PROFILE"
    }
}

function Configure-Git {
    Invoke-SetupCommand { git config --global include.path (Join-Path $RepoDir '.gitconfig') } 'Include shared Git configuration'
    if ($DryRun) {
        Add-SetupStatus Pending 'Would include shared Git configuration'
        Add-SetupStatus Pending 'Git identity not checked during dry run'
        return
    }
    Add-SetupStatus Done 'Included shared Git configuration'
    if (-not (git config --global --get user.name)) {
        $name = Read-Host 'Git display name (leave blank to configure later)'
        if ($name) { git config --global user.name $name }
    }
    if (-not (git config --global --get user.email)) {
        $email = Read-Host 'Git email (leave blank to configure later)'
        if ($email) { git config --global user.email $email }
    }
    if (git config --global --get user.name) { Add-SetupStatus Done 'Git display name is configured' }
    else { Add-SetupStatus Pending 'Set Git display name: git config --global user.name "Your Name"' }
    if (git config --global --get user.email) { Add-SetupStatus Done 'Git email is configured' }
    else { Add-SetupStatus Pending 'Set Git email: git config --global user.email "you@example.com"' }
}

function Connect-GitHub {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning 'GitHub CLI is not installed. Rerun after installing gh.'
        Add-SetupStatus Pending 'Install GitHub CLI, then rerun with -GitHub'
        return
    }
    if ($DryRun) {
        Add-SetupStatus Pending 'Would authenticate GitHub CLI and configure Git HTTPS access'
        if ($CreateSshKey) { Add-SetupStatus Pending 'Would create/upload an SSH key' }
        return
    }
    gh auth status | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Invoke-SetupCommand { gh auth login --git-protocol https --web } 'Open GitHub authentication'
        if (-not $DryRun -and $LASTEXITCODE -ne 0) {
            throw 'GitHub authentication did not complete.'
        }
    }
    Invoke-SetupCommand { gh auth setup-git } 'Configure GitHub HTTPS authentication'
    if ($LASTEXITCODE -ne 0) { throw 'Configuring GitHub HTTPS authentication failed.' }

    if ($CreateSshKey) {
        $key = Join-Path $HOME '.ssh\id_ed25519'
        if (-not (Test-Path $key)) {
            Invoke-SetupCommand { ssh-keygen -t ed25519 -f $key -C (git config --global --get user.email) } 'Create SSH key'
            if ($LASTEXITCODE -ne 0) { throw 'Creating the SSH key failed.' }
        }
        Invoke-SetupCommand { gh ssh-key add "$key.pub" --title "$env:COMPUTERNAME-$(Get-Date -Format 'yyyy-MM-dd')" } 'Upload SSH key to GitHub'
        if ($LASTEXITCODE -ne 0) { throw 'Uploading the SSH key to GitHub failed.' }
        Add-SetupStatus Done 'Uploaded SSH public key to GitHub'
    }
    gh auth status
    if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication status could not be verified.' }
    Add-SetupStatus Done 'Authenticated GitHub CLI and configured Git HTTPS access'
}

if (-not $SkipPackages) { Install-Tools }
else { Add-SetupStatus Skipped 'Package installation requested to be skipped' }
Install-Profile
Configure-Git
if ($GitHub -or $CreateSshKey) { Connect-GitHub }
else { Add-SetupStatus Pending 'Connect GitHub: rerun with -SkipPackages -GitHub or -CreateSshKey' }
Show-SetupSummary
Write-Host "`nRestart PowerShell to load the profile."
