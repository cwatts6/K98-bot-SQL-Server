#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$PacketRoot,[Parameter(Mandatory=$true)][string[]]$PreviousIds)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$m=Get-Content -LiteralPath (Join-Path $PacketRoot 'manifest.json') -Raw|ConvertFrom-Json
if($env:COMPUTERNAME -cne 'MINI_AMD' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'MINI_AMD\K98LabAdmin' -or $m.purpose -cne 'fresh-business-baseline-restore' -or $m.production_eligible -ne $false -or $m.vm_id -cne '2ac1b401-7076-4965-af71-de36ee0f9f9c' -or $m.guest_directory -cne $PacketRoot -or $m.fresh_database -cnotmatch '^K98_P02Business_[0-9]{17}$'){throw 'Exact isolated storage packet required'}
$continuing=($null -ne $m.PSObject.Properties['resume_storage'] -and $m.resume_storage -eq $true)
$directoryContinuing=($null -ne $m.PSObject.Properties['resume_directory'] -and $m.resume_directory -eq $true)
if($directoryContinuing -and (-not $continuing -or $m.fresh_database -cne 'K98_P02Business_20261121180254259' -or $m.volume_label -cne 'P02_BUSINESS_20261121180254259')){throw 'Exact retained formatted fixture required'}
$expected=@('60022480FF55AB6D02F41EDBFA5D57E1','60022480F18852E666A58D834543C4BC')
if($PreviousIds.Count -ne 2 -or @($PreviousIds|Where-Object {$_ -cnotin $expected}).Count){throw 'Original two guest disk identities required'}
if($m.new_disk_bytes -ne 128GB -or $m.drive_letter -cne 'R' -or $m.data_directory -cne ('R:\'+$m.fresh_database)){throw 'Exact fresh volume plan required'}
$receiptPath=Join-Path $PacketRoot 'storage-receipt.json'
if(Test-Path -LiteralPath $receiptPath){throw 'Existing storage attempt retained'}
$r=[ordered]@{schema='p02-business-storage/1';outcome='running';stage='identify newly attached raw disk';started=[datetime]::UtcNow.ToString('o');previous_ids=$PreviousIds;new_disk=$null;partition=$null;volume=$null;acl_sddl=$null;actions=@();first_failure=$null;production_operations=0;existing_disks_changed=0}
$journal=@{number=0}
function Write-NewStorage([string]$Path,[object]$Value){
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 12));$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Save-Storage { $journal.number++;if($journal.number -gt 12){throw 'Storage stage limit'};Write-NewStorage (Join-Path $PacketRoot ('storage-stage-'+$journal.number+'.json')) $r }
function Assert-NewRawDisk($All,[string[]]$Old){
 if(@($All).Count -ne 3 -or @($All|Where-Object {$_.UniqueId -cin $Old}).Count -ne 2){throw 'Only one new disk may be present'}
 $fresh=@($All|Where-Object {$_.UniqueId -cnotin $Old})
 if($fresh.Count -ne 1 -or -not $fresh[0].UniqueId -or $fresh[0].Size -ne 128GB -or [string]$fresh[0].PartitionStyle -cne 'RAW' -or $fresh[0].NumberOfPartitions -ne 0 -or $fresh[0].IsBoot -or $fresh[0].IsSystem -or $fresh[0].IsReadOnly){throw 'One new empty non-system raw disk required'}
 return $fresh[0]
}

function Require-OriginalStorageAttempt {
 $prior='Q:\P02Observer\20261121173848849'
 $pins=[ordered]@{
  'packet.zip'='87ded69266ab699eab14a5db59bfae4a668a7eabf1097f6fe36f7613e462cd0a'
  'storage-receipt.json'='5d075c4d9dcf640c0119adea479c18c29e77c16508d61ba63dc4cfa1467520e7'
  'storage-stage-1.json'='a990d33c32f360909c6c62bf113d9a7200e0136436eef2acfbbea658aeed3c2a'
  'storage-stage-2.json'='f2d308ffe8a6ddecc1a14d53802c30918128e20313294e621832035e9e98a006'
 }
 foreach($name in $pins.Keys){
  $file=Get-Item -LiteralPath (Join-Path $prior $name) -Force
  if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pins[$name]){throw 'Original stopped storage attempt differs'}
 }
 $forbidden=@('guest-receipt.json','before','after','before.stdout.txt','before.stderr.txt')
 $forbidden+=@(3..12|ForEach-Object {'storage-stage-'+$_+'.json'})
 $forbidden+=@(1..20|ForEach-Object {'restore-stage-'+$_+'.json'})
 foreach($name in $forbidden){if(Test-Path -LiteralPath (Join-Path $prior $name)){throw 'Original attempt advanced beyond its recorded boundary'}}
 $r.original_attempt=[ordered]@{directory=$prior;storage_sha256=$pins['storage-receipt.json'];initialization_replayed=$false}
}
function Assert-InitializedEmptyDisk($All,$Partitions,[string[]]$Old) {
 if(@($All).Count -ne 3 -or @($All|Where-Object {$_.UniqueId -cin $Old}).Count -ne 2){throw 'Original disks plus exact retained new disk required'}
 $fresh=@($All|Where-Object {$_.UniqueId -ceq '60022480C1862170FEFA7ABB4C6843F2'})
 if($fresh.Count -ne 1 -or $fresh[0].Size -ne 128GB -or [string]$fresh[0].PartitionStyle -cne 'GPT' -or $fresh[0].IsBoot -or $fresh[0].IsSystem -or $fresh[0].IsReadOnly -or $fresh[0].IsOffline){throw 'Retained new disk is not settled GPT storage'}
 if(@($Partitions).Count -gt 1 -or $fresh[0].NumberOfPartitions -ne @($Partitions).Count){throw 'Unexpected retained new disk partitions'}
 foreach($part in $Partitions){
  if($part.DiskNumber -ne $fresh[0].Number -or ([guid]$part.GptType).ToString() -cne 'e3c9e316-0b5c-4db8-817d-f92df00215ae' -or $part.Size -gt 128MB -or $part.Size -lt 1MB -or $part.IsBoot -or $part.IsSystem -or ([string]$part.DriveLetter).Trim([char]0).Length -ne 0 -or @($part.AccessPaths|Where-Object {$_}).Count -ne 0){throw 'Retained new disk contains an unexpected or mounted partition'}
 }
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
function Require-FormattedAttempt {
 $prior='Q:\P02Observer\20261121180254259'
 $pins=[ordered]@{
  'packet.zip'='fcfaffe3e9ae9c546a869312b05a334202f01cc41ddad0e5d0107a4ae7fe703e'
  'storage-receipt.json'='5f5cd4d21774c56ef614e5c36cf4ab4346cff03199a46601c7529eef061acb8a'
  'storage-stage-1.json'='ff1c7f60888b5a7734eb2782c0abedff1ebfdc276f8ddce318b2fb3373277229'
  'storage-stage-2.json'='66b37b2164355d216add5b1233dc457dee756628d3c310992a92ed99231d53e2'
  'storage-stage-3.json'='dfb1573502a1d6bcbc4bf15075c7d7c038994e71ea905ed4e0c1c7f5b6436693'
  'storage-stage-4.json'='45be81e89e6fbf8949541fdfcbc8fd357409af56e41ac85b81758e43146b2b8f'
  'storage-stage-5.json'='8dc3e95dcf1d22d9548548e5aff397731d90e62461c1a22e4e9c580dbb77e3ba'
  'storage-stage-6.json'='6ee2960f7efcd573579fd05c698ace88909923309e51b039e4f98aec3cc717da'
  'storage-stage-7.json'='a1e4e374cb2f997d6d094876434d5969410231f0b421a7e1989c569e8ed993ce'
  'storage-stage-8.json'='e7a78249aac77fb1c61879457f52b499a3fef8afb857e3b2e4e4c878cf4ca44f'
  'storage-stage-9.json'='283faa42edd3de3c685b928e76ad2e2e4fa3b3e9314c6f6e5e497c71b0edb3fb'
 }
 foreach($name in $pins.Keys){
  $file=Get-Item -LiteralPath (Join-Path $prior $name) -Force
  if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pins[$name]){throw 'Exact completed format attempt required'}
 }
 $forbidden=@('guest-receipt.json','before','after','before.stdout.txt','before.stderr.txt')
 $forbidden+=@(10..12|ForEach-Object {'storage-stage-'+$_+'.json'})
 $forbidden+=@(1..20|ForEach-Object {'restore-stage-'+$_+'.json'})
 foreach($name in $forbidden){if(Test-Path -LiteralPath (Join-Path $prior $name)){throw 'Original formatted attempt advanced beyond recorded failure'}}
 $r.original_formatted_attempt=[ordered]@{directory=$prior;receipt_sha256=$pins['storage-receipt.json'];storage_setup_replayed=$false;acl_rewritten=$false}
}
function Assert-RetainedFormattedStorage($All,$Partition,$Volume,[string[]]$Old) {
 if(@($All).Count -ne 3 -or @($All|Where-Object {$_.UniqueId -cin $Old}).Count -ne 2){throw 'Exact three retained disks required'}
 $disk=@($All|Where-Object {$_.UniqueId -ceq '60022480C1862170FEFA7ABB4C6843F2'})
 if($disk.Count -ne 1 -or $disk[0].Size -ne 128GB -or [string]$disk[0].PartitionStyle -cne 'GPT' -or $disk[0].NumberOfPartitions -ne 2 -or $disk[0].IsBoot -or $disk[0].IsSystem -or $disk[0].IsReadOnly -or $disk[0].IsOffline){throw 'Retained formatted disk changed'}
 if(@($Partition).Count -ne 1 -or $Partition.DiskNumber -ne $disk[0].Number -or $Partition.PartitionNumber -ne 2 -or ([guid]$Partition.Guid).ToString() -cne 'fa4c5920-80fb-4206-ab7d-88f12cb600ff' -or $Partition.DriveLetter -cne 'R' -or $Partition.Size -ne 137421127680){throw 'Retained R partition changed'}
 if(@($Volume).Count -ne 1 -or $Volume.UniqueId -ine '\\?\Volume{fa4c5920-80fb-4206-ab7d-88f12cb600ff}\' -or $Volume.FileSystemLabel -cne 'P02_BUSINESS_20261121180254259' -or $Volume.FileSystem -cne 'NTFS' -or $Volume.Size -ne 137421062144 -or $Volume.SizeRemaining -lt 120GB){throw 'Retained formatted volume changed'}
 return $disk[0]
}

Save-Storage
try{
 if($directoryContinuing){
  Require-FormattedAttempt
  $r.stage='reconcile retained formatted disk and volume';Save-Storage
  $all=@(Get-Disk);$partition=Get-Partition -DriveLetter R;$volume=Get-Volume -Partition $partition
  $r.observed_retained_disks=@($all|Select-Object UniqueId,Number,Size,PartitionStyle,NumberOfPartitions,IsBoot,IsSystem,IsOffline,IsReadOnly)
  $r.observed_retained_partition=@($partition|Select-Object DiskNumber,PartitionNumber,Guid,DriveLetter,Size)
  $r.observed_retained_volume=@($volume|Select-Object UniqueId,DriveLetter,FileSystem,FileSystemLabel,Size,SizeRemaining)
  Save-Storage
  $disk=Assert-RetainedFormattedStorage $all $partition $volume $PreviousIds
  $r.new_disk=[ordered]@{unique_id=$disk.UniqueId;number=$disk.Number;bytes=$disk.Size}
  $r.partition=[ordered]@{guid=[string]$partition.Guid;number=$partition.PartitionNumber;disk_number=$partition.DiskNumber;bytes=$partition.Size}
  $r.volume=[ordered]@{unique_id=$volume.UniqueId;label=$volume.FileSystemLabel;filesystem=$volume.FileSystem;bytes=$volume.Size;free_bytes=$volume.SizeRemaining}
  $r.actions+=@([ordered]@{operation='reuse completed formatted storage without replay';acknowledged=$true})
 }else{
 if(Test-Path -LiteralPath 'R:\'){throw 'R drive already exists'}
 if($continuing){
  Require-OriginalStorageAttempt
  $r.stage='reconcile retained initialized disk';Save-Storage
  Update-HostStorageCache
  $all=@(Get-Disk)
  $candidate=@($all|Where-Object {$_.UniqueId -ceq '60022480C1862170FEFA7ABB4C6843F2'})
  if($candidate.Count -ne 1){throw 'Exact retained disk identity missing'}
  $parts=@(Get-Partition|Where-Object {$_.DiskNumber -eq $candidate[0].Number})
  $r.observed_disk=@($candidate|Select-Object UniqueId,Number,Size,PartitionStyle,NumberOfPartitions,IsBoot,IsSystem,IsOffline,IsReadOnly)
  $r.observed_partitions=@($parts|Select-Object DiskNumber,PartitionNumber,Guid,GptType,Size,DriveLetter,AccessPaths,IsBoot,IsSystem)
  Save-Storage
  $disk=Assert-InitializedEmptyDisk $all $parts $PreviousIds
  $r.new_disk=[ordered]@{unique_id=$disk.UniqueId;number=$disk.Number;bytes=$disk.Size}
  $r.actions+=@([ordered]@{operation='reconcile completed initialization without replay';acknowledged=$true})
  Save-Storage
 }else{
 Update-HostStorageCache
 $watch=[Diagnostics.Stopwatch]::StartNew()
 do{$all=@(Get-Disk);if($all.Count -ne 2){break};Start-Sleep -Milliseconds 250}while($watch.Elapsed.TotalSeconds -lt 20)
 $disk=Assert-NewRawDisk $all $PreviousIds
 $r.new_disk=[ordered]@{unique_id=$disk.UniqueId;number=$disk.Number;bytes=$disk.Size}
 if($disk.IsOffline){$r.stage='online only new raw disk';Save-Storage;Set-Disk -InputObject $disk -IsOffline $false}
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
 }
 if(Test-Path -LiteralPath 'R:\'){throw 'R became occupied'}
 $r.stage='create new R partition';$r.actions+=@([ordered]@{operation='partition';acknowledged=$false});Save-Storage
 $partitionResult=New-Partition -InputObject $disk -UseMaximumSize -DriveLetter R
 $r.partition_result=@($partitionResult|Select-Object DiskNumber,PartitionNumber,Guid,DriveLetter,Size)
 $partition=Get-Partition -DiskNumber $disk.Number -PartitionNumber $partitionResult.PartitionNumber
 if(@($partition).Count -ne 1 -or [string]$partition.Guid -cne [string]$partitionResult.Guid){throw 'Created partition readback differs'}
 $check=Get-Disk -Number $partition.DiskNumber
 if($check.UniqueId -cne $r.new_disk.unique_id -or $partition.DriveLetter -cne 'R' -or $partition.Size -lt 127GB){throw 'New partition ownership differs'}
 $r.partition=[ordered]@{guid=[string]$partition.Guid;number=$partition.PartitionNumber;disk_number=$partition.DiskNumber;bytes=$partition.Size}
 $r.actions[-1].acknowledged=$true;Save-Storage
 $r.stage='format only new partition';$r.actions+=@([ordered]@{operation='format';acknowledged=$false});Save-Storage
 $formatResult=Format-Volume -Partition $partition -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $m.volume_label -Confirm:$false
 $r.format_result=@($formatResult|Select-Object UniqueId,DriveLetter,FileSystem,FileSystemLabel,Size,SizeRemaining)
 $volume=Get-Volume -Partition $partition
 if(@($volume).Count -ne 1){throw 'Exactly one new partition volume required'}
 if($volume.DriveLetter -cne 'R' -or $volume.FileSystem -cne 'NTFS' -or $volume.FileSystemLabel -cne $m.volume_label -or $volume.SizeRemaining -lt 120GB){throw 'New volume acknowledgement differs'}
 $r.volume=[ordered]@{unique_id=$volume.UniqueId;label=$volume.FileSystemLabel;filesystem=$volume.FileSystem;bytes=$volume.Size;free_bytes=$volume.SizeRemaining}
 $r.actions[-1].acknowledged=$true;Save-Storage
 }
 $r.stage='protect fresh SQL file directory';Save-Storage
 if($directoryContinuing){
  $directory=Get-Item -LiteralPath $m.data_directory -Force
  if(-not $directory.PSIsContainer -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -or @(Get-ChildItem -LiteralPath $directory.FullName -Force).Count){throw 'Exact empty ordinary retained SQL directory required'}
 }else{
  if(Test-Path -LiteralPath $m.data_directory){throw 'Fresh data directory already exists'}
  $directory=[IO.Directory]::CreateDirectory($m.data_directory)
 }
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
 if(-not $directoryContinuing){Set-Acl -LiteralPath $directory.FullName -AclObject $acl}
 $actual=Get-Acl -LiteralPath $directory.FullName
 $r.acl_expected=Get-PermissionFacts $acl;$r.acl_observed=Get-PermissionFacts $actual
 $r.acl_expected_sddl=$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
 $r.acl_observed_sddl=$actual.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access)
 Save-Storage
 Assert-DirectoryPermissions $actual $acl
 $r.acl_sddl=$actual.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All)
 $r.directory=$directory.FullName
 $r.outcome='passed';$r.stage='new private volume and SQL directory ready';Save-Storage
}catch{$r.outcome='failed';$r.first_failure=[ordered]@{stage=$r.stage;type=$_.Exception.GetType().FullName;detail=$_.Exception.Message}}
finally{$r.finished=[datetime]::UtcNow.ToString('o');Write-NewStorage $receiptPath $r}
[pscustomobject]@{outcome=$r.outcome;receipt=$receiptPath;sha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()}
