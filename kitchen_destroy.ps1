#Requires -RunAsAdministrator
param([string]$vmName)

function stop_vm_by_name
{
    param([string]$vmName)
    $vm = Get-VM -Name $vmName
    if ($vm.State -eq [Microsoft.HyperV.PowerShell.VMState]::Running) {
        Stop-VM -VM $vm -Force -Confirm:$false
    }
}

function delete_vm_by_name
{
  param([string]$vmName)
  $vm = Get-VM -Name $vmName
  if (($vm.State -ne [Microsoft.HyperV.PowerShell.VMState]::Off) -and ($vm.State -ne [Microsoft.HyperV.PowerShell.VMState]::OffCritical)) {
    Stop-VM -VM $vm -TurnOff -Force -Confirm:$false
  }
  Remove-VM -Name $vmName -Force -Confirm:$false
}

function get_default_vm_disk_path
{
    $vmmsSettings = gwmi -namespace 'root\virtualization\v2' Msvm_VirtualSystemManagementServiceSettingData -computername '.'
    $vmmsSettings.DefaultVirtualHardDiskPath
}

function get_vm_disk_path
{
    param([string]$vmName)
    $disk_name = $vmName + '.vhdx'
    $default_path = get_default_vm_disk_path
    $disk_path = Join-Path $default_path -ChildPath $disk_name
    $disk_path
}

stop_vm_by_name $vmName
delete_vm_by_name $vmName
$disk_dest = get_vm_disk_path $vmName
rm $disk_dest
kitchen destroy $vmName
