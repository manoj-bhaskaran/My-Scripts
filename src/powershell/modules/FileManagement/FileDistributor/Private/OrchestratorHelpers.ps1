# OrchestratorHelpers.ps1 - Internal helpers for FileDistributor orchestration functions

function Test-EndOfScriptCondition {
    param(
        [Parameter(Mandatory = $true)][string]$Condition, # "NoWarnings" | "WarningsOnly"
        [int]$Warnings = 0,
        [int]$Errors = 0
    )
    switch ($Condition) {
        "NoWarnings" { return ($Warnings -eq 0 -and $Errors -eq 0) }
        "WarningsOnly" { return ($Errors -eq 0) }
        default {
            Write-LogWarning "Unknown EndOfScriptDeletionCondition '$Condition'. Failing closed."
            return $false
        }
    }
}
