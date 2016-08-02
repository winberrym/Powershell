# Written by: Matt Winberry
# Function: Clone the members of one group to another
# Creation date: 7/28/16
# Version 1
# Add major updates below this line!
# Example:
# Clone-GroupMembers -src "TUR.GRP.MG.ALN.TST" -dest "TUR.GRP.MG.ALN.TST2"
# or
# Clone-GroupMembers "TUR.GRP.MG.ALN.TST" "TUR.GRP.MG.ALN.TST2"
#  

param(
    [Parameter(Mandatory=$true,Position = 0)]
    [string]$src,
    [Parameter(Mandatory=$false,Position = 1)]
    [string]$dest)

	# Hook to our source and destination groups here.
	try{$srcgroup = get-adgroup -Identity $src}
	catch{$srcgroup = $null}
	try{$destgroup = get-adgroup -Identity $dest}
	catch{$destgroup = $null}
	
	# If the source group doesn't exist, the catch statement above will make the variable null,
	# so it won't iterate through the rest of this section.
	if($srcgroup)
	{
		write-host "`nGetting group members for $($srcgroup.Name).`n"
		# The group exists, now we see if it has members in it.
		$srcgroupmem = get-adgroupmember $srcgroup
		# No need for a try/catch here, as a group with no members will naturally return null.
		if($srcgroupmem)
		{
			# If the destination group doesn't exist, the catch statement above will make the variable null,
			# so it won't iterate through the rest of this section.
			if($destgroup)
			{
				# Now we move through our group members and check to see if they're already in the destination
				foreach($mem in $srcgroupmem)
				{
					if((get-adgroupmember $destgroup).name -contains $($mem.name))
					{
						write-host "$($mem.name) is already a member of $($destgroup.name)" -f Yellow
					}
					else
					{
						write-host "Adding $($mem.name) to $($destgroup.name)" -f Green
						add-adgroupmember -Identity $destgroup -Member $mem
					}
				}
			}
			# This is what happens if the destination group doesn't exist.
			else
			{
				write-host "$dest does not exist.`n" -f Red
			}
		}
		# This is what happens if the source group doesn't contain any members.
		else
		{
			write-host "There are no group members in $($srcgroup.Name).`n" -f Red
		}
	}
	# This is what happens if the source group doesn't exist.
	else
	{
		write-host "$src does not exist.`n" -f Red
	}
	
	write-host "`nGetting Group membership for Destination Group.`n" -f Green
	$destgroupmem = get-adgroupmember $destgroup
	# This part should never error out if the error checking above does its job, but you never know.
	if($destgroupmem)
	{
		($destgroupmem | select Name).Name
		write-host "`n"
	}
	else
	{
		write-host "`nThere are no group members for $dest, which shouldn't be true." -f Yellow
	}