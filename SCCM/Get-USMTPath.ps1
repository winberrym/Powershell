# Get-USMTPath.ps1

# Message Pop Up Function
function Trigger-PopUp
{
	param(
		[string]$title,
        [string]$msg,
        [string]$options,
        [string]$style
    )
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [Windows.Forms.MessageBox]::Show("$msg", "$title", "$options","$style")
}

function Kill-AppList
{
    # Close all the running background apps that we're backing stuff up for
    $applist = ("communicator,lync,lynchtmlconv,onedrive,groove,AeXAgentUIHost,AeXAuditPls,AeXInvSoln,AeXNSAgent,alg,AppleMobileDeviceService,igfxpers,igfxsrvc,igfxtray,OUTLOOK,picpick,googletalk").split(',')
    foreach($app in $applist)
    {
        try{$proc=get-process $app -EA SilentlyContinue}
        catch{$proc=$null}
        if($proc)
        {
            $proc.kill()
        }
    }
}

function Reload-WinForm
{
    $WinForm.Close()
    $WinForm.Dispose()
    $script:TSBackupPath=$null
    $script:USMTPath=$null
    $script:formexit=$false
    $script:confirmed=$false
    Run-WinForm
}

function Unblock-USB
{
    # Enable External Device Writes
    $rempol = "HKLM:\Software\Policies\Microsoft\Windows\RemovableStorageDevices"
    $polscope = get-childitem $rempol
    $denye = "Deny_Execute"
    $denyr = "Deny_Read"
    $denyw = "Deny_Write"
    foreach($pol in $polscope)
    {
        $polpath = $pol.PSPath
        $deny_execute = Get-RegistryValue -Path $polpath -Value $denye
        if($deny_execute -eq 1){set-itemproperty $polpath -Name $denye -Value 0}
        $deny_read = Get-RegistryValue -Path $polpath -Value $denyr
        if($deny_read -eq 1){set-itemproperty $polpath -Name $denyr -Value 0}
        $deny_write = Get-RegistryValue -Path $polpath -Value $denyw
        if($deny_write -eq 1){set-itemproperty $polpath -Name $denyw -Value 0}
    }

    # Disable Block of USB Write
    $storpol = "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies"
    $protkey = "WriteProtect"
    $exists = Get-RegistryValue -Path $storpol -Value $protkey
    if($exists -eq 1){set-itemproperty $storpol -Name $protkey -Value 0}
}

function Get-RegistryValue {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    )

        $valpath = Get-Item -Path $Path
        try{$val = $valpath.GetValue($Value)}
        catch{$val=$null}
        if($val)
        {return $val}
        else
        {return $null}
}

function Create-RegistryValue {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Name,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    )
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | out-null
}
function New-OnBootScheduledTask {
    param (
        [Parameter()]
	    [string]$TaskName,
        [Parameter()]
        [ValidateScript({Test-Path -Path $_ -PathType 'Leaf' })]
        [string]$FilePath,
        [Parameter()]
        [string]$TaskDescr,
        [Parameter()]
	    [string]$TaskCommand,
        [Parameter()]
	    [string]$TaskArgs
    )
    try{
        # The Task Action command
        $TaskCommand = "cmd"
        # attach the Task Scheduler com object
        $service = new-object -ComObject("Schedule.Service")
        # connect to the local machine. 
        # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381833(v=vs.85).aspx
        $service.Connect()

        $rootFolder = $service.GetFolder("\")
        try{$TaskFolder = $service.GetFolder("\USMT")}
        catch{
            $rootFolder.CreateFolder("USMT")
            $TaskFolder = $service.GetFolder("\USMT")
        }
        $TaskDefinition = $service.NewTask(0) 
        $TaskDefinition.RegistrationInfo.Description = "$TaskDescr"
        $TaskDefinition.Settings.Enabled = $true
        $TaskDefinition.Settings.AllowDemandStart = $true

        $triggers = $TaskDefinition.Triggers
        #http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
        $trigger = $triggers.Create(8) # Creates a "Boot" trigger
        $trigger.Enabled = $true

        $TaskEndTime = [datetime]::Now.AddMinutes(30)
		$Trigger.EndBoundary = $TaskEndTime.ToString("yyyy-MM-dd'T'HH:mm:ss")

        # http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
        $Action = $TaskDefinition.Actions.Create(0)
        $action.Path = "$TaskCommand"
        $action.Arguments = "$TaskArgs"
        #http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
        $TaskFolder.RegisterTaskDefinition("$TaskName",$TaskDefinition,6,"System",$null,5) | out-null
        }catch{Write-Error $_.Exception.Message}
}

function Validate-FinalPath
{
    if(($formexit -eq $false) -and ($confirmed -eq $false))
    {
        if($script:TSBackupPath -ne $null)
        {
            if((test-path $script:TSBackupPath) -eq $true)
            {
                # Root Share exists, confirm with user.
                $title = "Backup Path Confirmation"
                $message = "You have chosen the following backup path:`n`n$USMTPath`n`nIs this correct?`n(Click Yes to confirm, No to Retry, Cancel to Exit.)"
                $options = "YesNoCancel"
                $style = "Question"
                $confirmbox = Trigger-PopUp -Title $Title -msg $message -options $options -style $style
                if($confirmbox -eq "Yes"){
                    # This is our USMT Path
                    if((test-path $script:USMTPath) -eq $true)
                    {
                        # USMT Path already exists, check to make sure that it's okay to overwrite.
                        write-host "The USMT Backup Path already exists, prompting for action..."
                        $title = "USMT Backup Path already exists."
                        $message = "The USMT Backup Folder already exists.  Do you want to overwrite it?`n`nClick Yes to Overwrite, No to enter a new path, or Cancel to close."
                        $options = "YesNoCancel"
                        $style = "Warning"
                        $failbox = Trigger-PopUp -Title $Title -msg $message -options $options -style $style
                        if($failbox -eq "Yes"){
                            write-host "USMT Backup Folder location confirmed, overwriting..."
                            $tsenv.Value("OSDStateStorePath") = $script:USMTPath
                            write-host "The USMT Backup Folder path is $script:USMTPath"
                            $tsenv.Value("returncode") = 0
                            Kill-AppList
                            Stop-Transcript
                        }
                        if($failbox -eq "Retry"){Reload-WinForm;$confirmed=$false}
                        else{}
                    }
                    else{
                        try{$newdir = new-item $script:USMTPath -type Directory -Force -ErrorAction SilentlyContinue}
                        catch{$newdir=$null}
                        if($newdir)
                        {
                                # Successfully created the folder, set our TS Variable, kill the apps and move on
                                $tsenv.Value("OSDStateStorePath") = $script:USMTPath
                                write-host "Successfully create the USMT Backup Folder"
                                write-host "The USMT Backup Folder path is $script:USMTPath"
                                $tsenv.Value("returncode") = 0
                                Kill-AppList
                                Stop-Transcript
                        }
                        else {
                                write-host "Failed to create drive on Network Share."
                                $title = "Failed to create drive on Network Share."
                                $message = "The Backup Folder could not be created.  Please double check share permissions and re-run the task sequence."
                                $options = "RetryCancel"
                                $style = "Error"
                                $failbox = Trigger-PopUp -Title $Title -msg $message -options $options -style $style
                                if($failbox -eq "Retry"){Reload-WinForm;$confirmed=$false}
                                else{}
                        }

                    }
                }
                if($confirmbox -eq "No"){Reload-WinForm;$script:confirmed=$false}
                if($confirmbox -eq "Cancel"){}
            }
            else {
                # Root Share doesn't exist or can't be accessed.
                $title = "Failed to locate Root Network Share"
                $title = "Failed to locate Network Share"
                $message = "The Network share provided could not be located or accessed.  Please double check the path and re-run the task sequence."
                $options = "RetryCancel"
                $style = "Error"
                $failbox = Trigger-PopUp -Title $Title -msg $message -options $options -style $style
                if($failbox -eq "Retry"){Reload-WinForm;$confirmed=$false}
                else{}
            }
        }
        else {
        }
    }
    else 
    {
        $tsenv.Value("returncode") = 1
    }
}

function Run-WinForm
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Windows.Forms.Application]::EnableVisualStyles()
    
    # Set our initial validating conditions for formexit and confirm
    $script:formexit = $false
    $script:confirmed = $false

    # Create our Nested Functions
    # Validation Functions
    # Check to see if the text field is null or has changed.
    function Validate-Tag
    {
        Param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNull()]
            [string]$textfield,
            [string]$tagfield
            )
        if($textfield -eq $tagfield)
        {
            # Text fields are the same
            return $true
        }
        else
        {
            # Text fields are different
            return $false
        }
    }

    function Browse-ForFolder
    {
        $o = new-object -comobject Shell.Application
        $folder = $o.BrowseForFolder(0,"Select location to store user backup",4213,17)
        $fstest = $folder.self.IsFileSystem
        if($fstest -eq $true){
            $selectedfolder = $folder.self.path
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($o) > $null
        }
        else{
            $selectedfolder = ''
        }
        return $selectedfolder
    }

    # Non-validation Functions
    # Output to TS Function
    Function Assemble-Path ([string]$TSBP,[string]$TSFUN)
    {
        # Set the TS variable for the backup path
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        $tsenv.Value("TSCusBackupPath") = $TSBP
        $tsenv.Value('TSCusFullUserName') = $TSFUN
        $TSSUN = $TSFUN.split('\')[1]
        $tsenv.Value('TSCusPrimaryUser') = $TSSUN
        $script:USMTPath = "$TSBP\$TSSUN"
        Validate-FinalPath
    }

    # Create our objects:
    $script:WinForm = New-Object 'System.Windows.Forms.Form'
    $script:OKButton = New-Object 'System.Windows.Forms.Button'
    $script:CancelButton = New-Object 'System.Windows.Forms.Button'
    $script:BrowseButton = New-Object 'System.Windows.Forms.Button'
    $script:objpathLabel = New-Object 'System.Windows.Forms.Label'
    $script:objuserLabel = New-Object 'System.Windows.Forms.Label'
    $script:objpathTextBox = New-Object 'System.Windows.Forms.TextBox'
    $script:objuserTextBox = New-Object 'System.Windows.Forms.TextBox'
    $script:PathErrorProvider = New-Object 'System.Windows.Forms.ErrorProvider'
    $script:UserErrorProvider = New-Object 'System.Windows.Forms.ErrorProvider'
    $script:InitialFormWindowState = New-Object 'System.Windows.Forms.FormWindowState'

    # Set our Error Handler options
    $PathErrorProvider.BlinkStyle = "NeverBlink"
    $UserErrorProvider.BlinkStyle = "NeverBlink"
    $PathErrorProvider.ContainerControl = $WinForm
    $UserErrorProvider.ContainerControl = $WinForm

    # Define our validating conditions
    # Path validating
    $objpathTextBox_Validating = [System.ComponentModel.CancelEventHandler]{
        $_.Cancel = $true
        $title = "Backup Path Invalid"
        $options = "OK"
        $style = "Error"
        try{
            $_.Cancel = Validate-Tag $objpathTextBox.Text $objpathTextBox.Tag
            if($_.Cancel)
            {
                $msg = "Please enter a valid Backup Path."
                Trigger-PopUp -title $title -msg $msg -options $options -style $style
                $PathErrorProvider.SetError($this,$msg)
                $PathErrorProvider.SetIconAlignment($this, [System.Windows.Forms.ErrorIconAlignment]::MiddleLeft)
            }
            else {
                $objpathTextBox.ForeColor = 'WindowText'
            }
        }
        catch [System.Management.Automation.ParameterBindingException]{
            $msg = "The Backup Path Field cannot be blank."
            Trigger-PopUp -title $title -msg $msg -options $options -style $style
            $PathErrorProvider.SetError($this,$msg)
            $PathErrorProvider.SetIconAlignment($this, [System.Windows.Forms.ErrorIconAlignment]::MiddleLeft)
        }
    }

    # User validating
    $objUserTextBox_Validating = [System.ComponentModel.CancelEventHandler]{
        $_.Cancel = $true
        $title = "UserName Invalid"
        $options = "OK"
        $style = "Error"
        try{
            $msg = "Please enter a valid UserName in Domain\Username format."
            $_.Cancel = Validate-Tag $objuserTextBox.Text $objuserTextBox.Tag
            if($_.Cancel)
            {
                Trigger-PopUp -title $title -msg $msg -options $options -style $style
                $UserErrorProvider.SetError($this,$msg)
                $UserErrorProvider.SetIconAlignment($this, [System.Windows.Forms.ErrorIconAlignment]::MiddleLeft)
            }
            else {
                if($objuserTextBox.Text -notlike "*\*")
                {
                    $_.Cancel = $true
                    Trigger-PopUp -title $title -msg $msg -options $options -style $style
                    $UserErrorProvider.SetError($this,$msg)
                    $UserErrorProvider.SetIconAlignment($this, [System.Windows.Forms.ErrorIconAlignment]::MiddleLeft)
                }
                else {
                    $objuserTextBox.ForeColor = 'WindowText'
                }
            }
        }
        catch [System.Management.Automation.ParameterBindingException]{
            $msg = "The UserName Field cannot be blank."
            Trigger-PopUp -title $title -msg $msg -options $options -style $style
            $UserErrorProvider.SetError($this,$msg)
            $UserErrorProvider.SetIconAlignment($this, [System.Windows.Forms.ErrorIconAlignment]::MiddleLeft)
        }
    }

    # Path validated
    $objpathTextBox_Validated ={
        # Pass the calling control and clear error message
        $PathErrorProvider.SetError($this, "")
    }

    # User validated
    $objUserTextBox_Validated ={
        # Pass the calling control and clear error message
        $UserErrorProvider.SetError($this, "")
    }

    # Add the controls to our form
    $WinForm.Controls.Add($OKButton)
    $WinForm.Controls.Add($CancelButton)
    $WinForm.Controls.Add($BrowseButton)
    $WinForm.Controls.Add($objpathTextBox)
    $WinForm.Controls.Add($objuserTextBox)
    $WinForm.Controls.Add($objuserLabel)
    $WinForm.Controls.Add($objpathLabel)

    # Customize the form
    $WinForm.Size = '320,200'
    $WinForm.Text = "USMT Backup Path"
    $WinForm.StartPosition = "CenterScreen"
    $Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    $WinForm.Icon = $Icon
    $WinForm.Topmost = $True
    $WinForm.AcceptButton = $OKButton

    # Set up Validation when the form closes with OK.
    $WinForm_FormClosing=[System.Windows.Forms.FormClosingEventHandler]{
        #Event Argument: $_ = [System.Windows.Forms.FormClosingEventArgs]
            #Validate only on OK Button
            if($WinForm.DialogResult -eq "OK")
            {
                #Validate the Child Control and Cancel if any fail
                $_.Cancel = -not $WinForm.ValidateChildren()
            }
            else {
                write-host "The Form was canceled before being completed."
                $tsenv.Value("returncode") = 1
            }
    }

    # Allow for Enter and Escape Key action on Form.
    $WinForm.KeyPreview = $True
    $WinForm.Add_KeyDown(
        {
            # Use the OK Button Click Event for the OK button.
            if ($_.KeyCode -eq "Enter"){$OKButton.PerformClick()}
            # Use the Cancel Button Click Event for the Escape button.
            if ($_.KeyCode -eq "Escape"){$WinForm.close()}
    })

    # Customize the OK Button
    $OKButton.Location = '20,115'
    $OKButton.Size = '75,23'
    $OKButton.Text = "&OK"
    $OKButton.TabIndex = 3
    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK

    # Define our Button Click event
    $OKButton.Add_Click(
    {
        $script:TSBackupPath=$objpathTextBox.Text
        $TSBP = $objpathTextBox.Text
        $TSFUN=$objuserTextBox.Text
        $TSDomain = $TSFUN.split('\')[0]
        Assemble-Path -TSBP $TSBP -TSFUN $TSFUN
        $WinForm.Close()
        $WinForm.Dispose()
    })

        # Customize the Browse Button
        $BrowseButton.Location = '210,40'
        $BrowseButton.Size = '60,21'
        $BrowseButton.Text = "&Browse"
        $BrowseButton.CausesValidation = $false
        $BrowseButton.TabIndex = 1
    
        # Define our Button Click Event
        $BrowseButton.Add_Click({
            $Browsing=$true
            $Winform.Visible =  $false
            $BrowseInput = Browse-ForFolder
            if(![string]::IsNullOrEmpty($BrowseInput))
            {
                $objpathTextBox.Text = $BrowseInput
                $Winform.Visible = $true
            }
            else
            {
                $Winform.Visible = $true
            }
        })

   # Customize the Cancel Button
   $CancelButton.Location = '205,115'
   $CancelButton.Size = '75,23'
   $CancelButton.Text = "&Cancel"
   $CancelButton.CausesValidation = $false
   $CancelButton.TabIndex = 4
   $CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    # Define our Button Click Event
    $CancelButton.Add_Click({
            write-host "The Operation was canceled."
            $script:TSBackupPath=$null
            $script:USMTPath=$null
            $script:formexit=$true
            $tsenv.Value("returncode") = 1
            $WinForm.Close()
            $WinForm.Dispose()
            Stop-Transcript
    })

    # Customize our Text Boxes
    # Path Text Box
    $objpathTextBox.Location = '20,40'
    $objpathTextBox.Size = '182,23'
    $objpathTextBox.Text = "\\<server>\<share>"
    $objpathTextBox.Tag = "\\<server>\<share>"
    $objpathTextBox.TabIndex = 0
    $objpathTextBox.Add_Validating($objpathTextBox_Validating)
    $objpathTextBox.Add_Validated($objpathTextBox_Validated)
    

    # User Text Box
    $objuserTextBox.Location = '20,90'
    $objuserTextBox.Size = '260,40'
    $objuserTextBox.Text = "<Domain>\<UserName>"
    $objuserTextBox.Tag = "<Domain>\<UserName>"
    $objuserTextBox.TabIndex = 2
    $objuserTextBox.Add_Validating($objUserTextBox_Validating)
    $objuserTextBox.Add_Validated($objUserTextBox_Validated)
    
    # Customize our Text Labels
    # Path Label
    $objpathLabel.TextAlign ="BottomLeft"
    $objpathLabel.Location = '20,20'
    $objpathLabel.Size = '280,20'
    $objpathLabel.Text = "Please enter the USMT Backup Path:"

    # User Label
    $objuserLabel.TextAlign ="BottomLeft"
    $objuserLabel.Location = '20,70'
    $objuserLabel.Size = '280,20'
    $objuserLabel.Text = "Please enter the User ID of the Primary User:"

    # Setup our TS Object
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment

    # Call our form
    [void] $WinForm.ShowDialog()
}

# Create our TS Environment object
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
# Define our logging path and filename
$logPath = $tsenv.Value("_SMSTSLogPath")
$now = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
# $logPath = "C:\Temp"
$filename = ("$($myInvocation.MyCommand)").split('.')[0]
$filename = "$($filename)-$now.log"
$logFile = "$logPath\$filename"

# Start the logging 
Start-Transcript $logfile

#Hide the progress dialog
$TSProgressUI = new-object -comobject Microsoft.SMS.TSProgressUI
$TSProgressUI.CloseProgressDialog()

# Prep the registry for storing our reboot keys.
$ConRegPath = "HKLM:\Software\Contoso"
$RegRebootPath = "$ConRegPath\USMT"
$testrootpath = test-path $RegRebootPath
if(!$testrootpath)
{
    write-host "Initial run of the TS, creating HKLM:\Software\Contoso\USMT subkey."
	New-Item -Path $ConRegPath -Name USMT -Force | out-null
}

# Set up variables for our registry key values
$ChkDskRebootNeededKey = "ChkDskRebootNeeded"
$ChkDskRebootedKey = "ChkDskRebooted"
$USBRebootNeededKey = "USBRebootNeeded"
$USBRebootedKey = "USBRebooted"

do
{
    # Check to see if we need to ask about CheckDisk.
    $ChkDskRebootNeeded = Get-RegistryValue -Path $RegRebootPath -Value $ChkDskRebootNeededKey

    switch ($ChkDskRebootNeeded)
    {
        $false {
            # The question has already been asked, and answered with a No.
            $chkdskgo = $true
        }
        $null {
            # The question has not yet been asked, and needs to be.
            $title = "Run CheckDisk?"
            $message = "Do you want to run CheckDisk to check the disk for errors?`n`nIf you click Yes, the system will restart and initiate a ChkDsk on the local C: drive."
            $options = "YesNo"
            $style = "Question"
            $chkdiskcheck = Trigger-PopUp -title $title -msg $message -options $options -style $style
            switch ($chkdiskcheck)
            {
                "Yes" {
                    write-host "Reboot needed for CheckDisk."
                    # Create the RebootNeeded Registry Key and set to true.
                    Create-RegistryValue -Path $RegRebootPath -Name $ChkDskRebootNeededKey -Value "True"
                    # Create a scheduled task on boot to change the Rebooted Key to True.
                    $Name = "Set Rebooted Registry Keys for $ChkDskRebootedKey key"
                    $Descr = "Set our Rebooted Registry Key for $ChkDskRebootedKey to True after reboot."
                    $TaskCommand = "cmd"
                    $TaskArgs = "/c reg add HKLM\Software\Contoso\USMT /v $ChkDskRebootedKey /t REG_SZ /d True /f"
                    New-OnBootScheduledTask -TaskName $Name -TaskDescr $Descr -TaskCommand $TaskCommand -TaskArgs $TaskArgs
                }
                "No" {
                    # This makes life easier.
                    write-host "Reboot not needed for CheckDisk."
                    # Create the RebootNeeded Registry Key and set to false.
                    Create-RegistryValue -Path $RegRebootPath -Name $ChkDskRebootNeededKey -Value "False"
                }
            }
        }
        $true {
            $ChkDskRebooted = Get-RegistryValue -Path $RegRebootPath -Value $ChkDskRebootedKey
            switch ($ChkDskRebooted)
            {
                $true {
                    #Reboot completed.
                    write-host "Checkdisk has been run and the machine has been rebooted."
                    $chkdskgo = $true
                }
                $false {
                    # We need to reboot, but haven't yet.
                    write-host "Checkdisk has been selected and the machine needs to reboot."
                    $cdrive = Get-WMIObject -class Win32_LogicalDisk -Filter 'DeviceID="C:"'
                    $cdrive.chkdsk($false,$false,$false,$true,$false,$true)
                }
                $null {
                    # Create the Rebooted Registry Key and set to false, since we haven't rebooted yet.
                    Create-RegistryValue -Path $RegRebootPath -Name $ChkDskRebootedKey -Value "False"
                }
            }
        }
    }
}
until(($ChkDskRebootNeeded -eq $false) -or ($ChkDskRebooted -ne $null))

do
{
    # Check to see if we need to ask about USB Storage. The first run will be a null result.
    $USBRebootNeeded = Get-RegistryValue -Path $RegRebootPath -Value $USBRebootNeededKey

    switch ($USBRebootNeeded)
    {
        $false {
            # The question has already been asked, and answered with a No.
            write-host "The user is not using USB Storage."
            $usbchkgo = $true
        }
        $null {
            # The question has not yet been asked, and needs to be.
            $title = "Contoso User Data Backup - USB Storage"
            $message = "Will the backup be stored on a USB or other removable drive, directly connected to this PC?  If you are backing up to a network location (i.e. \\server\share\backup), choose No."
            $options = "YesNo"
            $style = "Question"
            $usbcheck = Trigger-PopUp -title $title -msg $message -options $options -style $style
            switch ($usbcheck)
            {
                "Yes" {
                    write-host "Reboot needed for USB."
                    # Create the RebootNeeded Registry Key and set to true.
                    Create-RegistryValue -Path $RegRebootPath -Name $USBRebootNeededKey -Value "True"
                    # Create a scheduled task on boot to change the Rebooted Key to True.
                    $Name = "Set Rebooted Registry Keys for $USBRebootedKey key"
                    $Descr = "Set our Rebooted Registry Key for $USBRebootedKey to True after reboot."
                    $TaskCommand = "cmd"
                    $TaskArgs = "/c reg add HKLM\Software\Contoso\USMT /v $USBRebootedKey /t REG_SZ /d True /f"
                    New-OnBootScheduledTask -TaskName $Name -TaskDescr $Descr -TaskCommand $TaskCommand -TaskArgs $TaskArgs
                    # Rerun our script after reboot.
                    $Scriptpath = "$PSScriptroot\$($myInvocation.MyCommand)"
                    $Name = "Rerun Get-USMTPath.ps1"
                    $Descr = "Rerun the script after reboot to unblock USB."
                    $TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
                    $TaskArgs = "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -file $Scriptpath"
                    New-OnBootScheduledTask -TaskName $Name -TaskDescr $Descr -TaskCommand $TaskCommand -TaskArgs $TaskArgs
                }
                "No" {
                    # This makes life easier.
                    write-host "Reboot not needed for USB."
                    # Create the RebootNeeded Registry Key and set to false.
                    Create-RegistryValue -Path $RegRebootPath -Name $USBRebootNeededKey -Value "False"    
                }
            }
        }
        $true {
            $USBRebooted = Get-RegistryValue -Path $RegRebootPath -Value $USBRebootedKey
            switch ($USBRebooted)
            {
                $true {
                    #Reboot completed.
                    write-host "USB Restriction policy has been lifted and the machine has been rebooted."
                    $usbchkgo = $true
                }
                $false {
                    # We need to reboot, but haven't yet.
                    $title = "Contoso User Data Backup - Disable WiFi and Reboot"
                    $options = "OK"
                    $style = "Information"
                    $message = "To enable USB storage access, the PC will need to be rebooted. WiFi connections will be disabled automatically.  Before clicking OK, please disconnect the wired Ethernet cable." 
                    Trigger-PopUp -title $title -msg $message -options $options -style $style
                    write-host "USB Storage has been selected and the machine needs to reboot."
                    $adapters = @(Get-WmiObject -Namespace Root\CIMv2 -class Win32_NetworkAdapter | ? {$_.NetEnabled})
                    try{$netresult = $adapters | % {if($_ | select * | % {$_ -like "*Wireless*"}){$_.Disable()}}}
                    catch{$netresult=$null}
                    if($netresult.ReturnValue -eq 0)
                    {
                        write-host "The wireless network adapter has been disabled."
                        Unblock-USB
                        write-host "Rebooting the machine."
                        $tsenv.Value("returncode") = 0
                        Stop-Transcript
                        Restart-Computer -Force
                    }
                    else {
                        write-host "There was a problem disabling the network adapters."
                        $tsenv.Value("returncode") = 1
                        Stop-Transcript
                    }
                }
                $null {
                    # Create the Rebooted Registry Key and set to false, since we haven't rebooted yet.
                    Create-RegistryValue -Path $RegRebootPath -Name $USBRebootedKey -Value "False"
                }
            }
        }
    }
}
until(($USBRebootNeeded -eq $false) -or ($USBRebooted -ne $null))

if(($chkdskgo -eq $true) -and ($usbchkgo -eq $true))
{
    write-host "This is where the form should begin."
    # Get our path
    Run-WinForm
}
else {
    write-host "Either chkdskgo or usbchkgo returned false."
    Stop-Transcript
}
