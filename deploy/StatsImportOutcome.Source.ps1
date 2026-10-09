function Get-S11PreOutcomeSource([string]$Source) {
    # Inverse of the reviewed receipt and exact counter-binding edits. The caller must first validate the
    # forward postimage; this never adds a historical runtime allowlist entry.
    $source = $Source.Replace("`r`n", "`n")
    $source = $source.Replace("@CompletedFileName [nvarchar](260),`n    @ExportPreparationID uniqueidentifier = NULL", '@CompletedFileName [nvarchar](260)')
    $source = [regex]::Replace($source, '(?ms)^    IF @ExportPreparationID IS NOT NULL\n    BEGIN\n.*?^    END;\n\n', '')
    $source = [regex]::Replace($source, '(?ms)^        IF @ExportPreparationID IS NOT NULL\n        BEGIN\n.*?^        END;\n', '')
    $source = $source.Replace("        DECLARE @S11CompletionCounters TABLE (LastRunCounter int NOT NULL);`n", '')
    $source = $source.Replace("        OUTPUT inserted.LastRunCounter INTO @S11CompletionCounters (LastRunCounter)`n", '')
    $source = $source.Replace('FROM dbo.SP_TaskStatus WITH (UPDLOCK,HOLDLOCK)', 'FROM dbo.SP_TaskStatus')
    if ($source.Contains('@ExportPreparationID') -or $source.Contains('StatsImportExecution')) {
        throw 'Incomplete outcome amendment inversion'
    }
    return $source
}
