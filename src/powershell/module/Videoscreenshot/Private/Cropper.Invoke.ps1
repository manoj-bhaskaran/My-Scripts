function Invoke-Cropper {
    <#
    .SYNOPSIS
    Run the Python cropper script to trim borders by dominant color.
    .DESCRIPTION
    Invokes the provided Python script with folder/prefix arguments. Throws on non-zero exit.
    Helpers follow the “throw on failure; no user-facing writes” policy.
    .PARAMETER PythonScriptPath
    Path to the cropper script (e.g., crop_colours.py).
    .PARAMETER PythonExe
    Optional Python executable to use. If not supplied, tries 'py' (Windows launcher) then 'python'.
    .PARAMETER SaveFolder
    Folder where frames were saved.
    .PARAMETER ScenePrefix
    Filename prefix used for frames (files like '<prefix>*.png' are targeted).
    .OUTPUTS
    [pscustomobject] with ExitCode and ElapsedSeconds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PythonScriptPath,
        [Parameter()][string]$PythonExe,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix
    )

    if (-not (Test-Path -LiteralPath $PythonScriptPath)) {
        throw "Cropper script not found: $PythonScriptPath"
    }
    if (-not (Test-Path -LiteralPath $SaveFolder)) {
        throw "SaveFolder not found for cropper: $SaveFolder"
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

    # Common argument model: script --folder <SaveFolder> --prefix <ScenePrefix>
    # (Keeps compatibility simple; adjust your cropper script accordingly.)
    $pyArgs = @("$PythonScriptPath", '--folder', $SaveFolder, '--prefix', $ScenePrefix)

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
        StdOut         = $stdOut
        StdErr         = $stdErr
    }
}