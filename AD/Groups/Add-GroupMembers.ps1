# Written by: Matt Winberry
# Function: Script to add members to an AD Group.
#
# Creation date: 5/3/2016
# Last modified date: 5/3/2016
# Version 1
# Add major updates below this line!
#
#

$listdir = "\\jackwagon\d$\Scripts\Matt\Powershell\AD\Groups"
$list = ipcsv $listdir\NoGroupQ216OSPatching.csv
foreach($item in $list)
{
	$sname = $item.Server
	$gname = $item.'New Group'
	try{$group = get-adgroup -Identity $gname}
	catch{$group = "Not in AD";write-host $gname $group}
	try{$server = get-adcomputer $sname}
	catch{$server = "Not in AD";write-host $sname $server}
	add-adgroupmember -Identity $group -Member $server
}

