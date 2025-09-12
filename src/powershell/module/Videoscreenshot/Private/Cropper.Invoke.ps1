<#
.SYNOPSIS
  Run the Python cropper (crop_colours.py) over an input folder.

.DESCRIPTION
  Invokes the cropper script with safe, opinionated defaults (non-destructive and robust):
      python crop_colours.py --input <folder> --skip-bad-images --allow-empty --ignore-processed --recurse --preserve-alpha [--debug]

  This helper follows the “helpers throw; caller owns user-facing messages” policy:
  - It validates Python is available.
  - It validates/installs required Python packages (by default).
  - On any failure, it throws with actionable detail; no user-facing writes except Debug.

  Auto-install behavior:
    - By default, required Python packages are auto-installed via `python -m pip install`.
    - Pass -NoAutoInstall to disable auto-install. In that case, the function throws when
      a required package is missing and suggests the pip command.

  Where packages come from:
    - If available, reads `Get-DefaultConfig().Python.RequiredPackages` (e.g., @('opencv-python','numpy')).
    - Falls back to @('opencv-python','numpy') if config is missing/unavailable.
    - Import-name translation: 'opencv-python' → import 'cv2'; others import by the same name.

.PARAMETER PythonScriptPath
  Path to the cropper script (e.g., crop_colours.py).

.PARAMETER PythonExe
  Optional Python executable to use. If not supplied, tries 'py' (Windows launcher) then 'python'.

.PARAMETER InputFolder
  Folder containing images to process (recurse enabled).

.PARAMETER NoAutoInstall
  Disable automatic installation of missing Python packages; throw instead with a suggested command.

.OUTPUTS
  [pscustomobject] with:
    - ExitCode       : int
    - ElapsedSeconds : double (wall-clock)
    - StdOut         : string
    - StdErr         : string
    - RequiredPackages : string[] (resolved package list used)

.EXAMPLE
  Invoke-Cropper -PythonScriptPath .\src\python\crop_colours.py -InputFolder .\shots

.EXAMPLE
  Invoke-Cropper -PythonScriptPath .\src\python\crop_colours.py -InputFolder .\shots -PythonExe python -NoAutoInstall -Debug
#>
function Invoke-Cropper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PythonScriptPath,
        [Parameter()][string]$PythonExe,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InputFolder,
        [switch]$NoAutoInstall
    )

    # ---- Validate inputs ----------------------------------------------------
    if (-not (Test-Path -LiteralPath $PythonScriptPath -PathType Leaf)) {
        throw "Cropper script not found: $PythonScriptPath"
    }
    if (-not (Test-Path -LiteralPath $InputFolder -PathType Container)) {
        throw "InputFolder not found for cropper: $InputFolder"
    }

    # ---- Resolve Python executable -----------------------------------------
    # Preference order: explicit -PythonExe → 'py' (Windows launcher) → 'python'
    $pythonCmd = $null
    if (-not [string]::IsNullOrWhiteSpace($PythonExe)) {
        try { $null = Get-Command -Name $PythonExe -ErrorAction Stop; $pythonCmd = $PythonExe }
        catch { throw "Specified PythonExe '$PythonExe' not found on PATH." }
    } else {
        if (Get-Command -Name py -ErrorAction SilentlyContinue) { $pythonCmd = 'py' }
        elseif (Get-Command -Name python -ErrorAction SilentlyContinue) { $pythonCmd = 'python' }
        else { throw "Python not found. Provide -PythonExe or ensure 'py'/'python' is on PATH." }
    }
    Write-Debug ("Invoke-Cropper: using Python executable: {0}" -f $pythonCmd)

    # ---- Determine required packages ---------------------------------------
    # Source of truth is the module config if available; otherwise fallback.
    $requiredPackages = @('opencv-python','numpy')
    try {
        if (Get-Command -Name Get-DefaultConfig -ErrorAction SilentlyContinue) {
            $cfg = Get-DefaultConfig
            if ($cfg -and $cfg.Python -and $cfg.Python.RequiredPackages -and $cfg.Python.RequiredPackages.Count -gt 0) {
                $requiredPackages = [string[]]$cfg.Python.RequiredPackages
            }
        }
    } catch {
        Write-Debug ("Invoke-Cropper: falling back to default package list; config error: {0}" -f $_.Exception.Message)
    }

    # Local helper: translate package → import name (where they differ)
    function ConvertTo-ImportName {
        param([Parameter(Mandatory)][string]$Package)
        switch ($Package) {
            'opencv-python' { 'cv2' }
            default         { $Package }
        }
    }

    # ---- Preflight: verify required packages; auto-install if allowed -------
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($pkg in $requiredPackages) {
        $mod = ConvertTo-ImportName -Package $pkg
        $psiChk = [System.Diagnostics.ProcessStartInfo]::new()
        $psiChk.FileName = $pythonCmd
        $null = $psiChk.ArgumentList.Add('-c')
        $null = $psiChk.ArgumentList.Add("import $mod")
        $psiChk.UseShellExecute = $false
        $psiChk.RedirectStandardOutput = $true
        $psiChk.RedirectStandardError  = $true
        $psiChk.CreateNoWindow = $true

        $pChk = [System.Diagnostics.Process]::new()
        $pChk.StartInfo = $psiChk
        $null = $pChk.Start()
        $null = $pChk.WaitForExit()
        if ($pChk.ExitCode -ne 0) {
            [void]$missing.Add($pkg)
        }
    }

    if ($missing.Count -gt 0) {
        $missCsv = ($missing -join ', ')
        if ($NoAutoInstall) {
            $suggest = "$pythonCmd -m pip install $missCsv"
            throw "Missing Python packages: $missCsv. Auto-install is disabled (-NoAutoInstall). Install manually, e.g.: $suggest"
        }

        # Attempt pip install
        Write-Debug ("Invoke-Cropper: installing missing packages: {0}" -f $missCsv)
        $psiPip = [System.Diagnostics.ProcessStartInfo]::new()
        $psiPip.FileName = $pythonCmd
        $null = $psiPip.ArgumentList.Add('-m')
        $null = $psiPip.ArgumentList.Add('pip')
        $null = $psiPip.ArgumentList.Add('install')
        foreach ($pkg in $missing) { $null = $psiPip.ArgumentList.Add($pkg) }
        $psiPip.UseShellExecute = $false
        $psiPip.RedirectStandardOutput = $true
        $psiPip.RedirectStandardError  = $true
        $psiPip.CreateNoWindow = $true

        $pPip = [System.Diagnostics.Process]::new()
        $pPip.StartInfo = $psiPip
        $null = $pPip.Start()
        $pipOut = $pPip.StandardOutput.ReadToEnd()
        $pipErr = $pPip.StandardError.ReadToEnd()
        $pPip.WaitForExit()
        if ($pPip.ExitCode -ne 0) {
            throw ("Failed to auto-install Python packages ({0}). pip exit={1}. STDERR: {2} | STDOUT: {3}" -f $missCsv, $pPip.ExitCode, $pipErr, $pipOut)
        }
        # Emit a concise snippet of pip STDOUT when debugging to aid diagnosis without flooding logs.
        if ($PSBoundParameters.ContainsKey('Debug') -or $DebugPreference -eq 'Continue') {
            $snippet = if ($pipOut -and $pipOut.Length -gt 400) {
                $pipOut.Substring(0, 400) + '…'
            } else { $pipOut }
            if ($snippet) { Write-Debug ("Invoke-Cropper: pip install output (truncated): {0}" -f $snippet) }
        }
        Write-Debug "Invoke-Cropper: package install completed."
    }

    # ---- Compose cropper arguments (intentionally opinionated) --------------
    # Per design, these flags are not made configurable here.
    $pyArgs = @(
        "$PythonScriptPath",
        '--input', $InputFolder,
        '--skip-bad-images',
        '--allow-empty',
        '--ignore-processed',
        '--recurse',
        '--preserve-alpha'
    )
    # Propagate PowerShell -Debug to Python via --debug
    $wantDebug = $PSBoundParameters.ContainsKey('Debug') -or ($DebugPreference -eq 'Continue')
    if ($wantDebug) { $pyArgs += '--debug' }

    # ---- Launch cropper process ---------------------------------------------
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pythonCmd
    foreach ($a in $pyArgs) { $null = $psi.ArgumentList.Add($a) }
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
        ExitCode         = [int]$p.ExitCode
        ElapsedSeconds   = [math]::Round($sw.Elapsed.TotalSeconds, 3) # wall-clock
        StdOut           = $stdOut
        StdErr           = $stdErr
        RequiredPackages = $requiredPackages
    }
}
