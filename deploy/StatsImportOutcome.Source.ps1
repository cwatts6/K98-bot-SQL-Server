function Get-S11PreOutcomeSource([string]$Source) {
    # Inverse of the four reviewed edits. The caller must first validate the
    # forward postimage; this never adds a historical runtime allowlist entry.
    $source = $Source.Replace("`r`n", "`n")
    $source = $source.Replace("@CompletedFileName [nvarchar](260),`n    @ExportPreparationID uniqueidentifier = NULL", '@CompletedFileName [nvarchar](260)')
    $source = [regex]::Replace($source, '(?ms)^    IF @ExportPreparationID IS NOT NULL\n    BEGIN\n.*?^    END;\n\n', '')
    $source = [regex]::Replace($source, '(?ms)^        IF @ExportPreparationID IS NOT NULL\n        BEGIN\n.*?^        END;\n', '')
    if ($source.Contains('@ExportPreparationID') -or $source.Contains('StatsImportExecution')) {
        throw 'Incomplete outcome amendment inversion'
    }
    return $source
}
