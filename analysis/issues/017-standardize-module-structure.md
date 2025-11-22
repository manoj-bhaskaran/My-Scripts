# ISSUE-017: Standardize PowerShell Module Structure

**Priority:** 🟡 MEDIUM
**Category:** Code Organization / Maintainability
**Estimated Effort:** 6 hours
**Skills Required:** PowerShell, Module Development

---

## Problem Statement

Inconsistent module structure - some use directory-based layout, others single files. Needs Public/Private separation.

---

## Acceptance Criteria
- [ ] All modules use directory-based structure
- [ ] Public/ and Private/ subdirectories for all modules
- [ ] Module manifests (.psd1) updated
- [ ] Deployment scripts updated
- [ ] All modules tested after restructure

---

## Target Structure

```
src/powershell/modules/
├── Core/
│   ├── ErrorHandling/
│   │   ├── ErrorHandling.psm1      # Main module (dot-sources Public/Private)
│   │   ├── ErrorHandling.psd1      # Manifest
│   │   ├── README.md
│   │   ├── Public/                 # Exported functions
│   │   │   ├── Write-ErrorLog.ps1
│   │   │   └── Get-ErrorContext.ps1
│   │   └── Private/                # Internal functions
│   │       └── Format-ErrorMessage.ps1
```

## Implementation

```powershell
# ErrorHandling.psm1 pattern
# Import private functions
Get-ChildItem "$PSScriptRoot/Private/*.ps1" | ForEach-Object {
    . $_.FullName
}

# Import public functions
Get-ChildItem "$PSScriptRoot/Public/*.ps1" | ForEach-Object {
    . $_.FullName
}

# Export only public
$publicFunctions = Get-ChildItem "$PSScriptRoot/Public/*.ps1" |
    Select-Object -ExpandProperty BaseName
Export-ModuleMember -Function $publicFunctions
```

---

**Time:** Restructure modules: 4h, Update deployment: 1h, Testing: 1h = **6 hours**
