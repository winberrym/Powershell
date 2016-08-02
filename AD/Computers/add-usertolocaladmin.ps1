# Written by: Matt Winberry
# Function: Script to add a user or group to local admin.
# Creation date: 6/26/15
# Last modified date: 7/21/2016
# Version 1.1
# Add major updates below this line!
#
# 7/21/2016 - Added parameters to allow piping input to script instead of hardcoding, and to accept multiple computers/users.
# 7/21/2016 - Changed domain declaration to be automatic, instead of hardcoded.
# 7/21/2016 - Removed the function, as it was just the line "$AdminGroup.Add($User.Path)", hardly seemed worth keeping it declared.
# 7/21/2016 - Commented out $Username and $Computers to allow pipeline input instead.
#
#Cobbled together from knowledge gained on:
#https://4sysops.com/archives/add-a-user-to-the-local-administrators-group-on-a-remote-computer/

param(
	[parameter(position=0,mandatory=$true)]
	[string]
	$Computers,
	[parameter(position=1,mandatory=$true)]
	[string]
	$Users)

$DomainName = (([system.directoryservices.activedirectory.domain]::GetCurrentDomain()).Name).split('.')[0]
#Define the users that we're going to add.
$Users = $Users.split(',')
#Define which computers we're going to do this on.
$Computers = $Computers.split(',')
foreach($u in $users)
{
	#Set up the ADSI statement for adding the user.
	$User = [ADSI]"WinNT://$DomainName/$u,user"
	foreach($ComputerName in $Computers)
	{
		#Define which group we're going to add the user to.  This could be any local security group, not just admin.
		$AdminGroup = [ADSI]"WinNT://$ComputerName/Administrators,group"
		#Loop through our list of servers and call the Add method on the ADSI object.
		$AdminGroup.Add($User.Path)
	}
}




