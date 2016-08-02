# Written by: Matt Winberry
# Function: Script to remove all members from an AD Group.
#
# Creation date: 5/3/2016
# Last modified date: 5/3/2016
# Version 1
# Add major updates below this line!
#
#

import-module ActiveDirectory
#Define our group here.
$group = get-adgroup -Identity TUR.GRP.MG.FLD.PT 
#Get group members here.
$groupmem = get-adgroupmember -Identity $group 
#Remove group members here.  Commented out for safety.
#$groupmem | % {Remove-ADGroupMember $group $_ -confirm:$false} 
