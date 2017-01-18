#Requires -RunAsAdministrator
param([string]$vmName, [string]$box)

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

function get_vagrant_box_path
{
    param([string]$box, [string]$boxversion)
    $box_parts = $box.split('/')
    if($box_parts[1] -Match 'centos')
    {
      $arch = 'x86_64'
    } else {
      $arch = 'amd64'
    }
    $box_image = $box_parts[1]+'-'+$arch+'.vhdx'
    $vagrant_dir = Join-Path $HOME -ChildPath '.vagrant.d' |
                   Join-Path -ChildPath 'boxes' |
                   Join-Path -ChildPath $box.replace('/', '-VAGRANTSLASH-') |
                   Join-Path -ChildPath $boxversion |
                   Join-Path -ChildPath 'hyperv' |
                   Join-Path -ChildPath 'Virtual Hard Disks' |
                   Join-Path -ChildPath $box_image
    $vagrant_dir
}

function create_virtual_machine
{
    param([string]$vmName, [string]$vhdPath)
    $newVHDSizeBytes = 1024 * 1024 * 1024 * 20
    $memory = 1024 * 1024 * 1024 * 2
    New-VM -Name $vmName -MemoryStartupBytes $memory -SwitchName 'packer-hyperv-iso'
}

function set_boot_order
{
    param([string]$vmName)
    Set-VMBios -VMName $vmName -StartupOrder @("IDE", "CD","LegacyNetworkAdapter","Floppy")
}

function start_vm_by_name
{
    param([string]$vmName)
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm.State -eq [Microsoft.HyperV.PowerShell.VMState]::Off) {
        Start-VM -Name $vmName -Confirm:$false
    }
}

function copy_vhd_by_name
{
    param([string]$vmName, [string]$box, [string]$boxversion)
    $disk_source = get_vagrant_box_path $box $boxversion
    $disk_dest = get_vm_disk_path $vmName
    copy $disk_source $disk_dest
}

function attach_virtual_disk
{
    $disk_path = get_vm_disk_path $vmName
    Add-VMHardDiskDrive -VMName $vmName -ControllerType IDE -Path $disk_path
}

function get_vm_ip_if_exists
{
    param([string]$vmName)
    try {
      $adapter = Get-VMNetworkAdapter -VMName $vmName -ErrorAction SilentlyContinue
      $ip = $adapter.IPAddresses[0]
      if($ip -eq $null) {
        return $false
      }
    } catch {
      return $false
    }
    $ret_ip = $false
    ForEach($ipstr In $adapter.IPAddresses)
    {
      $ipaddress = [ipaddress]$ipstr
      if($ipaddress.AddressFamily -eq "InterNetwork")
      {
        $ret_ip = $ipstr
      }
    }
    $ret_ip
}

function create_vm_by_name
{
    param([string]$vmName, [string]$box, [string]$boxversion)
    copy_vhd_by_name $vmName $box $boxversion
    create_virtual_machine $vmName
    attach_virtual_disk $disk_dest
    set_boot_order $vmName
    start_vm_by_name $vmName
}

function create_vagrantfile
{
  param([string]$ip)
  $vagrantfile_path = Join-Path $HOME -ChildPath '.vagrant.d' |
                      Join-Path -ChildPath 'Vagrantfile'
  rm $vagrantfile_path
  $content = @"
Vagrant.configure("2") do |config|
  config.vm.box = "tknerr/managed-server-dummy"

  config.vm.provider :managed do |managed, override|
    managed.server = "
"@
  $content += $ip
  $content += @"
"
    override.vm.box = "tknerr/managed-server-dummy"
  end
end
"@
  Out-File -InputObject $content -FilePath $vagrantfile_path -Encoding ascii
}

create_vm_by_name $vmName $box '0'
$ip = $false
while($ip -eq $false)
{
    $ip = get_vm_ip_if_exists $vmName
    Start-Sleep -s 1
}
create_vagrantfile $ip
&{
  $VAGRANT_DEFAULT_PROVIDER = 'managed'
  $env:VAGRANT_DEFAULT_PROVIDER = 'managed'
  kitchen test $vmName
}
