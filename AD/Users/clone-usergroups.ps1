# Written by: Matt Winberry
# Function: Clone User Groups memberships from one to another.
# Creation date: 7/8/16
# Version 1
# Add major updates below this line!
# Syntax:
# clone-usergroups.ps1 <sourceuser> <destination user>
#

param(
	[Parameter(Mandatory=$true,Position=0)]
	[string]$source=$null,
	[Parameter(Mandatory=$true,Position=1)]
	[string]$dest=$null)

$error.clear()
try{$adsource = get-aduser $source -Property MemberOf}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {$adsource=$null}
try{$addest = get-aduser $dest -Property MemberOf}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {$addest=$null}
if($adsource)
{
	if($addest)
	{
		write-host "Getting groups for user $($source)..." -f Green
		$srcgroups = $adsource | select -expand MemberOf
		foreach($group in $srcgroups)
		{
			$group = $group.split(',')[0].substring(3)
			$members = get-adgroupmember -Identity $group
			if($members.samaccountname -like "*$($dest)*")
			{
				write-host "User $dest is already in $group." -f Yellow
			}
			else
			{
				write-host "Adding $dest to $group." -f Green
				add-adgroupmember -Identity $group -Member $addest
			}
		}
		write-host "Operation Complete." -f Green
		$destgroups = $addest | select -expand MemberOf
		write-host "User $dest is currently in the following groups :"
		$destgroups | % {$_.split(',')[0].substring(3)}
	}
	else
	{
		write-host "Destination user $dest is not a valid user." -f Red
	}
}
else
{
	write-host "Source user $source is not a valid user." -f Red
}