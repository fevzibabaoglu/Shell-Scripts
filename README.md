# AutoHotKey

## MaximizeTerminal
Minimizes all the apps except the terminal when the terminal is maximized.

## ToggleDesktopIcons
Toggle desktop icons using shortcut [Win+Q].


---
# PowerShell

## CreatePythonProject
A script to automate the setup of a new Python project from a remote Git repository. It clones the repo, initializes a project structure, adds LGPLv3.0 licensing, and prepares the development environment.

* Requires Git, Python, and internet access.
* Automatically creates main and dev branches and pushes them to the remote.
* Includes LGPLv3.0 licensing, virtual environment setup, and initial source files.

* Parameters:
    * SshCloneUrl: SSH URL of the Git repository (e.g., git@github.com:user/repo.git)
    * Author: Name of the project author (used in license headers)
    * ProjectDescription: A short description of the project

## WoL-Script
A script to turn on a computer on the same network using *magic packet* and *Wake-on-LAN* feature. [Windows to Linux]

* Both computers (the computer running the script and the target computer) must be on the same network.
* Target computer should support *Wake-on-LAN* feature and it should be enabled.
* MAC address of the target computer should be known.

* Parameters:
    * MacAddress: MAC address of the target computer
    * Username: Username of the user on the target computer
    * GrubBootIndex *[Optional]*: If the target computer has more than one Linux distro installed, specify the index of the target boot. *(Default: 0)*
