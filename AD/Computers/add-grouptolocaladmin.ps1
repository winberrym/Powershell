# Written by: Matt Winberry
# Function: Script to add a user or group to local admin.
# Creation date: 6/26/15
# Version 1.1
# Add major updates below this line!
# 
# 8/2/2016 - Changed domain declaration to be automatic, instead of hardcoded.
# 8/2/2016 - Added parameters to allow piping input to script instead of hardcoding, and to accept multiple computers/users.
# 8/2/2016 - Changed domain declaration to be automatic, instead of hardcoded.
# 8/2/2016 - Removed the function, as it was just the line "$AdminGroup.Add($User.Path)", hardly seemed worth keeping it declared.
# 
#Cobbled together from knowledge gained on:
#https://4sysops.com/archives/add-a-user-to-the-local-administrators-group-on-a-remote-computer/

param(
	[parameter(position=0,mandatory=$true)]
	[string]
	$Computers,
	[parameter(position=1,mandatory=$true)]
	[string]
	$Group)
	
$DomainName = (([system.directoryservices.activedirectory.domain]::GetCurrentDomain()).Name).split('.')[0]
#Define the user that we're going to add.
$Group = "<Insert Group Name between quotation marks>"
#Set up the ADSI statement for adding the user.
$Member = [ADSI]"WinNT://$DomainName/$Group,group"
#Define which computers we're going to do this on.
$Computers = $Computers.split(',')
#Loop through our list of servers and call the function.
foreach($ComputerName in $Computers){
#Define which group we're going to add the user to.  This could be any local security group, not just admin.
$AdminGroup = [ADSI]"WinNT://$ComputerName/Administrators,group"
$AdminGroup.Add($Member.Path)
}

