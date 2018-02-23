<#

.SYNOPSIS

.DESCRIPTION

# .PARAMETER

.EXAMPLE

#>

function Get-JojobaArgument {
    [CmdletBinding()]
    [OutputType("System.Collections.Hashtable")]
    param (
        $Caller
    )

    begin {
    }

    process {
        $callerModuleName = $Caller.GetVariableValue("MyInvocation").MyCommand.ModuleName
        $callerClassName = $Caller.GetVariableValue("MyInvocation").MyCommand.Name
        if ($callerClassName) {
            $callerCommand = $Caller.GetVariableValue("MyInvocation").MyCommand
            if (!$callerCommand) {
                Write-Error "No caller command"
            }

            $argumentName = $null
            $inputName = $null
            foreach ($key in $callerCommand.Parameters.Keys.GetEnumerator()) {
                if ($callerCommand.Parameters[$key].ParameterSets.ContainsKey($Caller.ParameterSetName) -and
                    (
                        $callerCommand.Parameters[$key].ParameterSets[$Caller.ParameterSetName].ValueFromPipeline -or
                        $callerCommand.Parameters[$key].ParameterSets[$Caller.ParameterSetName].ValueFromPipelineByPropertyName
                    ) -and
                    (
                        $callerCommand.Parameters[$key].Name -eq "InputObject" -or
                        $callerCommand.Parameters[$key].Aliases -contains "InputObject"
                    )) {
                    $inputName = $Key
                }

                if ($callerCommand.Parameters[$key].ParameterSets.ContainsKey($Caller.ParameterSetName) -and
                    $callerCommand.Parameters[$key].ParameterSets[$Caller.ParameterSetName].ValueFromRemainingArguments) {
                    $argumentName = $Key
                }
            }

            # Get the ValueFromRemainingArguments
            if (!$argumentName) {
                Write-Error "Jojoba requires a parameter with ValueFromRemainingArguments"
            }
            if (!$inputName) {
                Write-Error "Jojoba requires a parameter variable aliased to InputObject"
            }

            # Maybe no -Jojoba arguments were specified, and that's okay!
            if (!($arguments = $Caller.GetVariableValue($argumentName))) {
                $arguments = @()
            }
        } else {
            Write-Error "Jojoba can only be used from within functions"
        }

        if ($arguments -notcontains "-JojobaArgumentName") {
            $arguments += "-JojobaArgumentName", $argumentName
        }
        if ($arguments -notcontains "-JojobaInputName") {
            $arguments += "-JojobaInputName", $inputName
        }

        if ($arguments -notcontains "-JojobaBatch") {
            $arguments += "-JojobaBatch", [guid]::NewGuid().ToString()
        }

        if ($arguments -notcontains "-JojobaSuite") {
            $arguments += "-JojobaSuite", $callerModuleName
        }
        if ($arguments -notcontains "-JojobaClassName") {
            $arguments += "-JojobaClassName", $callerClassName
        }
        if ($arguments -notcontains "-JojobaName") {
            $arguments += "-JojobaName", $Caller.GetVariableValue($inputName)
        }

        if ($arguments -notcontains "-JojobaQuiet") {
            $arguments += "-JojobaQuiet", $false
        }
        if ($arguments -notcontains "-JojobaPassThru") {
            $arguments += "-JojobaPassThru", $false
        }
        if ($arguments -notcontains "-JojobaThrottle") {
            $arguments += "-JojobaThrottle", $env:NUMBER_OF_PROCESSORS
        }
        if ($arguments -notcontains "-JojobaJenkins") {
            $arguments += "-JojobaJenkins"
            if ($env:JENKINS_SERVER_COOKIE) {
                $arguments += ".\Jojoba.xml"
            } else {
                $arguments += $null
            }
        }
        if ($arguments -notcontains "-JojobaPassThru") {
            $arguments += "-JojobaPassThru:", $false
        }

        $Caller.SessionState.PSVariable.Set($argumentName, $arguments)

        $settings = @{}

        for ($i = 0; $arguments -and $i -lt $arguments.Count; $i++) {
            if ($arguments[$i] -and $arguments[$i] -match '^-Jojoba(.*?)(?::?)$') {
                if (($i + 1) -eq $arguments.Count -or $arguments[$i + 1] -like "-*") {
                    $settings[$Matches[1]] = $true
                } else {
                    $settings[$Matches[1]] = $arguments[++$i]
                }
            }
        }

        # Resolve full path
        if ($settings.Jenkins) {
            $settings.Jenkins = Join-Path (Resolve-Path (Split-Path $settings.Jenkins)) (Split-Path $settings.Jenkins -Leaf)
        }

        $settings
    }

    end {
    }
}
