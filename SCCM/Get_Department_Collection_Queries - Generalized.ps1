param([switch]$export)

<#
.SYNOPSIS
    Gets MECM Device Collection Query Expressions, creates new query expressions, and reports results.
.DESCRIPTION
    Last year we automated the process of creating query based device collection memberships based on our new naming
    convention.  Because the naming convention is much more granular than our original naming convention, the creator
    of the naming convention insisted that we create device collections to match each functional area for every department.
    We also used an overly complicated query expression that evaluated against a value that could be simplified with regex.
    This made collection evaluation incredibly slow, and a year later we still aren't using most of those subdepartment
    collections.  Now we've been told to simplify and strip out the extraneous query based collection membership rules.
    This script imports XML information containing department allocation information, compiles a list of department id's,
    connects to MECM to gather device collection information, filters the results to only include query based collection 
    rules that were created when we implemented this standard, checks to see how many clauses are in the query expression,
    determines whether or not the query is simple or complex, compiles a new query expression to replace the old one, runs
    both the old query and the new query, records the results, adds them to an array, and either returns the array in export
    or object form.
.INPUTS
    None that aren't explicitly defined in the body.
.OUTPUTS
    ArrayList contents
.NOTES
	===========================================================================
    Created on:   	05/11/2022>
    Created by:   	Matt Winberry
    Organization: 	Washington University in St. Louis - Information Technology
    Requirements:	MECM
	===========================================================================
#>


#region Start-Log

Function Start-Log {
<#
.SYNOPSIS
    Start-Log creates the logfile.
.DESCRIPTION
    Composes the FilePath based on the script filename, and creates the log file in the directory the script/executable was run.
.INPUTS
    None
.OUTPUTS
    Log file is created
.EXAMPLE
    Start-Log
.NOTES
#>

    # Define our current date for the log filename
    $now = Get-Date -Format "MM-dd-yyyy-hh-mm"

    $MyCommandString = $script:MyInvocation.MyCommand.ToString()
    $fname_regex = ".*?(?=\.ps1)"
    $fnameval = ($MyCommandString | select-string $fname_regex).Matches.Value
    $filename = "$($fnameval)-$now.log"
    $FilePath = "$($psscriptroot)\$($filename)"  

    try
    {
        if (!(Test-Path $FilePath))
        {
            ## Create the log file
            New-Item $FilePath -Type File | Out-Null
        }

        ## Set the global variable to be used as the FilePath for all subsequent Write-Log
        ## calls in this session
        $Script:ScriptLogFilePath = $FilePath
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

#endregion Start-Log

#region Write-Log

Function Write-Log {
<#
.SYNOPSIS
    Write-Log writes data to the logfile.
.DESCRIPTION
    Writes to the log file in CMTrace format for easier review of errors and warnings.
.PARAMETER Message
    Status text to be written to the log or log & host
.PARAMETER Silent
    Writes status text only to the log
.PARAMETER LogLevel
    1 for informational messages; 2 for warning messages; 3 for error messages
.INPUTS
    None
.OUTPUTS
    Messages to the log file
.EXAMPLE
    Write-Log "Informational message"
    Write-Log "Informational message" -Silent
    Write-Log "Informational message" -LogLevel 1
    Write-Log "Informational message" -LogLevel 1 -Silent
    Write-Log "Warning message" -LogLevel 2
    Write-Log "Warning message" -LogLevel 2 -Silent
    Write-Log "Error message" -LogLevel 3
    Write-Log "Error message" -LogLevel 3 -Silent
.NOTES
#>    
    param (
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [switch]$silent,    
    [Parameter()]
    [ValidateSet(1, 2, 3)]
    [int]$LogLevel = 1
    )

    # Set up our time values
    $BaseDate = Get-Date
    $FriendlyDate = $BaseDate.ToString("MM/dd/yyyy HH:mm:ss")
    $OutMessage = "[$FriendlyDate]: $Message"

    # Get our calling source
    $Source = (Get-Variable -Name MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value
    $Component = $([string]$parentFunctionName = [IO.Path]::GetFileNameWithoutExtension($Source.MyCommand.Name); If($parentFunctionName) {$parentFunctionName} Else {'Unknown'})
    if(!$silent){
        if($LogLevel -eq 1){
            $color = (get-host).ui.rawui.ForegroundColor
        }
        if($LogLevel -eq 2){
            $color = "Yellow"
        }
        if($LogLevel -eq 3){
            $color = "Red"
        }
        write-host $OutMessage -ForegroundColor $color
    }

    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($Component):$($MyInvocation.ScriptLineNumber)", $LogLevel
    $Line = $Line -f $LineFormat
    try{Add-Content -Value $Line -Path $ScriptLogFilePath}
    catch{
        $retrycount = 1
        $logretry = $true
        while(($logretry) -and ($retrycount -le 5)){
            try{
                Add-Content -Value $Line -Path $ScriptLogFilePath
                $logretry = $false
            }
            catch{
                start-sleep -seconds 1
                $retrycount++
            }
        }
    }
}

#endregion Write-Log

# Kick off logging.
Start-Log

#region Import XML for Dept Info

write-log "Gathering XML Information..." -LogLevel 2
# Create an array for our department id string information.
$department_id_array = New-Object System.Collections.ArrayList

# Import our XML file for Department Allocations. This will give us our department information
[xml]$department_allocation_xml = Get-Content "\\files.contoso.com\DepartmentData.xml"

# Compile a list of our departments to collate our department ID's from.
$department_list = ($department_allocation_xml | select-xml -xpath "//department").Node | Where-Object {$_.enabled -eq "True"}

# Loop through our department list and get our department name and id, then add to our array.
foreach($department in $department_list){
    # Define our department name
    $dep_name = $department.Name
    # Glue together the bits that make our department id.
    $dep_id = "$($department.campusidentifier)$($department.identifier)"
    # Put the information into an object for storage.
    $dep_obj = [PSCustomObject]@{'Name'=$dep_name;'ID'=$dep_id}
    # Store our object and move on.
    [void]$department_id_array.add($dep_obj)
}

#endregion Import XML for Dept Info

#region Setup SCCM Connection

write-log "Setting up SCCM Connection..." -LogLevel 2
# Site configuration
$SiteCode = "SMS" # Site code 
$ProviderMachineName = "Server.Contoso.com" # SMS Provider machine name

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}

# Connect to the site's drive if it is not already present
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}

# Set the current location to the CMSite PSDrive.
Push-Location $SiteCode":"

#endregion Setup SCCM Connection

#region Get Collection Information

write-log "Getting Device Collection Data..." -LogLevel 2

# Get our device collections
$device_collections = Get-CMDeviceCollection

#endregion Get Collection Information

#region Parse Collection Data

write-log "Parsing Collection Rule information..." -LogLevel 2

# Create an array to store our reporting results in
$result_array = New-Object System.Collections.ArrayList

# Filter to just the device collections that have Query based membership rules that are evaluating against the system Name, and that were named according to our standard rulename.
$query_devicename_collections = $device_collections | Where-Object {($_.CollectionRules.SmsProviderObjectPath -contains "SMS_CollectionRuleQuery") -and ($_.CollectionRules.QueryExpression -like "*SMS_R_System.Name like*") -and ($_.CollectionRules.RuleName -like "Computer Name Matching*")}

# Define the regex pattern that we're going to use to check for multiple query conditions.
# My regex patterns are tested against https://regexr.com/ which is the work of a genius.
$clause_pattern = "(?<=like ).*?(?= and| or|$)"

# Get all of the Query Expressions used in these collections and record them
$i = 1
foreach($dev_coll in $query_devicename_collections){
    # Get our collection name value and assign to a variable
    $collection_name = $dev_coll.Name
    # Get our collection id value and assign to a variable
    $collection_id = $dev_coll.CollectionID    
    write-log "Recording detail for $collection_name ($collection_id), item $i of $($query_devicename_collections.count)"
    # Get our collection rules
    $collection_rules = $dev_coll.CollectionRules
    # Create custom objects for our collection rules
    $rule_objects = $collection_rules | ForEach-Object {[pscustomobject]@{RuleName=$_.RuleName;OldQueryExpression=$_.QueryExpression}}
    # Check for the existance of a "new" rule.  
    # While we've filtered to just collections with rules that have a RuleName like "Computer Name Matching*", some of them will have
    # other collection membership rules as well, and we only want to examine this specific rule for the collection, not all of the rules.
    $modern_rule = $rule_objects | Where-Object {$_.RuleName -like "Computer Name Matching*"}
    # See if the rule name parses to an ID.
    try{
        $parsed_rule_val = $modern_rule | ForEach-Object {
            $RuleName = $_.RuleName
            $parsed_obj = [pscustomobject]@{
                'Parsed_Rule'=$RuleName.ToString().Split('-')[-1].Trim().TrimEnd().substring(0,2) | Select-Object -Unique
                'RuleName' = $RuleName
            }
            $parsed_obj
        }
    } catch{
        $parsed_rule_val = $null
        Pop-Location
        throw $_
    }
    # Handle the parsed val check the same as the modern rules check, by using a foreach and piping the results, works with single or multiple results.
    $parsed_rule_val | ForEach-Object {
        $parsed_rule = $_.Parsed_Rule
        $RuleName = $_.RuleName
        # Now see if that ID matches any from our list of department ID's
        $department_match = $department_id_array | Where-Object {$_.ID -eq $parsed_rule}
        if($null -ne $department_match){
            # There are rules that we want to check.
            $modern_rule | ForEach-Object {
                # Assign our old query expression to a variable.
                $qrule = $_.OldQueryExpression
                # Check to see if our old query expression had multiple clauses.
                $clause_check = ($qrule | select-string $clause_pattern -AllMatches).Matches.value
                $clause_check_count = $clause_check.count
                if($clause_check_count -gt 1){
                    $querytype = "Complex"
                    write-log "Rule $RuleName has multiple clauses in the query logic structure:"
                    $clause_check | ForEach-Object {write-log "$($_)"}
                } else {
                    $querytype = "Simple"
                }
                # Set the expression for our dummy old query to the query expression.
                Set-CMQuery -ID SMS0016C -Expression $qrule
                # Invoke the query and count the results.
                $old_query_result = Invoke-CMQuery -Id SMS0016C
                $old_qr_count = ($old_query_result | Measure-Object).count
                $id_match = $department_match.ID
                $new_query_string = "select SMS_R_System.NetbiosName from SMS_R_System where SMS_R_System.NetbiosName like '{0}[a-z0-9][a-z0-9][a-z0-9][awlx][dltvw]-%'" -f $id_match
                # See if the query expression for the new dummy query needs to change.
                $NewQueryExpression = (Get-CMQuery -Id SMS0016D).Expression
                if($NewQueryExpression -ne $new_query_string){
                    # Set the expression for our dummy new query to the query expression.
                    Set-CMQuery -ID SMS0016D -Expression $new_query_string
                    # Invoke the query and count the results.
                    $new_query_result = Invoke-CMQuery -Id SMS0016D
                    $new_qr_count = ($new_query_result | Measure-Object).count
                } else {
                    # No need to change anything.
                }
                # Create our result object and add to our results array.
                $resobj = [PSCustomObject]@{'Name'=$collection_name;'CollectionID'=$collection_id;'Department'=$department_match.Name;'IDMatch'=$id_match;'RuleName'=$Rulename;'OldQueryRule'=$qrule;'OldQueryClauses'=$clause_check_count;'QueryType'=$querytype;'OldQueryResultCount'=$old_qr_count;'NewQueryRule'=$new_query_string;'NewQueryResultCount'=$new_qr_count;}
                [void]$result_array.Add($resobj)
            }
        } else {
            # There isn't a department in the list that has this ID, no need to tabulate for now.
            write-log "Found NO departments matching $parsed_rule for RuleName $RuleName" -LogLevel 3
        }        
    }
    $i++
}

#endregion Parse Collection Data

# Switch back to our previous location
Pop-Location

if($export){
    write-log "Exporting Data..."
    # Export our data
    $result_array | Sort-Object Name | Select-Object Name,CollectionID,Department,IDMatch,RuleName,QueryType,OldQueryRule,OldQueryClauses,OldQueryResultCount,NewQueryRule,NewQueryResultCount | Export-Csv "C:\temp\department_collection_query_results_$(Get-Date -Format "MMddyyyy_hhmm").csv" -NoType
} else {
    $result_array | Sort-Object Name | Select-Object Name,CollectionID,Department,IDMatch,RuleName,QueryType,OldQueryRule,OldQueryClauses,OldQueryResultCount,NewQueryRule,NewQueryResultCount
}
