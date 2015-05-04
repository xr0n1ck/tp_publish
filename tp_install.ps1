$path = Split-Path -parent $MyInvocation.MyCommand.Definition
cd $path

#Default settings
$webroot = "C:\inetpub\TargetProcess"
$sitename = "TargetProcess"
$port = "80"
$ip_address = "*"

#Argparse
if ($args) {
    [Collections.ArrayList]$args = $args
    if ($args.Contains("--webroot") -and ($args[$args.IndexOf("--webroot") + 1])) {
        $webroot = $args[$args.IndexOf("--webroot") + 1]
    }
    if ($args.Contains("--sitename") -and ($args[$args.IndexOf("--sitename") + 1])) {
        $sitename = $args[$args.IndexOf("--sitename") + 1]
    }
    if ($args.Contains("--port") -and ($args[$args.IndexOf("--port") + 1])) {
        $port = $args[$args.IndexOf("--port") + 1]
    }
    if ($args.Contains("--ip_address") -and ($args[$args.IndexOf("--ip_address") + 1])) {
        $ip_address = $args[$args.IndexOf("--ip_address") + 1]
    }             
}

if (-not (test-path $webroot)) {
    New-Item $webroot -ItemType Directory -Force
}
if (test-path "$path\TargetProcess.zip") {
    #Unpack piblish folder to web directory
    [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | out-null
    [System.IO.Compression.ZipFile]::ExtractToDirectory( "$path\TargetProcess.zip", $webroot )
    
    #edit Web.config with args settings
    $content = get-content "$webroot\Web.config" | % {
        $_ -replace "<add key=`"GitFolder`" value=`"C:\\inetpub\\TargetProcess\\App_Data\\rep`" />", "<add key=`"GitFolder`" value=`"$webroot\App_Data\rep`" />" `
        -replace "<add key=`"GitUrl`" value=`"C:\\inetpub\\TargetProcess\\App_Data\\base`" />", "<add key=`"GitUrl`" value=`"$webroot\App_Data\base`" />"
    } 
    set-content -path "$webroot\Web.config" -value $content
}
else {
    write-host "Error: " -foregroundcolor "red" -NoNewLine
    write-host "Could not find $path\TargetProcess.zip file"
    exit 1
}


Import-Module WebAdministration
#create app pool
if (-not (test-path "IIS:\AppPools\$sitename")) {
    New-Item "IIS:\AppPools\$sitename"
}
Set-ItemProperty "IIS:\AppPools\$sitename" managedRuntimeVersion "v4.0"

#create site
if (-not (test-path "IIS:\Sites\$sitename")) {
    $id=((get-website).id | select -last 1 ) + 1
    New-WebSite -Name $sitename -Port $port -ID $id -IP $ip_address -HostHeader '' -PhysicalPath $webroot -ApplicationPool $sitename
    & "$env:SystemRoot\System32\inetsrv\appcmd.exe" set config "TargetProcess" -section:system.web/identity /impersonate:"False"
    
    #set acl for git repo folder (with applicarion pool identity user)
    icacls "$webroot\App_Data" /t /grant "IIS AppPool\${sitename}:(F)"
}
else {
    write-host "Warning: " -foregroundcolor "yellow" -NoNewLine
    write-host "Site $sitename already exists"
}
