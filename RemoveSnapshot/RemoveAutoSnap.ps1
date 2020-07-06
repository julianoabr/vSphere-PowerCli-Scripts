#Requires -Version 4.0
#Requires -RunAsAdministrator  

<#
.Synopsis
   Delete Snapshots with more than 5 days
.DESCRIPTION
   Delete Snapshots with more than 5 days and don't has string DNR5 in description
.EXAMPLE
   Inserir posteriormente
.EXAMPLE
   Inserir posteriormente
.CREATEDBY
    Juliano Alves de Brito Ribeiro (julianoalvesbr@live.com ou jaribeiro@uoldiveo.com)
.VERSION INFO
    0.3
.VERSION NOTES
    Add function to unmount vmtools if is mounted on a VM. If Vmtools is mounted, Snapshot will not removed and throught an error.
.TO THINK
    “Todos os livros científicos passam por constantes atualizações. 
    Se a bíblia, que por muitos é considerada obsoleta e irrelevante, 
    nunca precisou ser atualizada quanto ao seu conteúdo original, 
    o que podemos dizer dos nossos livros científicos de nossa ciência?” 

#>


#PAUSE POWERSHELL
function Pause
{

   Read-Host 'Press Enter to continue…' | Out-Null
}

#VALIDATE MODULE
    $moduleExists = Get-Module -Name Vmware.VimAutomation.Core

    if ($moduleExists){
    
        Write-Output "The Module Vmware.VimAutomation.Core is already loaded"
    
    }#if validate module
    else{
    
        Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop
    
    }#else validate module


[string]$vcServer = 'YourVcenter'

[string]$vcServerPort = '443'

Connect-VIServer -Server $vcServer -Port $vcServerPort -WarningAction SilentlyContinue

$outputPath = "$env:systemDrive\Temp"

if (!(Test-Path $outputPath)){

    Write-Host "Folder Named: Temp does not exists. I will create it" -ForegroundColor Yellow -BackgroundColor Black

    New-Item -Path "$env:SystemDrive\" -ItemType Directory -Name "Temp" -Confirm:$true -Verbose -Force

}else{

    Write-Host "Folder Named: Temp Already Exists" -ForegroundColor White -BackgroundColor Blue
    
    Write-Output "`n"
 
}

$actualDate = (Get-Date -Format "ddMMyyyy-HHmmss")

#Put the time that you consider ok to exclude. Vmware Recommends 3 days
#https://kb.vmware.com/s/article/1025279?lang=en_us
$trimDate = (Get-Date).AddHours(-120)

#THE OBJECTIVE OF THIS STRING IS BYPASS THE PROCEDURE. VMS THAT HAS DNR5 in Snapshot description, their snapshots will not be deleted
[string]$stringDNR = 'DNR5'


$snapshotList = Get-Vm | Get-Snapshot | Where-Object -FilterScript {$_.Created -lt "$trimdate" -and $_.Description -notlike "*$stringDNR*"}

$vmList = @()

if(!($snapshotList)){
    
    Write-Output "In $dataAtual there are no snapshots to remove according to parameters. 5 days and DNR5 string" | Out-File -FilePath "$outputPath\AutomaticRemoveVC65-$actualDate-Snapshots.txt" -Append

}#end of IF
else{
    Write-Output "List of Snapshots Removed in: $dataAtual" | Out-File -FilePath "$outputPath\AutomaticRemoveVC65-$actualDate-Snapshots.txt" -Append
    
    Write-Output "`n"

    foreach ($snap in $snapshotList){
    
     $snapName = $snap.Name
     
     $vmName = $snap.VM.Name

     $vM = $snap.vm

     [System.Boolean]$mountedTools = $vm.ExtensionData.Runtime.ToolsInstallerMounted

     #Validate if VM has VmTools mounted
     If ($mountedTools){
     
        Write-Output "VM: $vmName has Vmtools mounted. I have to unmount before remove Snapshot"

        $Vm | Dismount-Tools -Verbose
        
        Start-Sleep -Seconds 5    
     
     }
     
     Write-Output "Now I will remove the $snapName of the VM $vmName ..." 
       
     $snap | Select-Object -Property Name,Description,Created,SizeGB,VM | Out-File -FilePath "$outputPath\AutomaticRemoveVC65-$actualDate-Snapshots.txt" -Append

     Remove-Snapshot -Snapshot $snap -RunAsync -RemoveChildren -Confirm:$false -Verbose

    }#end forEach

    Start-Sleep -Seconds 120

    #LISTA DE VMs para verificar se é necessário consolidar discos.
        
    $vmList = $snapshotList.VM.Name

    #IF NECESSARY CONSOLIDATE DISKS
    foreach ($tmpVM in $vmList){
    
        $vm = Get-VM -Name $tmpvm

        $consolidationNeeded = $vm.ExtensionData.Runtime.ConsolidationNeeded

        if ($consolidationNeeded -like "false"){ 
        
         Write-Output "The VM $tmpVM does not need consolidation disk"  | Out-File -FilePath "$outputPath\AutomaticRemoveVC65-$actualDate-Snapshots.txt" -Append  

         }#end of IF
         else{
         
         Write-Output "The VM $tmpVM needs consolidation disk"  | Out-File -FilePath "$outputPath\AutomaticRemoveVC65-$actualDate-Snapshots.txt" -Append

         $vm.ExtensionData.ConsolidateVMDisks()
         
         }#end of Else
    
    
    }#end forEach

}#end of Else


Disconnect-ViServer -Server $vcServer -Force -Confirm:$false -ErrorAction SilentlyContinue
