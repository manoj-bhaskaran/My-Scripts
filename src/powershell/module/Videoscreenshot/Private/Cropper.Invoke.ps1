function Invoke-Cropper {
    <#
    .SYNOPSIS
    Run the Python cropper (crop_colours.py) over an input folder.
    .DESCRIPTION
    Invokes the Python script as:
      python crop_colours.py --input <folder> --skip-bad-images --allow-empty --ignore-processed --recurse --preserve-alpha [--debug]
    Throws on non-zero exit. No user-facing writes here (“helpers throw” policy).
    .PARAMETER PythonScriptPath
    Path to the cropper script (e.g., crop_colours.py).
    .PARAMETER PythonExe
    Optional Python executable to use. If not supplied, tries 'py' (Windows launcher) then 'python'.
    .PARAMETER InputFolder
    Folder containing images to process (will recurse).
    .OUTPUTS
    [pscustomobject] with ExitCode and ElapsedSeconds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PythonScriptPath,
        [Parameter()][string]$PythonExe,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InputFolder
    )

    if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
        throw "Cropper script not found: $PythonScriptPath"
    }
    if (-not (Test-Path -LiteralPath $InputFolder)) {
        throw "InputFolder not found for cropper: $InputFolder"
    }

    # Resolve python executable
    $pythonCmd = $null
    if ($PythonExe) {
        $pythonCmd = $PythonExe
    } else {
        if (Get-Command -Name py -ErrorAction SilentlyContinue) { $pythonCmd = 'py' }
        elseif (Get-Command -Name python -ErrorAction SilentlyContinue) { $pythonCmd = 'python' }
        else { throw "Python not found. Provide -PythonExe or ensure 'py'/'python' is on PATH." }
    }

    # Required cropper arguments
    $pyArgs = @(
        "$PythonScriptPath",
        '--input', $InputFolder,
        '--skip-bad-images',
        '--allow-empty',
        '--ignore-processed',
        '--recurse',
        '--preserve-alpha'
    )
    # If caller used -Debug, propagate --debug to Python
    $wantDebug = $PSBoundParameters.ContainsKey('Debug') -or ($DebugPreference -eq 'Continue')
    if ($wantDebug) { $pyArgs += '--debug' }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pythonCmd
    foreach ($a in $pyArgs) {
        $psi.ArgumentList.Add($a)
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true

    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $null = $p.Start()
    $stdOut = $p.StandardOutput.ReadToEnd()
    $stdErr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $sw.Stop()

    if ($p.ExitCode -ne 0) {
        $msg = "Cropper failed (exit $($p.ExitCode)). STDERR: $stdErr"
        if ($stdOut) { $msg += " | STDOUT: $stdOut" }
        throw $msg
    }

    [pscustomobject]@{
        ExitCode       = [int]$p.ExitCode
        ElapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 3) # wall-clock time for accuracy on I/O-bound work
        StdOut         = $stdOut
        StdErr         = $stdErr
    }
}