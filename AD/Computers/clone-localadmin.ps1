# Written by: Matt Winberry
# Function: Script to clone the local admin group membership between servers.
# Creation date: 7/19/2016
# Last modified date: 7/19/2016
# Version 1
# Add major updates below this line!
#


Param( 
[Parameter(ValueFromPipeline=$True, Position=0, ValueFromPipelineByPropertyName=$True,Mandatory=$true)] 
[String]
$sourcemachine,
[Parameter(ValueFromPipeline=$True, Position=1, ValueFromPipelineByPropertyName=$True,Mandatory=$true)] 
[String]
$destmachine)



Write-host "Connecting to $($sourcemachine)" -f Cyan
$SourceAdminGroup = [ADSI]"WinNT://$sourcemachine/Administrators,group"
Write-host "Connecting to $($destmachine)" -f Cyan
$DestAdminGroup = [ADSI]"WinNT://$destmachine/Administrators,group"
$sourcemembers = $sourceadmingroup.psbase.Invoke("Members")
$output = @()
ForEach($member in $sourcemembers)
{
	$fullname = ([ADSI]$member).Path
	if($fullname -notlike "WinNT://S-*")
    {
        write-host "Checking ADSI Properties for $($fullname)." -f Green
        $shortname = ($fullname.substring(8)).split('/')
        if($shortname[1] -eq $sourcemachine)
        {
            write-host "$($shortname[2]) is a local account." -f Yellow
        }
        else
        {
            if($shortname[0] -eq "EXT")
            {
                write-host "Look for a way to handle $($fullname)" -f Magenta
            }
            else
            {
                try{$adsitest = [adsi]$fullname}
                catch [System.Management.Automation.RuntimeException]{$adsitest = $null}
            }
            if($adsitest)
            {
                write-host "Adding $($shortname[1]) to Local AdminGroup on $destmachine"
                $adsiuser = $adsitest
                try{$DestAdmingroup.Add($adsiuser.Path);$addcheck="True"}
                catch [System.Management.Automation.MethodInvocationException]{write-host "$($shortname[1]) is already a member of the local admin group." -f Red;$addcheck="False"}
            }
        }
    }
	$obj = new-object PSObject -Prop @{'Member'=$($shortname[1]);'Added'=$addcheck}
	$output+=$obj
}
$output | sort Member