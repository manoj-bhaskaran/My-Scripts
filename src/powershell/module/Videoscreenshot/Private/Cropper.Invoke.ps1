# Python cropper integration (private helper)
# Placeholder implementation to keep the pipeline coherent. When implemented,
# this should invoke the Python cropper script and return a result object if needed.
function Invoke-Cropper {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PythonScriptPath,
    [ValidateNotNullOrEmpty()][string]$PythonExe,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SaveFolder,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ScenePrefix
  )

  # Example of a real implementation sketch (to be completed later):
  # $exe = if ($PythonExe) { $PythonExe } else { 'python' }
  # $psi = [Diagnostics.ProcessStartInfo]::new()
  # $psi.FileName = $exe
  # $psi.ArgumentList.Add($PythonScriptPath)
  # $psi.ArgumentList.Add('--input')
  # $psi.ArgumentList.Add($SaveFolder)
  # $psi.ArgumentList.Add('--prefix')
  # $psi.ArgumentList.Add($ScenePrefix)
  # $psi.UseShellExecute = $false
  # $psi.RedirectStandardOutput = $true
  # $psi.RedirectStandardError  = $true
  # $p = [Diagnostics.Process]::new()
  # $p.StartInfo = $psi
  # $null = $p.Start()
  # $out = $p.StandardOutput.ReadToEnd()
  # $err = $p.StandardError.ReadToEnd()
  # $p.WaitForExit()
  # if ($p.ExitCode -ne 0) { throw "Cropper failed (exit=$($p.ExitCode)): $err" }
  # return [pscustomobject]@{ ExitCode = $p.ExitCode; Output = $out }

  throw "Invoke-Cropper is not implemented yet. Provide a Python cropper or disable -RunCropper."
}
