# Test-only named child: pause the real release runner after a fixed DDL batch.
# The parent owns this process handle and kills it only under explicit fault approval.
param(
    [Parameter(Mandatory=$true)][string]$ProfilePath,
    [Parameter(Mandatory=$true)][string]$ProfileSHA256,
    [Parameter(Mandatory=$true)][string]$ExpectedCommit,
    [Parameter(Mandatory=$true)][string]$ReleaseId,
    [Parameter(Mandatory=$true)][string]$ExpectedLogin,
    [Parameter(Mandatory=$true)][ValidateRange(1,4)][int]$Boundary
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:K98_MGE_APPROVED_TARGET -cnotmatch '^9SX2VF4\\K98DEV\|K98_MGE_Finalisation_Qualification_20261029_A\|[a-f0-9]{64}\z'){
    throw 'Explicit fixed disposable target approval required'
}
. "$PSScriptRoot\..\deploy\SqlDeploy.ModuleRelease.ps1"
$loaded=Read-K98ModuleProfile $ProfilePath $ProfileSHA256 '20261029_001_mge_board_finalisation'
$script:Commands=@($loaded.Commands)
$script:Boundary=$Boundary
$script:Count=0
$script:ExpectedLogin=$ExpectedLogin
$script:OriginalQuery=${function:Invoke-K98ModuleQuery}
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
    if($script:Commands -ccontains $Sql -or $Sql.StartsWith('INSERT dbo.DeploymentRunHistory')){
        $identity=& $script:OriginalQuery $Connection $Transaction "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server,DB_NAME() AS db,ORIGINAL_LOGIN() AS login;"
        if($identity.Count -ne 1 -or $identity[0].server -cne '9SX2VF4\K98DEV' -or $identity[0].db -cne 'K98_MGE_Finalisation_Qualification_20261029_A' -or $identity[0].login -cne $script:ExpectedLogin){throw 'Fixture identity differs'}
    }
    $result=& $script:OriginalQuery $Connection $Transaction $Sql $Values
    if($script:Commands -ccontains $Sql){
        $script:Count++
        if($script:Count -eq $script:Boundary){
            [Console]::WriteLine('BOUNDARY:'+ $script:Boundary)
            [Console]::Out.Flush()
            $null=[Console]::ReadLine()
            throw 'Fault boundary released without termination'
        }
    }
    return ,$result
}
$null=Invoke-K98ModuleRelease 'lpc:localhost\K98DEV' 'K98_MGE_Finalisation_Qualification_20261029_A' '20261029_001_mge_board_finalisation' $ProfilePath $ProfileSHA256 $ExpectedCommit $ReleaseId 'Apply'
throw 'Fixture runner unexpectedly passed interruption boundary'
