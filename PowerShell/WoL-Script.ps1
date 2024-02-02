# WoL-Script.ps1
param (
    [string]$MacAddress,
    [string]$Username,
    [Int32]$GrubBootIndex = 0
)

function Convert-MACtoPhysicalAddress {
    param (
        [string]$MAC
    )

    $MAC = $MAC.ToUpper()
    try {
        return [System.Net.NetworkInformation.PhysicalAddress]::Parse($MAC)
    }
    catch {}
}

function Convert-PhysicalAddresstoMAC {
    param (
        [System.Net.NetworkInformation.PhysicalAddress]$PhysicalAddress
    )

    $MACArray = [string[]]($PhysicalAddress.GetAddressBytes() | ForEach-Object {
        return $_.ToString("X2")
    })
    return ($MACArray -join '-').ToUpper()
}

function Get-CurrentIPAddress {
    $PhysicalInterfaces = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
    if ($PhysicalInterfaces.Length -lt 0) {
        return
    }
    if ($PhysicalInterfaces.Length -gt 1) {
        ## possible bug
        throw "Fix this function"
    }

    $InterfaceIndex = $PhysicalInterfaces[0].InterfaceIndex
    $IPAddress = Get-NetIPAddress -AddressFamily 'IPv4' -InterfaceIndex $InterfaceIndex
    return $IPAddress
}

function Get-IPFromMAC {
    param (
        [string]$TargetMAC,
        [string]$hostIPAddress,
        [Int32]$repeat = -1,
        [Int32]$PingSleepMS = 5000
    )

    ## not sure why repeating once/twice does not work
    $repeat = (($repeat -lt 3) -and ($repeat -gt 0)) ? 3 : $repeat

    Invoke-Expression -Command "arp -d"
    while ($repeat -ne 0) {
        $instances = Get-NetNeighbor -LinkLayerAddress $TargetMAC -AddressFamily 'IPv4' -ErrorAction:SilentlyContinue
        if ($instances.Length -gt 0) {
            return $instances[0].IPAddress
        }

        Start-Sleep -Milliseconds $PingSleepMS
        Ping-Arp -IPAddress $hostIPAddress
        $repeat = $repeat - 1
    }
}

## https://xkln.net/blog/layer-2-host-discovery-with-powershell-in-under-a-second/
function Ping-Arp {
    param (
        [string]$IPAddress,
        [Int32]$timeoutMS = 0,
        [Int32]$IPRangeStart = 1,
        [Int32]$IPRangeEnd = 254
    )

    $IPNetworkPortion = $IPAddress -replace '\.\d*$',''
    $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
    $Bytes = $ASCIIEncoding.GetBytes("a")
    $UDP = New-Object System.Net.Sockets.Udpclient

    $IPRangeStart..$IPRangeEnd | ForEach-Object {
        $IPPinging = $IPNetworkPortion + '.' + $_

        $UDP.Connect($IPPinging,1)
        [void]$UDP.Send($Bytes,$Bytes.length)
        if ($timeoutMS) {
            [System.Threading.Thread]::Sleep($timeoutMS)
        }
    }
}

## https://stackoverflow.com/a/72853503
function Send-MagicPacket {
    param (
        [string]$TargetMAC,
        [string]$HostIPAddress
    )
    
    $TargetPhysicalAddress = Convert-MACtoPhysicalAddress -MAC $TargetMAC
    $targetPhysicalAddressBytes = $TargetPhysicalAddress.GetAddressBytes()
    $packet = [byte[]](,0xFF * 6)+($targetPhysicalAddressBytes * 16)
    $IPAddress = [System.Net.IPAddress]::Parse($HostIPAddress)
    $client = [System.Net.Sockets.UdpClient]::new([System.Net.IPEndPoint]::new($IPAddress, 0))

    try {
        $client.Send($packet, $packet.Length, [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Broadcast, 9)) | Out-Null
    } 
    finally {
        $client.Dispose()
    }
}

function Invoke-CommandOnSSH {
    param (
        [string]$Hostname,
        [string]$Options = "",
        [string]$Command
    )
    return Invoke-Expression -Command "ssh $Options $Hostname '$Command'"
}

function Initialize-SSHKey {
    param (
        [string]$Hostname
    )
        
    $sshKeyDirectory = "$HOME/.ssh"
    $sshKeyFilename = "id_rsa"

    if (-not ((Test-Path "$sshKeyDirectory/$sshKeyFilename" -PathType Leaf) -and (Test-Path "$sshKeyDirectory/$sshKeyFilename.pub" -PathType Leaf))) {
        if (-not (Test-Path "$sshKeyDirectory")) {
            New-Item -Path $sshKeyDirectory -ItemType Directory
        }

        Write-Output "Generating ssh-key"
        Invoke-Expression -Command "ssh-keygen -q -f $sshKeyDirectory/$sshKeyFilename -t rsa -b 2048"
    }

    $fileExists = [Int32](Invoke-CommandOnSSH -Hostname $Hostname -Command "test -e ~/.ssh/authorized_keys && echo 1 || echo 0")
    if (-not $fileExists) {
        $folderExists = [Int32](Invoke-CommandOnSSH -Hostname $Hostname -Command "test -e ~/.ssh/ && echo 1 || echo 0")
        if (-not $folderExists) {
            Invoke-CommandOnSSH -Hostname $Hostname -Command "mkdir ~/.ssh"
        }

        Write-Output "Copying public ssh-key to $Hostname"
        Invoke-Expression -Command "scp $sshKeyDirectory/$sshKeyFilename.pub ${Hostname}:~/.ssh/authorized_keys"
    }
}

function Connect-MAC {
    param (
        [string]$TargetMAC,
        [string]$TargetUsername,
        [string]$GrubBootIndex
    )

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This function requires administrator privileges. Please run the script as an administrator."
    }

    $currentIPAddress = Get-CurrentIPAddress
    if ($null -eq $currentIPAddress) {
        throw "No internet connection"
    }

    $TargetPhysicalAddress = Convert-MACtoPhysicalAddress -MAC $TargetMAC
    if ($null -eq $TargetPhysicalAddress) {
        throw "Invalid MAC address $TargetMAC"
    }
    $TargetMAC = Convert-PhysicalAddresstoMAC -PhysicalAddress $TargetPhysicalAddress

    
    Write-Output "Sending magic packet to $TargetMAC"
    Send-MagicPacket -TargetMAC $TargetMAC -HostIPAddress $currentIPAddress.IPAddress

    Write-Output "Waiting for $TargetMAC to boot"
    $TargetIP = Get-IPFromMAC -TargetMAC $TargetMAC -hostIPAddress $currentIPAddress.IPAddress
    $hostname = "$TargetUsername@$TargetIP"
    Write-Output "$TargetMAC (IP:$TargetIP) booted"
    
    Initialize-SSHKey -Hostname $hostname

    if ($GrubBootIndex -ne 0) {
        Write-Output "Rebooting into grub-boot-$GrubBootIndex"
        Invoke-CommandOnSSH -Hostname $hostname -Options "-qt" -Command "sudo grub-reboot $GrubBootIndex && sudo init 6"
    
        Write-Output "Waiting for $TargetMAC to boot"
        $TargetIP = Get-IPFromMAC -TargetMAC $TargetMAC -hostIPAddress $currentIPAddress.IPAddress
        Write-Output "$TargetMAC (IP:$TargetIP) booted"
    
        Initialize-SSHKey -Hostname $hostname
    }


    ssh $hostname
}


Connect-MAC -TargetMAC $MacAddress -TargetUsername $Username -GrubBootIndex $GrubBootIndex
