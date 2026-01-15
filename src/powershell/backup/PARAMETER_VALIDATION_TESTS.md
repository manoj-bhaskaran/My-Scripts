# Parameter Validation Tests for Sync-MacriumBackups.ps1

## Purpose
This document outlines test cases for the improved parameter block validation in Sync-MacriumBackups.ps1.

## Changes Implemented
1. Added `[Parameter(Mandatory=$false)]` to all optional parameters
2. Added validation attributes:
   - `[ValidateNotNullOrEmpty()]` for string parameters
   - `[ValidatePattern('^[a-zA-Z0-9\s_-]+$')]` for SSID parameters (prevents command injection)
   - `[ValidateRange(64, 4096)]` for MaxChunkMB parameter
3. Organized parameters into logical groups with clear comments:
   - Path Parameters
   - Network Parameters
   - Rclone Configuration
   - Execution Control

## Test Cases

### 1. Valid Input Tests (Should PASS)

#### Test 1.1: Default Values
```powershell
.\Sync-MacriumBackups.ps1
```
**Expected**: Script should run with default values

#### Test 1.2: Valid Custom SSID with Alphanumeric
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "MyNetwork123" -FallbackSSID "Backup_Net"
```
**Expected**: Parameters accepted, script proceeds

#### Test 1.3: Valid SSID with Spaces and Hyphens
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "My Network" -FallbackSSID "Guest-WiFi"
```
**Expected**: Parameters accepted, script proceeds

#### Test 1.4: Valid SSID with Common Punctuation
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Joe's WiFi" -FallbackSSID "Home.Network"
.\Sync-MacriumBackups.ps1 -PreferredSSID "WiFi-5G+" -FallbackSSID "Guest (2.4GHz)"
.\Sync-MacriumBackups.ps1 -PreferredSSID "Net@Home" -FallbackSSID "Café_WiFi"
```
**Expected**: All common punctuation (apostrophes, periods, plus, parentheses, at signs) should be accepted

#### Test 1.5: Valid MaxChunkMB Values
```powershell
.\Sync-MacriumBackups.ps1 -MaxChunkMB 64
.\Sync-MacriumBackups.ps1 -MaxChunkMB 512
.\Sync-MacriumBackups.ps1 -MaxChunkMB 2048
.\Sync-MacriumBackups.ps1 -MaxChunkMB 4096
```
**Expected**: All values within range [64-4096] should be accepted

#### Test 1.6: Valid Paths
```powershell
.\Sync-MacriumBackups.ps1 -SourcePath "D:\Backups" -RcloneRemote "gdrive:Backup Folder"
```
**Expected**: Parameters accepted, script proceeds

### 2. Invalid Input Tests (Should FAIL with Validation Error)

#### Test 2.1: SSID with Semicolon (Command Injection Attempt)
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Test;whoami"
```
**Expected**: Parameter validation error - pattern mismatch
**Security**: Prevents command injection via semicolon

#### Test 2.2: SSID with Dollar Sign (Variable Expansion Attempt)
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Test`$ENV:PATH"
```
**Expected**: Parameter validation error - pattern mismatch
**Security**: Prevents variable expansion attacks

#### Test 2.3: SSID with Pipe (Command Chaining Attempt)
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Test|Get-Process"
```
**Expected**: Parameter validation error - pattern mismatch
**Security**: Prevents command chaining

#### Test 2.4: SSID with Backtick (Escape Character Attempt)
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Test``nmalicious"
```
**Expected**: Parameter validation error - pattern mismatch
**Security**: Prevents escape sequence injection

#### Test 2.5: SSID with Quote (String Breaking Attempt)
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Test`"break"
```
**Expected**: Parameter validation error - pattern mismatch
**Security**: Prevents quote-based string breaking

#### Test 2.6: SSID with Ampersand (Command Separator Attempt)
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "Test&calc"
```
**Expected**: Parameter validation error - pattern mismatch
**Security**: Prevents command separator injection

#### Test 2.7: Empty SSID
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID ""
```
**Expected**: Parameter validation error - ValidateNotNullOrEmpty

#### Test 2.8: MaxChunkMB Below Range
```powershell
.\Sync-MacriumBackups.ps1 -MaxChunkMB 32
```
**Expected**: Parameter validation error - value 32 is below minimum 64

#### Test 2.9: MaxChunkMB Above Range
```powershell
.\Sync-MacriumBackups.ps1 -MaxChunkMB 8192
```
**Expected**: Parameter validation error - value 8192 exceeds maximum 4096

#### Test 2.10: Empty SourcePath
```powershell
.\Sync-MacriumBackups.ps1 -SourcePath ""
```
**Expected**: Parameter validation error - ValidateNotNullOrEmpty

#### Test 2.11: Empty RcloneRemote
```powershell
.\Sync-MacriumBackups.ps1 -RcloneRemote ""
```
**Expected**: Parameter validation error - ValidateNotNullOrEmpty

### 3. Edge Case Tests

#### Test 3.1: SSID with Maximum Typical Length
```powershell
.\Sync-MacriumBackups.ps1 -PreferredSSID "A" * 32  # 32 character SSID
```
**Expected**: Should be accepted (WiFi SSIDs can be up to 32 bytes)

#### Test 3.2: Boundary Values for MaxChunkMB
```powershell
.\Sync-MacriumBackups.ps1 -MaxChunkMB 63    # Just below minimum
.\Sync-MacriumBackups.ps1 -MaxChunkMB 64    # Minimum (should pass)
.\Sync-MacriumBackups.ps1 -MaxChunkMB 4096  # Maximum (should pass)
.\Sync-MacriumBackups.ps1 -MaxChunkMB 4097  # Just above maximum
```
**Expected**: Only 64 and 4096 should pass

## Test Execution Instructions

### On Windows with PowerShell:
1. Open PowerShell as Administrator
2. Navigate to: `/home/user/My-Scripts/src/powershell/backup/`
3. Run each test case
4. Document results including:
   - Test number and description
   - Actual result (pass/fail)
   - Error message if validation failed
   - Any unexpected behavior

### Expected Validation Error Format:
```
ParameterBindingValidationException: Cannot validate argument on parameter 'PreferredSSID'.
The argument "Test;whoami" does not match the "^[^"`$|;&<>\r\n\t]+$" pattern.
Supply an argument that matches "^[^"`$|;&<>\r\n\t]+$" and try the command again.
```

## Security Improvements

### Command Injection Prevention
The ValidatePattern attribute on SSID parameters uses a **blacklist approach** to block dangerous characters while allowing legitimate WiFi names:

**Blocked Characters** (prevent command injection):
- Double quotes (`"`) - string breaking
- Backticks (`` ` ``) - PowerShell escape character
- Dollar signs (`$`) - variable expansion
- Pipes (`|`) - command chaining
- Semicolons (`;`) - command separators
- Ampersands (`&`) - background execution/command chaining
- Angle brackets (`<`, `>`) - redirection operators
- Newlines/carriage returns (`\r`, `\n`) - command splitting
- Tabs (`\t`) - parsing issues

### Allowed Characters
The pattern `^[^"\`$|;&<>\r\n\t]+$` allows most printable characters including:
- Letters (a-z, A-Z)
- Numbers (0-9)
- Spaces (for SSIDs like "My Network")
- Common punctuation: periods (`.`), apostrophes (`'`), hyphens (`-`), underscores (`_`)
- Parentheses, plus signs, at signs, commas, and other common symbols
- Any character that is NOT in the blocked list

**This approach balances security with usability** - it blocks command injection vectors while supporting real-world WiFi naming conventions like:
- "Joe's WiFi" (apostrophe)
- "Home.Network" (period)
- "WiFi-5G+" (plus sign)
- "Guest (2.4GHz)" (parentheses)
- "Net@Home" (at sign)

## Validation Rules Summary

| Parameter | Validation Rules | Range/Pattern |
|-----------|------------------|---------------|
| SourcePath | NotNullOrEmpty | Any valid path string |
| RcloneRemote | NotNullOrEmpty | Any valid remote string |
| PreferredSSID | NotNullOrEmpty + Pattern | `^[^"\`$|;&<>\r\n\t]+$` (blocks dangerous chars) |
| FallbackSSID | NotNullOrEmpty + Pattern | `^[^"\`$|;&<>\r\n\t]+$` (blocks dangerous chars) |
| MaxChunkMB | Range | 64 to 4096 MB |
| Interactive | Switch (boolean) | N/A |
| AutoResume | Switch (boolean) | N/A |
| Force | Switch (boolean) | N/A |

## Compatibility Notes
- All existing scripts and scheduled tasks using default values will continue to work
- Only scripts passing invalid parameters will fail (which is the intended security improvement)
- Default SSID values ("ManojNew_5G", "ManojNew") pass validation
- Default MaxChunkMB value (2048) is within valid range

## Maintenance Notes
- If SSIDs with special characters are legitimately needed, the ValidatePattern can be adjusted
- The pattern should always exclude characters used for command injection: `; | & $ ` " '`
- MaxChunkMB range aligns with rclone's recommended values and system memory constraints
