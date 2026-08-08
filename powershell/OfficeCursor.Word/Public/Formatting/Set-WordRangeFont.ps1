function Set-WordRangeFont {
    <#
    .SYNOPSIS
    Applies font properties to ranges emitted by Find-WordRange.

    .DESCRIPTION
    Validates range text before applying any mutation, groups all changes for a
    document into one Word undo record, and verifies requested properties.

    .EXAMPLE
    Find-WordRange -HighlightColor Yellow |
        Set-WordRangeFont -Bold $true

    .EXAMPLE
    Find-WordRange -Style Quote |
        Set-WordRangeFont -FontName Garamond -Italic $false -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Nullable[bool]]$Bold,

        [Nullable[bool]]$Italic,

        [string]$FontName,

        [Nullable[float]]$FontSize,

        [object]$FontColor,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Document', 'FullName')]
        [string]$DocumentPath,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int]$Start,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int]$End,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Text')]
        [AllowEmptyString()]
        [string]$ExpectedText
    )

    begin {
        $propertyNames = @('Bold', 'Italic', 'FontName', 'FontSize', 'FontColor')
        $requestedProperties = @($propertyNames | Where-Object { $PSBoundParameters.ContainsKey($_) })
        if ($requestedProperties.Count -eq 0) {
            throw 'Specify at least one font property to set.'
        }
        $requests = [Collections.Generic.List[object]]::new()
    }

    process {
        $requests.Add([pscustomobject]@{
            DocumentPath = $DocumentPath
            Start        = $Start
            End          = $End
            ExpectedText = $ExpectedText
        })
    }

    end {
        $word = Connect-WordApplication
        $setBold = $PSBoundParameters.ContainsKey('Bold')
        $setItalic = $PSBoundParameters.ContainsKey('Italic')
        $setFontName = $PSBoundParameters.ContainsKey('FontName')
        $setFontSize = $PSBoundParameters.ContainsKey('FontSize')
        $setFontColor = $PSBoundParameters.ContainsKey('FontColor')
        $targetColor = if ($setFontColor) {
            ConvertTo-WordColor -Color $FontColor
        }

        foreach ($documentGroup in $requests | Group-Object DocumentPath) {
            $document = Resolve-WordDocument -Application $word -DocumentPath $documentGroup.Name
            $orderedRequests = @($documentGroup.Group | Sort-Object Start -Descending)

            foreach ($request in $orderedRequests) {
                $actualText = [string]$document.Range($request.Start, $request.End).Text
                if ($actualText -cne $request.ExpectedText) {
                    throw "Range precondition failed at $($request.Start)-$($request.End)."
                }
            }

            $description = "Set $($requestedProperties -join ', ') on $($orderedRequests.Count) range(s)"
            $apply = $PSCmdlet.ShouldProcess([string]$document.FullName, $description)
            $results = [Collections.Generic.List[object]]::new()

            if ($apply) {
                Invoke-WordUndoRecord -Application $word -Name 'Office Cursor: set range font' -Action {
                    foreach ($request in $orderedRequests) {
                        $range = $document.Range($request.Start, $request.End)
                        if ($setBold) {
                            $range.Font.Bold = if ($Bold) { -1 } else { 0 }
                        }
                        if ($setItalic) {
                            $range.Font.Italic = if ($Italic) { -1 } else { 0 }
                        }
                        if ($setFontName) {
                            $range.Font.Name = $FontName
                        }
                        if ($setFontSize) {
                            $range.Font.Size = [float]$FontSize
                        }
                        if ($setFontColor) {
                            $range.Font.Color = $targetColor
                        }

                        $verified = $true
                        if ($setBold) {
                            $verified = $verified -and ([int]$range.Font.Bold -eq $(if ($Bold) { -1 } else { 0 }))
                        }
                        if ($setItalic) {
                            $verified = $verified -and ([int]$range.Font.Italic -eq $(if ($Italic) { -1 } else { 0 }))
                        }
                        if ($setFontName) {
                            $verified = $verified -and ([string]$range.Font.Name -eq $FontName)
                        }
                        if ($setFontSize) {
                            $verified = $verified -and ([float]$range.Font.Size -eq [float]$FontSize)
                        }
                        if ($setFontColor) {
                            $verified = $verified -and ([int]$range.Font.Color -eq $targetColor)
                        }

                        $results.Add([pscustomobject]@{
                            PSTypeName = 'OfficeCursor.Word.RangeFontChange'
                            Document   = [string]$document.FullName
                            Start      = $request.Start
                            End        = $request.End
                            Text       = $request.ExpectedText
                            Properties = $requestedProperties -join ', '
                            Applied    = $true
                            Verified   = $verified
                        })
                    }
                }
            }
            else {
                foreach ($request in $orderedRequests) {
                    $results.Add([pscustomobject]@{
                        PSTypeName = 'OfficeCursor.Word.RangeFontChange'
                        Document   = [string]$document.FullName
                        Start      = $request.Start
                        End        = $request.End
                        Text       = $request.ExpectedText
                        Properties = $requestedProperties -join ', '
                        Applied    = $false
                        Verified   = $false
                    })
                }
            }

            $results | Sort-Object Start
        }
    }
}
