function Get-S11PreAtomicConfigurationSource([string]$Source) {
    # Offline historical-contract reconstruction only. Validate both immutable
    # endpoints; never add the predecessor to the runtime definition allowlist.
    function Hash-ConfigurationSource([string]$Text) {
        $sha=[Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    $text=$Source.Replace("`r`n","`n")
    if((Hash-ConfigurationSource $text) -cne '340bc1e888bec8638791b889d128a31c4028ae7546d6e8331093acd66a062b75'){throw 'Atomic configuration forward source drift'}
    $text=$text.Replace("    @RepublishReason [nvarchar](400) = NULL,`n    @ExportPreparationID uniqueidentifier = NULL",'    @RepublishReason [nvarchar](400) = NULL')
    $text=$text.Replace('IF @ExportPreparationID IS NULL AND @@TRANCOUNT <> 0','IF @@TRANCOUNT <> 0')
    $text=[regex]::Replace($text,'(?ms)^    -- Only the typed configuration producer.*?(?=^    DECLARE @RequestedKVK int = @KVK;)','')
    $text=$text.Replace("        IF @ExportPreparationID IS NOT NULL AND (@@TRANCOUNT <> 1 OR XACT_STATE() <> 1)`n            THROW 52626, 'Atomic configuration publication lost its caller transaction.', 1;`n",'')
    if($text.Contains('@ExportPreparationID') -or (Hash-ConfigurationSource $text.Replace("`n","`r`n")) -cne '2ea82ec000c3e4d578c45871e3b107869ac885a3ad41af961a41292db7f31705'){throw 'Atomic configuration historical source drift'}
    return $text
}
