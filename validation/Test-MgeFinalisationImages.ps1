param([Parameter(Mandatory=$true)][string]$ProfilePath,[Parameter(Mandatory=$true)][string]$ExpectedLogin)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:K98_MGE_APPROVED_TARGET -cnotmatch '^9SX2VF4\\K98DEV\|K98_MGE_Finalisation_Qualification_20261029_A\|[a-f0-9]{64}\z'){
    throw 'Explicit fixed disposable target approval required'
}
. "$PSScriptRoot\..\deploy\SqlDeploy.ModuleRelease.ps1"
. "$PSScriptRoot\..\deploy\SqlDeploy.MgeFinalisation.ps1"
$raw=[IO.File]::ReadAllBytes($ProfilePath)
$loaded=Read-K98ModuleProfile $ProfilePath (Get-K98ModuleHash $raw) '20261029_001_mge_board_finalisation'
$connection=[Data.SqlClient.SqlConnection]::new('Data Source=lpc:localhost\K98DEV;Initial Catalog=K98_MGE_Finalisation_Qualification_20261029_A;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=5')
try {
    $connection.Open()
    $identity=Invoke-K98ModuleQuery $connection $null "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server,DB_NAME() AS db,ORIGINAL_LOGIN() AS login;"
    if($identity.Count -ne 1 -or $identity[0].server -cne '9SX2VF4\K98DEV' -or $identity[0].db -cne 'K98_MGE_Finalisation_Qualification_20261029_A' -or $identity[0].login -cne $ExpectedLogin){throw 'Native fixture identity differs'}
    $null=Invoke-K98ModuleQuery $connection $null 'SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET LOCK_TIMEOUT 5000;'
    Assert-K98MgeImages $connection $null $loaded $true
    $faults=@(
        'DROP INDEX IX_MGE_BoardFinalisation_Work ON dbo.MGE_BoardFinalisation;',
        'DISABLE TRIGGER dbo.tr_MGE_Events_Frozen ON dbo.MGE_Events;',
        'ALTER TABLE dbo.MGE_BoardFinalisation ADD UnexpectedColumn int NULL;',
        ($loaded.Triggers[0].Sql.Replace('CREATE TRIGGER','ALTER TRIGGER')+"`n-- changed postimage")
    )
    foreach($fault in $faults){
        $transaction=$connection.BeginTransaction()
        try {
            $null=Invoke-K98ModuleQuery $connection $transaction $fault
            $refused=$false
            try {Assert-K98MgeImages $connection $transaction $loaded $true} catch {$refused=$true;Write-Output $_.Exception.Message}
            if(-not $refused){throw 'Altered postimage was accepted'}
        }finally{$transaction.Rollback();$transaction.Dispose()}
        Assert-K98MgeImages $connection $null $loaded $true
    }
    Write-Output 'PASS: four altered postimages refused; each rollback independently verified'
}finally{$connection.Dispose()}
