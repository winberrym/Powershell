#Requires -Version 2.0            
 Param             
   (
    [String]$Domain,
	[string]$CurrentForest
    )#End Param

if($CurrentForest -or $Domain)
{
    try{$Forest = [system.directoryservices.activedirectory.Forest]::GetCurrentForest()}
    catch{$Forest = $null;write-host "Cannot connect to current forest." -f Red}
    if($Domain)
    {
		# User specified domain
		$Forest.domains | Where-Object {$_.Name -eq $Domain} | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name}
	}
    else
	{
        # All domains in forest
        $Forest.domains | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name}
	}
}
else
{
    # Current domain only
    [system.directoryservices.activedirectory.domain]::GetCurrentDomain() | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name}
}