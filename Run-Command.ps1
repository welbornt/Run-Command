# Run-Command.ps1 : Run commands across a number of Azure VMs within the same subscription via GUI selection
# Version : 1.0
# Copyright 2022 Timothy Welborn
# License: New BSD License

# verify the user is authenticated to azure
if($null -eq (Get-AzContext)){
    Connect-AzAccount
}

# select the subscription
Write-Host 'Select the target subscription in the dialog window.'
$Subscription = Get-AzSubscription -WarningAction SilentlyContinue `
    | Sort-Object -Property Name `
    | Out-GridView -PassThru -Title "Select a subscription"
if($null -eq $Subscription){
    Write-Warning 'No subscription selected. Exiting.'
    Exit
}
elseif($Subscription.Length -ne 1){
    Write-Warning 'Multiple subscriptions selected. Exiting.'
    Exit
}
Write-Host "Selected `"$($Subscription.Name)`" : $($Subscription.Id)"

# set the current subscription
Set-AzContext -SubscriptionId $Subscription.Id | Out-Null

# TODO: check how many vms exist, allow multiple selection
Write-Host 'Select the target VM/s in the dialog window'
$VMs = Get-AzVM
if($VMs.Length -eq 0){
    Write-Warning 'No VMs present in the selected subscription. Exiting.'
    Exit
}
$Targets = $Vms | Sort-Object -Property Name | Out-GridView -PassThru -Title 'Select a VM'
if($null -eq $Targets){
    Write-Warning 'No target/s selected. Exiting.'
    Exit
}
elseif($Targets.GetType().BaseType -eq 'Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine'){
    $Targets = @($Targets)
}
Write-Host "Selected VMs`n____________"
foreach($vm in $Targets){
    Write-Host $vm.Name
}

# select the script file
Write-Host "`nSelect the script to execute in the dialog window."
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [System.Environment]::GetFolderPath('Desktop')
    #Filter = '*.ps1 |*.sh'
}
$FileBrowser.ShowDialog() | Out-Null
Write-Host "Selected `"$($FileBrowser.FileName)`""

# verify the script file is a .ps1 or .sh file
$Script = $FileBrowser.FileName
if($Script.Endswith('.ps1')){
    $Command = 'RunPowerShellScript'
}
elseif($Script.Endswith('.sh')){
    $Command = 'RunShellScript'
}
else{
    Write-Warning 'Invalid file selected. Exiting.'
    Exit
}

# prompt the user to press a key to begin the running of the script
$Confirmation = Read-Host -Prompt `
    "Please verify the above selections are correct and type `"Confirm`" to begin running the selected script"
if($Confirmation -eq 'Confirm'){
    # if confirmed, run the script on each selected VM
    foreach($vm in $Targets){
        Write-Host "`nRunning the script on $($vm.Name)..."
        $Result = Invoke-AzVMRunCommand -ErrorAction Continue -ResourceGroupName $vm.ResourceGroupName `
            -Name $vm.Name -CommandId $Command -ScriptPath $Script
        Write-Host $Result.Status
        $Result
    }
}
else{
    Write-Warning 'Invalid confirmation. Exiting.'
    Exit
}
