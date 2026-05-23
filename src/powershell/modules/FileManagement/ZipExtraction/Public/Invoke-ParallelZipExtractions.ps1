function Invoke-ParallelZipExtractions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.IO.FileInfo[]]$Zips, [Parameter(Mandatory)][int]$ZipCount,
        [Parameter(Mandatory)][string]$DestinationDir, [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Policy, [Parameter(Mandatory)][int]$SafeNameMaxLen,
        [Parameter(Mandatory)][bool]$QuietMode, [Parameter(Mandatory)][int]$ThrottleLimit,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$ErrorList
    )
    $concurrentErrors = [ConcurrentBag[string]]::new()
    $fsModulePath     = (Get-Module -Name FileSystem -ErrorAction SilentlyContinue)?.Path
    $zipModulePath    = (Get-Module -Name Zip -ErrorAction SilentlyContinue)?.Path
    $runspaceFnDef    = "function Expand-ZipInRunspace { ${function:Expand-ZipInRunspace} }"
    $progressCounter  = 0

    $results = @(
        $Zips | ForEach-Object -Parallel {
            . ([ScriptBlock]::Create($using:runspaceFnDef))
            Expand-ZipInRunspace -Zip $_ -DestDir $using:DestinationDir -Mode $using:Mode -Policy $using:Policy -MaxLen $using:SafeNameMaxLen -FsModulePath $using:fsModulePath -ZipModulePath $using:zipModulePath -ErrorBag $using:concurrentErrors
        } -ThrottleLimit $ThrottleLimit | ForEach-Object {
            $progressCounter++
            Show-ProgressPhase -Activity "Extracting archives" -Status "$progressCounter / $ZipCount completed" -Current $progressCounter -Total $ZipCount -QuietMode $QuietMode
            $_
        }
    )

    Show-ProgressPhase -Activity "Extracting archives" -Status "Done" -Current $ZipCount -Total $ZipCount -QuietMode $QuietMode -Completed
    return Merge-ParallelZipResults -Results $results -ZipCount $ZipCount -ErrorList $ErrorList -ConcurrentErrors $concurrentErrors
}
