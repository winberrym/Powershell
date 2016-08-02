# Written by: Matt Winberry
# Function: Script to add the word decomm to the beginning of the AD Computer Description.
# I run this as a scheduled task on a server that has the AD PS Module installed.
#
# Creation date: 7/18/2016
# Last modified date: 7/18/2016
# Version 1
# Add major updates below this line!
#
#

Param( 
[Parameter(ValueFromPipeline=$True, Position=0, ValueFromPipelineByPropertyName=$True)] 
[String[]]
$Computername)

if(!$computername)
{
	write-host "No computername was passed, using the local computername." -f Yellow
	$computername=$Env:COMPUTERNAME
}

$Computername = $computername.split(',')
$output = @()
ForEach($Computer in  $Computername){
	Try  {
		Write-host "Connecting to $($Computer)" -f Cyan
		$adsi=[ADSI]"WinNT://$Computer,computer"
		write-host "Gathering members for the local administators group..." -f Cyan
		$group = $ADSI.psbase.children.find('Administrators','Group')
		$group.psbase.invoke("members")  | ForEach{
			$memname =([ADSI]$_).InvokeGet("Name")
			$obj = new-object PSObject -Prop @{'Member'=$memname}
			$output+=$obj
			}
		}
	Catch  {
		Write-Warning  "$($Computer): $_"
		}
}

$output | sort Member