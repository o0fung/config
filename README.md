# Cross-platform dotfiles

Personal command-line defaults for a new development machine:

- macOS and Linux: modular Zsh configuration
- Windows: native PowerShell profile
- all platforms: shared Git aliases and GitHub CLI authentication

This repository never stores a Git identity, password, token, SSH private key,
or a plaintext credential helper.

## Quick start

Clone the repository somewhere permanent, then run the platform installer from
the repository root.

### macOS or Linux

```sh
git clone <your-repository-url> ~/src/config
cd ~/src/config
bash setup.sh
exec zsh
```

The script supports Homebrew, `apt`, `dnf`, and `pacman`. Install a package
manager first if your computer has none. It tries to install optional tools
individually, so an unavailable package does not stop setup. During setup,
enter your Git display name and email if they are not already set globally.
These values identify the author of future commits; they are not GitHub login
credentials.

On macOS, setup refreshes Homebrew's formula metadata, then reports the command
path and Homebrew version for each tool it manages. A tool already available on
your `PATH` is skipped, even if Homebrew has a newer version; use `brew
outdated` and `brew upgrade <formula>` when you want to update it.

Python setup reuses an available Python 3.13 interpreter, `pip`, and `pipx`.
It installs only a missing command and does not create or update a dedicated
Python virtual environment.

The installer also attempts to make Zsh your default login shell. It may ask
for your account password through `chsh`; the password is not stored. Close
and reopen the terminal (or log out and back in) after setup for the change to
take effect. If account policy prevents this step, the final summary provides
the manual fallback:

```sh
chsh -s "$(command -v zsh)"
```

On Debian/Ubuntu, the installer runs `sudo apt-get update` before installing
tools. It does not upgrade unrelated system packages by default. On a new
machine where you explicitly want that update, use:

```sh
bash setup.sh --system-upgrade
```

This runs `sudo apt-get update` followed by `sudo apt-get upgrade -y`; it may
update libraries or the kernel and can require a restart. The option is
accepted but intentionally skipped on macOS and non-apt Linux distributions.
On Windows, `-SystemUpgrade` is likewise reported as skipped because it is an
apt-specific operation.

To preview setup without changing the computer:

```sh
bash setup.sh --dry-run
```

Dry-run prints the package installations, backups, symlinks, and Git
configuration it would perform. It can inspect existing files to describe
what would be replaced, but does not install, move, link, configure Git, or
start GitHub authentication.

### Windows PowerShell

Install Git for Windows and either `winget` (included with current Windows) or
Chocolatey. Then clone the repository and run:

```powershell
git clone <your-repository-url> "$HOME\src\config"
Set-Location "$HOME\src\config"
Set-ExecutionPolicy -Scope Process Bypass -Force
.\setup.ps1
```

The installer prefers a symbolic link for the PowerShell profile. If Windows
disallows it (common when Developer Mode is off), it writes a small loader
profile that sources this repository instead. Both choices receive future
changes from the repository.

## GitHub setup

Use GitHub CLI rather than `credential.helper = store`. First run the base
setup once. Then choose exactly one of the following connection methods.

### HTTPS (recommended)

Run this after the base setup:

```sh
# macOS/Linux
bash setup.sh --skip-packages --github
```

```powershell
# Windows
.\setup.ps1 -SkipPackages -GitHub
```

On the computer where you run setup, GitHub CLI opens a browser. Sign in to
the intended GitHub account and approve the request.

When you run setup over SSH, GitHub CLI prints a one-time code and a URL. On
a computer that has a browser, open that URL, enter the code, and approve
GitHub CLI.

The installer then configures Git to use HTTPS with GitHub CLI and displays
the authenticated account. Prepare no token, password, or GitHub webpage
configuration beforehand.

### SSH (alternative)

Use SSH only if you prefer SSH-form repository URLs such as
`git@github.com:owner/repository.git`. This is an alternative to the HTTPS
command above—do not run both. It performs the same GitHub login, creates
`~/.ssh/id_ed25519` only when no key exists, and uploads its
public key to the authenticated GitHub account:

```sh
bash setup.sh --skip-packages --ssh-key
```

```powershell
.\setup.ps1 -SkipPackages -CreateSshKey
```

No manual SSH-key entry in the GitHub webpage is needed. Review the
`ssh-keygen` passphrase prompt before continuing.

The GitHub login uses the system credential store. On macOS that is Keychain;
on Windows it is Git Credential Manager / Windows Credential Manager; on
Linux GitHub CLI uses its supported secure store or asks for a suitable
fallback. Do not add a `credential.helper = store` setting: it puts tokens in
plaintext on disk.

## Python 3.13, pip, and pipx

Setup reuses a Python 3.13 interpreter already on `PATH`. When none is
present, it uses `uv` to install the latest compatible Python 3.13 release
for the current platform. That interpreter is user-owned and independent of
the operating system Python.

If `pip` is missing, setup installs it for that interpreter. If `pipx` is
missing and `uv` is available, setup runs `uv tool install pipx`. That keeps
`pipx` in its own environment and links the command into `~/.local/bin`,
which is already on the shell path. A uv-managed Python rejects
`pip install --user`. Setup uses that pip command only when `uv` is not
installed.

Verify after restarting the shell:

```sh
python3.13 --version
pipx --version
```

```powershell
python --version
pipx --version
```

Use `uv` for project dependencies. For each project, create an isolated
environment:

```sh
cd path/to/project
uv venv --python 3.13
uv pip install -r requirements.txt
```

On Windows, a newly installed `uv` may not become visible to the current
PowerShell process immediately. If the final summary asks you to restart,
open a new PowerShell window and run `.\setup.ps1 -SkipPackages` once more.

## What is installed

The installers request these productivity tools where their package manager
provides them:

| Tool | Purpose |
| --- | --- |
| `eza` | modern directory listings |
| `bat` | syntax-highlighted file viewing |
| `zoxide` | frecency-based directory jumping |
| `fzf`, `fd`, `ripgrep` | fast fuzzy file/content search |
| `micro` | approachable terminal editor |
| `gh` | GitHub authentication and repository workflows |
| `git-delta` | readable Git diffs |
| `direnv` | project-local environment variables |
| `uv` | Python environments and package management |

`git-delta`, `direnv`, and `uv` are recommendations, not required by the
shell functions. `fzf`, `fd`, `ripgrep`, `bat`, and the Cursor CLI are required
only for the relevant search commands; missing tools show a clear error.

## Shell commands

On Zsh and, where practical, PowerShell:

- `ll`, `la`, `tree`: detailed directory listings through `eza`
- `cat`: `bat` when available
- `py`: the system Python command
- `venv [name]`: list environments under `~/venv`, or activate one
- `ftxt [query]` / `ft`: fuzzy full-text search and open the selected location
  in Cursor
- `ffile [query]` / `ff`: fuzzy file/directory search; enter a directory or
  open a file in the system default application
- `idx`: open the current folder in Chrome as a `file://` listing (Chromium or the default browser on Linux; Zsh only)

`zoxide` supplies the `z` directory-jump command. On Zsh, `cd` becomes `z`
when zoxide is available, while `builtin cd` remains available for exact shell
navigation.

## Git defaults

The installer adds this repository's `.gitconfig` as an include in your global
Git config. It provides concise aliases (`git st`, `git lg`, `git ci`, `git
pl`, `git ph`, `git br`, `git sw`), automatic remote tracking on a first push,
and stale remote-branch pruning.

It deliberately does not include the former `git go` shortcut. That command
staged every changed file, committed the fixed message `ok`, and pushed
immediately, which is unsafe for routine work.

Set your identity during setup, or later:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

For Git servers other than GitHub, configure the platform credential manager
instead of plaintext storage.

## Customization and rollback

- Put machine-specific Zsh values in `~/.zsh/local.zsh`.
- Put machine-specific PowerShell values in `powershell/local.ps1` in your
  local clone. Both paths are ignored by Git.
- Existing Zsh files and PowerShell profiles are backed up under
  `~/.dotfiles-backup/<timestamp>/` before replacement.
- Remove the relevant symlink or PowerShell loader and restore the backup to
  roll back. Remove the Git include with:

```sh
git config --global --unset include.path
```

The prompt color is portable, but terminal-emulator color schemes are not:
macOS Terminal/iTerm2, Linux terminal emulators, and Windows Terminal use
different export formats. Configure the terminal theme separately.
