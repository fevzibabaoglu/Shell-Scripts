<#
.SYNOPSIS
    Automates the creation and setup of a Python project from a new Git repository.

.DESCRIPTION
    This script clones a remote Git repository, sets up a standard Python project structure,
    creates license files, .gitignore, and initial source files with headers. It also
    initializes a Python virtual environment, installs setuptools, creates two Git commits,
    and pushes a 'main' and 'dev' branch to the remote.

.PARAMETER SshCloneUrl
    The SSH URL of the Git repository to clone (e.g., git@github.com:user/repo.git).

.PARAMETER Author
    The name of the author to be included in the license headers.

.PARAMETER ProjectDescription
    A brief description of the project to be included in the license headers.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SshCloneUrl,

    [Parameter(Mandatory = $true)]
    [string]$Author,

    [Parameter(Mandatory = $true)]
    [string]$ProjectDescription
)


# --- Configuration ---
$Year           = Get-Date -Format "yyyy"
$GitIgnoreUrl   = "https://raw.githubusercontent.com/github/gitignore/refs/heads/main/Python.gitignore"
$GplUrl         = "https://www.gnu.org/licenses/gpl-3.0.txt"
$LgplUrl        = "https://www.gnu.org/licenses/lgpl-3.0.txt"

# Extract project name
$ProjectName = ($SshCloneUrl -split '/')[-1].Replace(".git", "")


# --- Git Availability Check ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in your PATH."
    exit 1
}


# --- Clone Repository ---
Write-Host "Cloning repository from $SshCloneUrl"
try {
    git clone $SshCloneUrl *>$null
} catch {
    Write-Error "Failed to clone the repository. Please check the URL and your SSH key configuration."
    exit 1
}

# Change directory into the project
Set-Location -Path $ProjectName


# --- Create Project Structure ---
Write-Host "Setting up project structure for '$ProjectName'"
$SourceDir = "src"
New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null


# --- Download Standard Files ---
Write-Host "Downloading license and .gitignore files"
try {
    Invoke-WebRequest -Uri $GplUrl      -OutFile "COPYING"
    Invoke-WebRequest -Uri $LgplUrl     -OutFile "COPYING.LESSER"
    Invoke-WebRequest -Uri $GitIgnoreUrl -OutFile ".gitignore"
} catch {
    Write-Error "Failed to download required files from the internet."
    exit 1
}


# --- Create .gitattributes ---
Set-Content -Path ".gitattributes" -Value @"
# Auto detect text files and perform LF normalization
* text=auto
"@


# --- Create README.md ---
Set-Content -Path "README.md" -Value @"
# $ProjectName


***

## License

This project is licensed under the terms of the **GNU Lesser General Public License v3.0**.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but **WITHOUT ANY WARRANTY**; without even the implied warranty of **MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE**. See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU General Public License and the GNU Lesser General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

The full text of the licenses can be found in the root of this project:

*   **[COPYING](./COPYING)** (The GNU General Public License)
*   **[COPYING.LESSER](./COPYING.LESSER)** (The GNU Lesser General Public License)
"@


# --- License Header ---
$LicenseHeader = @"
"""
$ProjectName - $ProjectDescription
Copyright (C) $Year  $Author

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
"""
`n`n
"@


# --- setup.py ---
$SetupContent = $LicenseHeader + @"
from setuptools import setup, find_packages


setup(
    name="$ProjectName",
    version="0.0.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
)
"@
Set-Content -Path "setup.py" -Value $SetupContent


# --- __init__.py ---
$InitContent  = $LicenseHeader + "__all__ = []"
$InitPath = Join-Path $SourceDir "__init__.py"
Set-Content -Path $InitPath -Value $InitContent


# --- main.py ---
$MainContent  = $LicenseHeader + @"
def main():
    pass


if __name__ == '__main__':
    main()
"@
$MainPath = Join-Path $SourceDir "main.py"
Set-Content -Path $MainPath -Value $MainContent


# --- Virtual Environment Setup ---
Write-Host "Creating Python virtual environment"
python -m venv .venv

Write-Host "Installing setuptools and creating requirements.txt"
$PipPath = Join-Path ".venv" "Scripts\pip.exe"

& $PipPath install -qqq setuptools
& $PipPath freeze > requirements.txt


# --- Git Commit and Push ---
Write-Host "Creating Git commits and pushing to remote"
git add COPYING COPYING.LESSER *>$null
git commit -q --no-verbose -m "chore: add LGPL v3 LICENSE"

git add . *>$null
git commit -q --no-verbose -m "chore: init empty python project template"

git push -u origin main *>$null

Write-Host "Creating and pushing dev branch"
git switch -c dev *>$null
git push -u origin dev *>$null

Write-Host "Project '$ProjectName' created successfully!"
