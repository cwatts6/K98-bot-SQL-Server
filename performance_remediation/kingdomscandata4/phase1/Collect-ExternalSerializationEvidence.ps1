[CmdletBinding()]
param(
    [string] $BotRoot = 'C:\discord_file_downloader',

    [ValidateRange(100, 20000)]
    [int] $MaximumStaticMatches = 5000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Read-only collector. The JSON output can contain command lines, service
# accounts, paths, and source excerpts. Retain raw output outside Git.

$collectionErrors = [System.Collections.Generic.List[object]]::new()
$scheduledTasks = [System.Collections.Generic.List[object]]::new()
$taskActions = [System.Collections.Generic.List[object]]::new()
$taskTriggers = [System.Collections.Generic.List[object]]::new()
$services = [System.Collections.Generic.List[object]]::new()
$processes = [System.Collections.Generic.List[object]]::new()
$startupCommands = [System.Collections.Generic.List[object]]::new()
$staticMatches = [System.Collections.Generic.List[object]]::new()
$lockArtifacts = [System.Collections.Generic.List[object]]::new()

function Add-CollectionError {
    param(
        [string] $Section,
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $collectionErrors.Add([pscustomobject]@{
        EvidenceSection = $Section
        ExceptionType = $ErrorRecord.Exception.GetType().FullName
        Message = $ErrorRecord.Exception.Message
    })
}

function Get-TextSha256 {
    param([AllowEmptyString()][string] $Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString(
            $sha.ComputeHash($bytes)
        ).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-PropertyValue {
    param(
        [AllowNull()][object] $InputObject,
        [string] $PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Convert-PropertyBag {
    param(
        [AllowNull()][object] $InputObject,
        [string[]] $PropertyNames
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $bag = [ordered]@{}
    foreach ($name in $PropertyNames) {
        $property = $InputObject.PSObject.Properties[$name]
        if ($null -eq $property -or $null -eq $property.Value) {
            continue
        }

        $value = $property.Value
        if (
            $value -is [string] -or
            $value -is [ValueType]
        ) {
            $bag[$name] = $value
        }
        else {
            $bag[$name] = $value | ConvertTo-Json -Compress -Depth 5
        }
    }
    return [pscustomobject]$bag
}

$resolvedBotRoot = [System.IO.Path]::GetFullPath($BotRoot)
$botRootExists = Test-Path -LiteralPath $resolvedBotRoot -PathType Container
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole(
    [System.Security.Principal.WindowsBuiltInRole]::Administrator
)
$scriptHash = if ($PSCommandPath) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash
}
else {
    $null
}

$escapedBotRoot = [regex]::Escape($resolvedBotRoot)
$operationalPattern = [regex]::new(
    "(?i)($escapedBotRoot|discord_file_downloader|UPDATE_ALL2|" +
    'IMPORT_STAGING|KingdomScanData4|stats\.csv|Import_Archive|' +
    'ROK_TRACKER|kingdom.?scan|stats.?import|file.?download)'
)

try {
    foreach ($task in Get-ScheduledTask -ErrorAction Stop) {
        $actionText = @(
            foreach ($action in $task.Actions) {
                '{0} {1} {2}' -f (
                    (Get-PropertyValue $action 'Execute'),
                    (Get-PropertyValue $action 'Arguments'),
                    (Get-PropertyValue $action 'WorkingDirectory')
                )
            }
        ) -join ' '
        $candidateText = '{0} {1} {2}' -f (
            $task.TaskPath,
            $task.TaskName,
            $actionText
        )

        if (-not $operationalPattern.IsMatch($candidateText)) {
            continue
        }

        $taskInfo = $null
        $definitionHash = $null
        try {
            $taskInfo = Get-ScheduledTaskInfo -InputObject $task -ErrorAction Stop
        }
        catch {
            Add-CollectionError -Section (
                "scheduled_task_info:$($task.TaskPath)$($task.TaskName)"
            ) -ErrorRecord $_
        }
        try {
            $taskXml = Export-ScheduledTask `
                -TaskName $task.TaskName `
                -TaskPath $task.TaskPath `
                -ErrorAction Stop
            $definitionHash = Get-TextSha256 -Text $taskXml
        }
        catch {
            Add-CollectionError -Section (
                "scheduled_task_definition:$($task.TaskPath)$($task.TaskName)"
            ) -ErrorRecord $_
        }

        $scheduledTasks.Add([pscustomobject]@{
            EvidenceSection = 'windows_scheduled_tasks'
            TaskPath = $task.TaskPath
            TaskName = $task.TaskName
            State = [string]$task.State
            Enabled = Get-PropertyValue $task.Settings 'Enabled'
            Author = Get-PropertyValue $task 'Author'
            Description = Get-PropertyValue $task 'Description'
            PrincipalUserId = Get-PropertyValue $task.Principal 'UserId'
            PrincipalLogonType = [string](
                Get-PropertyValue $task.Principal 'LogonType'
            )
            PrincipalRunLevel = [string](
                Get-PropertyValue $task.Principal 'RunLevel'
            )
            MultipleInstances = [string](
                Get-PropertyValue $task.Settings 'MultipleInstances'
            )
            AllowDemandStart = Get-PropertyValue `
                $task.Settings 'AllowDemandStart'
            StartWhenAvailable = Get-PropertyValue `
                $task.Settings 'StartWhenAvailable'
            ExecutionTimeLimit = [string](
                Get-PropertyValue $task.Settings 'ExecutionTimeLimit'
            )
            RestartCount = Get-PropertyValue $task.Settings 'RestartCount'
            RestartInterval = [string](
                Get-PropertyValue $task.Settings 'RestartInterval'
            )
            LastRunTime = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
            LastTaskResult = if ($taskInfo) {
                $taskInfo.LastTaskResult
            }
            else {
                $null
            }
            NextRunTime = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
            NumberOfMissedRuns = if ($taskInfo) {
                $taskInfo.NumberOfMissedRuns
            }
            else {
                $null
            }
            DefinitionSha256 = $definitionHash
        })

        $actionNumber = 0
        foreach ($action in $task.Actions) {
            $actionNumber++
            $taskActions.Add([pscustomobject]@{
                EvidenceSection = 'windows_scheduled_task_actions'
                TaskPath = $task.TaskPath
                TaskName = $task.TaskName
                ActionNumber = $actionNumber
                ActionType = $action.CimClass.CimClassName
                Execute = Get-PropertyValue $action 'Execute'
                Arguments = Get-PropertyValue $action 'Arguments'
                WorkingDirectory = Get-PropertyValue `
                    $action 'WorkingDirectory'
            })
        }

        $triggerNumber = 0
        foreach ($trigger in $task.Triggers) {
            $triggerNumber++
            $taskTriggers.Add([pscustomobject]@{
                EvidenceSection = 'windows_scheduled_task_triggers'
                TaskPath = $task.TaskPath
                TaskName = $task.TaskName
                TriggerNumber = $triggerNumber
                TriggerType = $trigger.CimClass.CimClassName
                Trigger = Convert-PropertyBag `
                    -InputObject $trigger `
                    -PropertyNames @(
                        'Enabled',
                        'StartBoundary',
                        'EndBoundary',
                        'Delay',
                        'RandomDelay',
                        'ExecutionTimeLimit',
                        'DaysInterval',
                        'WeeksInterval',
                        'DaysOfWeek',
                        'DaysOfMonth',
                        'MonthsOfYear',
                        'WeeksOfMonth',
                        'UserId',
                        'Subscription',
                        'Repetition'
                    )
            })
        }
    }
}
catch {
    Add-CollectionError -Section 'windows_scheduled_tasks' -ErrorRecord $_
}

try {
    foreach (
        $service in Get-CimInstance -ClassName Win32_Service -ErrorAction Stop
    ) {
        $candidateText = '{0} {1} {2}' -f (
            $service.Name,
            $service.DisplayName,
            $service.PathName
        )
        if (-not $operationalPattern.IsMatch($candidateText)) {
            continue
        }

        $services.Add([pscustomobject]@{
            EvidenceSection = 'windows_services'
            Name = $service.Name
            DisplayName = $service.DisplayName
            State = $service.State
            StartMode = $service.StartMode
            StartName = $service.StartName
            ProcessId = $service.ProcessId
            PathName = $service.PathName
            ExitCode = $service.ExitCode
        })
    }
}
catch {
    Add-CollectionError -Section 'windows_services' -ErrorRecord $_
}

try {
    foreach (
        $process in Get-CimInstance -ClassName Win32_Process -ErrorAction Stop
    ) {
        $candidateText = '{0} {1} {2}' -f (
            $process.Name,
            $process.ExecutablePath,
            $process.CommandLine
        )
        if (-not $operationalPattern.IsMatch($candidateText)) {
            continue
        }

        $processes.Add([pscustomobject]@{
            EvidenceSection = 'matching_running_processes'
            ProcessId = $process.ProcessId
            ParentProcessId = $process.ParentProcessId
            Name = $process.Name
            CreationDate = $process.CreationDate
            ExecutablePath = $process.ExecutablePath
            CommandLine = $process.CommandLine
        })
    }
}
catch {
    Add-CollectionError -Section 'matching_running_processes' -ErrorRecord $_
}

$runKeyPaths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($runKeyPath in $runKeyPaths) {
    try {
        if (-not (Test-Path -LiteralPath $runKeyPath)) {
            continue
        }
        $properties = Get-ItemProperty -LiteralPath $runKeyPath -ErrorAction Stop
        foreach ($property in $properties.PSObject.Properties) {
            if ($property.Name -like 'PS*' -or $null -eq $property.Value) {
                continue
            }
            $command = [string]$property.Value
            if (-not $operationalPattern.IsMatch($command)) {
                continue
            }
            $startupCommands.Add([pscustomobject]@{
                EvidenceSection = 'windows_run_startup_commands'
                RegistryPath = $runKeyPath
                ValueName = $property.Name
                Command = $command
            })
        }
    }
    catch {
        Add-CollectionError -Section "startup_commands:$runKeyPath" `
            -ErrorRecord $_
    }
}

$gitEvidence = [ordered]@{
    RepositoryPresent = $false
    Head = $null
    Branch = $null
    Status = @()
    Error = $null
}

if ($botRootExists -and (Test-Path -LiteralPath (Join-Path $resolvedBotRoot '.git'))) {
    $gitEvidence.RepositoryPresent = $true
    try {
        $gitEvidence.Head = (
            & git -C $resolvedBotRoot rev-parse HEAD 2>&1
        ) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            throw "git rev-parse failed with exit code $LASTEXITCODE."
        }
        $gitEvidence.Branch = (
            & git -C $resolvedBotRoot branch --show-current 2>&1
        ) -join "`n"
        if ($LASTEXITCODE -ne 0) {
            throw "git branch failed with exit code $LASTEXITCODE."
        }
        $gitEvidence.Status = @(
            & git -C $resolvedBotRoot status --short 2>&1
        )
        if ($LASTEXITCODE -ne 0) {
            throw "git status failed with exit code $LASTEXITCODE."
        }
    }
    catch {
        $gitEvidence.Error = $_.Exception.Message
        Add-CollectionError -Section 'bot_git_context' -ErrorRecord $_
    }
}

if ($botRootExists) {
    $sourceExtensions = @(
        '.py',
        '.ps1',
        '.psm1',
        '.bat',
        '.cmd',
        '.json',
        '.toml',
        '.yaml',
        '.yml',
        '.ini',
        '.cfg'
    )
    $excludedPathPattern =
        '(?i)\\(\.git|\.venv|venv|__pycache__|node_modules|' +
        'downloads|downloads_test|Import_Archive|evidence|logs?|cache)\\'
    $sourcePattern = @(
        'UPDATE_ALL2',
        'IMPORT_STAGING_PROC',
        'stats\.csv',
        'Import_Archive',
        'downloads_test',
        '(?i)singleton',
        '(?i)mutex',
        '(?i)lockfile',
        '(?i)filelock',
        '(?i)pidfile',
        '(?i)portalocker',
        '(?i)fasteners',
        '(?i)InterProcessLock',
        '(?i)CreateMutex',
        '(?i)O_EXCL',
        '(?i)msvcrt\.(locking|LK_)',
        '(?i)fcntl\.flock',
        '(?i)(asyncio|threading)\.Lock',
        '(?i)schtasks',
        '(?i)ScheduledTask',
        '(?i)APScheduler',
        '(?i)schedule\.(every|run_pending)',
        '(?i)tasks\.loop',
        '(?i)cron'
    )

    try {
        $sourceFiles = Get-ChildItem `
            -LiteralPath $resolvedBotRoot `
            -Recurse `
            -File `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Extension -in $sourceExtensions -and
                $_.FullName -notmatch $excludedPathPattern
            }

        foreach ($sourceFile in $sourceFiles) {
            if ($staticMatches.Count -ge $MaximumStaticMatches) {
                break
            }
            try {
                foreach (
                    $match in Select-String `
                        -LiteralPath $sourceFile.FullName `
                        -Pattern $sourcePattern `
                        -AllMatches `
                        -ErrorAction Stop
                ) {
                    if ($staticMatches.Count -ge $MaximumStaticMatches) {
                        break
                    }
                    $staticMatches.Add([pscustomobject]@{
                        EvidenceSection = 'bot_serialization_static_matches'
                        Path = $sourceFile.FullName
                        LineNumber = $match.LineNumber
                        Line = $match.Line.Trim()
                    })
                }
            }
            catch {
                Add-CollectionError `
                    -Section "bot_static_search:$($sourceFile.FullName)" `
                    -ErrorRecord $_
            }
        }

        foreach (
            $artifact in Get-ChildItem `
                -LiteralPath $resolvedBotRoot `
                -Recurse `
                -File `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -notmatch $excludedPathPattern -and
                    (
                        $_.Extension -in @('.lock', '.lck', '.pid') -or
                        $_.Name -match '(?i)(singleton|mutex|lockfile|pidfile)'
                    )
                }
        ) {
            $lockArtifacts.Add([pscustomobject]@{
                EvidenceSection = 'bot_lock_artifacts'
                Path = $artifact.FullName
                Length = $artifact.Length
                CreationTimeUtc = $artifact.CreationTimeUtc
                LastWriteTimeUtc = $artifact.LastWriteTimeUtc
                Sha256 = (Get-FileHash `
                    -Algorithm SHA256 `
                    -LiteralPath $artifact.FullName).Hash
            })
        }
    }
    catch {
        Add-CollectionError -Section 'bot_filesystem_search' -ErrorRecord $_
    }
}
else {
    $collectionErrors.Add([pscustomobject]@{
        EvidenceSection = 'bot_repository'
        ExceptionType = 'DirectoryNotFound'
        Message = "Bot root does not exist: $resolvedBotRoot"
    })
}

$result = [ordered]@{
    CollectionContext = [ordered]@{
        EvidenceSection = 'external_serialization_context'
        CollectorRevision = '20260724.1'
        ComputerName = $env:COMPUTERNAME
        UserName = $identity.Name
        IsAdministrator = $isAdministrator
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        BotRoot = $resolvedBotRoot
        BotRootExists = $botRootExists
        ScriptSha256 = $scriptHash
        MaximumStaticMatches = $MaximumStaticMatches
        StaticMatchLimitReached = (
            $staticMatches.Count -ge $MaximumStaticMatches
        )
        CollectedAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    BotGitContext = $gitEvidence
    ScheduledTasks = @($scheduledTasks)
    ScheduledTaskActions = @($taskActions)
    ScheduledTaskTriggers = @($taskTriggers)
    WindowsServices = @($services)
    MatchingRunningProcesses = @($processes)
    WindowsRunStartupCommands = @($startupCommands)
    BotSerializationStaticMatches = @($staticMatches)
    BotLockArtifacts = @($lockArtifacts)
    CollectionErrors = @($collectionErrors)
}

$result | ConvertTo-Json -Depth 10
