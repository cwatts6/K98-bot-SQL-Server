#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$PacketRoot,[Parameter(Mandatory=$true)][string[]]$PreviousIds)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$m=Get-Content -LiteralPath (Join-Path $PacketRoot 'manifest.json') -Raw|ConvertFrom-Json
$stamp=Split-Path -Leaf $PacketRoot
if($env:COMPUTERNAME -cne 'MINI_AMD' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'MINI_AMD\K98LabAdmin' -or $m.purpose -cne 'p02-matching-cost-fixtures' -or $m.production_eligible -ne $false -or $m.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $PacketRoot -cne $m.guest_directory -or $PacketRoot -cnotmatch '^Q:\\P02Observer\\[0-9]{17}$' -or $m.volume_label -cne ('P02_COST_'+$stamp)){throw 'Exact isolated cost storage packet required'}
$expected=@('60022480FF55AB6D02F41EDBFA5D57E1','60022480F18852E666A58D834543C4BC','60022480C1862170FEFA7ABB4C6843F2')
if($PreviousIds.Count -ne 3 -or @($PreviousIds|Select-Object -Unique).Count -ne 3 -or @($PreviousIds|Where-Object {$_ -cnotin $expected}).Count){throw 'Exact three retained disk identities required'}
if($m.new_disk_bytes -ne 256GB -or $m.drive_letter -cne 'S' -or $m.data_directory -cne ('S:\P02Cost_'+$stamp)){throw 'Exact new cost volume required'}
foreach($item in $m.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $PacketRoot $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $item.Value){throw 'Sealed storage member differs'}}
$receiptPath=Join-Path $PacketRoot 'storage-receipt.json'
if((Test-Path -LiteralPath $receiptPath) -or (Test-Path -LiteralPath (Join-Path $PacketRoot 'storage-stage-1.json'))){throw 'Existing storage attempt retained; do not replay'}
$r=[ordered]@{schema='p02-cost-storage/1';outcome='running';stage='identify new raw disk';started=[datetime]::UtcNow.ToString('o');previous_ids=$PreviousIds;new_disk=$null;partition=$null;volume=$null;actions=@();first_failure=$null;production_operations=0;existing_disks_changed=0}
$journal=@{number=0}
function Write-NewStorage([string]$Path,[object]$Value){
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 12));$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-Storage { $journal.number++;if($journal.number -gt 16){throw 'Storage stage limit'};Write-NewStorage (Join-Path $PacketRoot ('storage-stage-'+$journal.number+'.json')) $r }
function Assert-NewRawDisk($All,[string[]]$Old){
 if(@($All).Count -ne 4 -or @($All|Where-Object {$_.UniqueId -cin $Old}).Count -ne 3){throw 'Only one new disk may be present'}
 $fresh=@($All|Where-Object {$_.UniqueId -cnotin $Old})
 if($fresh.Count -ne 1 -or -not $fresh[0].UniqueId -or $fresh[0].Size -ne 256GB -or [string]$fresh[0].PartitionStyle -cne 'RAW' -or $fresh[0].NumberOfPartitions -ne 0 -or $fresh[0].IsBoot -or $fresh[0].IsSystem -or $fresh[0].IsReadOnly){throw 'One new empty non-system raw disk required'}
 return $fresh[0]
}

function Get-PermissionFacts($Acl) {
 $rules=@($Acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])|ForEach-Object {
  [pscustomobject][ordered]@{sid=$_.IdentityReference.Value;rights=[int]$_.FileSystemRights;type=[int]$_.AccessControlType;inheritance=[int]$_.InheritanceFlags;propagation=[int]$_.PropagationFlags;inherited=[bool]$_.IsInherited}
 }|Sort-Object sid,rights,type,inheritance,propagation,inherited)
 return [pscustomobject][ordered]@{owner=$Acl.GetOwner([Security.Principal.SecurityIdentifier]).Value;protected=[bool]$Acl.AreAccessRulesProtected;canonical=[bool]$Acl.AreAccessRulesCanonical;rules=$rules}
}
function Assert-DirectoryPermissions($Actual,$Expected) {
 $observed=Get-PermissionFacts $Actual;$wanted=Get-PermissionFacts $Expected
 if(-not $observed.protected -or -not $observed.canonical -or ($observed|ConvertTo-Json -Depth 8 -Compress) -cne ($wanted|ConvertTo-Json -Depth 8 -Compress)){throw 'Fresh directory permission rules or owner differ'}
}
Save-Storage
try{
 if(Test-Path -LiteralPath 'S:\'){throw 'S drive already exists'}
 Update-HostStorageCache
 $watch=[Diagnostics.Stopwatch]::StartNew()
 do{$all=@(Get-Disk);if($all.Count -ne 3){break};Start-Sleep -Milliseconds 250}while($watch.Elapsed.TotalSeconds -lt 20)
 $disk=Assert-NewRawDisk $all $PreviousIds
 $r.new_disk=[ordered]@{unique_id=$disk.UniqueId;number=$disk.Number;bytes=$disk.Size}
 if($disk.IsOffline){$r.stage='online only new raw disk';$r.actions+=@([ordered]@{operation='online';acknowledged=$false});Save-Storage;Set-Disk -InputObject $disk -IsOffline $false;$r.actions[-1].acknowledged=$true;Save-Storage}
 $disk=Get-Disk -UniqueId $r.new_disk.unique_id
 $null=Assert-NewRawDisk @(Get-Disk) $PreviousIds
 $r.stage='initialize new disk';$r.actions+=@([ordered]@{operation='initialize';acknowledged=$false});Save-Storage
 $initializer=Initialize-Disk -InputObject $disk -PartitionStyle GPT -PassThru
 $r.initializer_result=@($initializer|Select-Object UniqueId,Number,PartitionStyle,Size)
 Update-Disk -UniqueId $r.new_disk.unique_id
 $disk=Get-Disk -UniqueId $r.new_disk.unique_id
 $r.initialized_read=@($disk|Select-Object UniqueId,Number,PartitionStyle,Size)
 if($disk.UniqueId -cne $r.new_disk.unique_id -or [string]$disk.PartitionStyle -cne 'GPT'){throw 'Initialized disk identity differs'}
 $r.actions[-1].acknowledged=$true;Save-Storage
 if(Test-Path -LiteralPath 'S:\'){throw 'S became occupied'}
 $r.stage='create new S partition';$r.actions+=@([ordered]@{operation='partition';acknowledged=$false});Save-Storage
 $partitionResult=New-Partition -InputObject $disk -UseMaximumSize -DriveLetter S
 $r.partition_result=@($partitionResult|Select-Object DiskNumber,PartitionNumber,Guid,DriveLetter,Size)
 $partition=Get-Partition -DiskNumber $disk.Number -PartitionNumber $partitionResult.PartitionNumber
 if(@($partition).Count -ne 1 -or [string]$partition.Guid -cne [string]$partitionResult.Guid){throw 'Created partition readback differs'}
 $check=Get-Disk -Number $partition.DiskNumber
 if($check.UniqueId -cne $r.new_disk.unique_id -or $partition.DriveLetter -cne 'S' -or $partition.Size -lt 255GB){throw 'New partition ownership differs'}
 $r.partition=[ordered]@{guid=[string]$partition.Guid;number=$partition.PartitionNumber;disk_number=$partition.DiskNumber;bytes=$partition.Size}
 $r.actions[-1].acknowledged=$true;Save-Storage
 $r.stage='format only new partition';$r.actions+=@([ordered]@{operation='format';acknowledged=$false});Save-Storage
 $formatResult=Format-Volume -Partition $partition -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $m.volume_label -Confirm:$false
 $r.format_result=@($formatResult|Select-Object UniqueId,DriveLetter,FileSystem,FileSystemLabel,Size,SizeRemaining)
 $volume=Get-Volume -Partition $partition
 if(@($volume).Count -ne 1){throw 'Exactly one new partition volume required'}
 if($volume.DriveLetter -cne 'S' -or $volume.FileSystem -cne 'NTFS' -or $volume.FileSystemLabel -cne $m.volume_label -or $volume.SizeRemaining -lt 250GB){throw 'New volume acknowledgement differs'}
 $r.volume=[ordered]@{unique_id=$volume.UniqueId;label=$volume.FileSystemLabel;filesystem=$volume.FileSystem;bytes=$volume.Size;free_bytes=$volume.SizeRemaining}
 $r.actions[-1].acknowledged=$true;Save-Storage
 $r.stage='protect only new SQL file directory';$r.actions+=@([ordered]@{operation='create and protect new directory';acknowledged=$false});Save-Storage
 if(Test-Path -LiteralPath $m.data_directory){throw 'New data directory already exists'}
 $directory=[IO.Directory]::CreateDirectory($m.data_directory)
 $acl=[Security.AccessControl.DirectorySecurity]::new()
 $acl.SetAccessRuleProtection($true,$false)
 $inherit=[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
 $prop=[Security.AccessControl.PropagationFlags]::None
 $allow=[Security.AccessControl.AccessControlType]::Allow
 $system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18')
 $admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
 $sql=([Security.Principal.NTAccount]::new('NT SERVICE\MSSQLSERVER')).Translate([Security.Principal.SecurityIdentifier])
 $acl.SetOwner($admins)
 foreach($sid in @($system,$admins)){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$prop,$allow))}
 $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sql,[Security.AccessControl.FileSystemRights]::Modify,$inherit,$prop,$allow))
 Set-Acl -LiteralPath $directory.FullName -AclObject $acl
 $actual=Get-Acl -LiteralPath $directory.FullName
 $r.acl_expected=Get-PermissionFacts $acl;$r.acl_observed=Get-PermissionFacts $actual
 $r.acl_expected_sddl=$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
 $r.acl_observed_sddl=$actual.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
 Save-Storage
 Assert-DirectoryPermissions $actual $acl
 $r.acl_sddl=$actual.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All)
 $r.directory=$directory.FullName
 $r.actions[-1].acknowledged=$true
 $r.outcome='passed';$r.stage='new private volume and SQL directory ready';Save-Storage
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}
finally{$r.finished=[datetime]::UtcNow.ToString('o');Write-NewStorage $receiptPath $r}
[pscustomobject]@{outcome=$r.outcome;receipt=$receiptPath;sha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()}
