## PowerShell

**WoL-Script:** A script to turn on a computer on the same network using *magic packet* and *Wake-on-LAN* feature. [Windows to Linux]

* Both computers (the computer running the script and the target computer) must be on the same network.
* Target computer should support *Wake-on-LAN* feature and it should be enabled.
* MAC address of the target computer should be known.

* Parameters:
    * **MacAddress:** MAC address of the target computer
    * **Username:** Username of the user on the target computer
    * **GrubBootIndex *[Optional]*:** If the target computer has more than one Linux distro installed, specify the index of the target boot. *(Default: 0)*
