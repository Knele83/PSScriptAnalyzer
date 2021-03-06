﻿Import-Module PSScriptAnalyzer
$violationMessage = "'Verb-Files' has the ShouldProcess attribute but does not call ShouldProcess/ShouldContinue."
$violationName = "PSShouldProcess"
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
$violations = Invoke-ScriptAnalyzer $directory\BadCmdlet.ps1 | Where-Object {$_.RuleName -eq $violationName}
$noViolations = Invoke-ScriptAnalyzer $directory\GoodCmdlet.ps1 | Where-Object {$_.RuleName -eq $violationName}

Describe "UseShouldProcessCorrectly" {
    Context "When there are violations" {
        It "has 3 should process violation" {
            $violations.Count | Should Be 1
        }

        It "has the correct description message" {
            $violations[0].Message | Should Match $violationMessage
        }

    }

    Context "When there are no violations" {
        It "returns no violations" {
            $noViolations.Count | Should Be 0
        }
    }

    Context "Where ShouldProcess is called by a downstream function" {
        It "finds no violation for 1 level downstream call" {
            $scriptDef = @'
function Foo
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Bar
}

function Bar
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if ($PSCmdlet.ShouldProcess(""))
    {
        "Continue normally..."
    }
    else
    {
        "what would happen..."
    }
}

Foo
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }

        It "finds no violation if downstream function does not declare SupportsShouldProcess" {
              $scriptDef = @'
function Foo
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Bar
}

function Bar
{
    if ($PSCmdlet.ShouldProcess(""))
    {
        "Continue normally..."
    }
    else
    {
        "what would happen..."
    }
}

Foo
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }

        It "finds no violation for 2 level downstream calls" {
            $scriptDef = @'
function Foo
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    Baz
}

function Baz
{
    Bar
}

function Bar
{
    if ($PSCmdlet.ShouldProcess(""))
    {
        "Continue normally..."
    }
    else
    {
        "what would happen..."
    }
}

Foo
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }
    }

    Context "When downstream function is defined locally in a function scope" {
        It "finds no violation" {
            $scriptDef = @'
function Foo
{
   [CmdletBinding(SupportsShouldProcess)]
   param()
   begin
   {
       function Bar
       {
           if ($PSCmdlet.ShouldProcess('',''))
           {

           }
       }
       bar
   }
}
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }
    }

    Context "When a builtin command with SupportsShouldProcess is called" {
        It "finds no violation for a cmdlet" {
            $scriptDef = @'
function Remove-Foo {
[CmdletBinding(SupportsShouldProcess)]
    Param(
        [string] $Path
    )
    Write-Verbose "Removing $($path)"
    Remove-Item -Path $Path
}
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }

        It "finds no violation for a function" {
            $scriptDef = @'
function Install-Foo {
[CmdletBinding(SupportsShouldProcess)]
    Param(
        [string] $ModuleName
    )
    Install-Module $ModuleName
}
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }

       It "finds no violation for a function with self reference" {
            $scriptDef = @'
function Install-ModuleWithDeps {
[CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(ValueFromPipeline)]
        [string] $ModuleName
    )
    if ($PSCmdlet.ShouldProcess("Install module with dependencies"))
    {
        Get-Dependencies $ModuleName | Install-ModuleWithDeps
        Install-ModuleCustom $ModuleName
    }
    else
    {
        Get-Dependencies $ModuleName | Install-ModuleWithDeps
        Write-Host ("Would install module {0}" -f $ModuleName)
    }
}
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }

       It "finds no violation for a function with self reference and implicit call to ShouldProcess" {
            $scriptDef = @'
function Install-ModuleWithDeps {
[CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(ValueFromPipeline)]
        [string] $ModuleName
    )
    $deps = Get-Dependencies $ModuleName
    if ($deps -eq $null)
    {
        Install-Module $ModuleName
    }
    else
    {
        $deps | Install-ModuleWithDeps
    }
    Install-Module $ModuleName
}
'@
            $violations = Invoke-ScriptAnalyzer -ScriptDefinition $scriptDef -IncludeRule PSShouldProcess
            $violations.Count | Should Be 0
        }

    }
}