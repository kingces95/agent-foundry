function Set-WordRangeText {
    <#
    .SYNOPSIS
    Replaces the text of ranges emitted by Find-WordRange.

    .DESCRIPTION
    Validates each range's current text before mutation, applies all ranges in
    reverse document order inside one Word undo record, and verifies each
    replacement immediately. Reverse ordering keeps later coordinates stable.

    .PARAMETER ReplacementText
    Text that replaces every input range. An empty string deletes the ranges.

    .EXAMPLE
    Find-WordRange -Text 'draft' -MatchWholeWord |
        Set-WordRangeText -ReplacementText 'manuscript'

    .EXAMPLE
    Find-WordRange -Text ' — proof copy' |
        Set-WordRangeText -ReplacementText '' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ReplacementText,

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
        $requests = [Collections.Generic.List[object]]::new()
    }

    process {
        if ($End -lt $Start) {
            throw "Range end $End precedes start $Start."
        }

        $requests.Add([pscustomobject]@{
            DocumentPath = $DocumentPath
            Start        = $Start
            End          = $End
            ExpectedText = $ExpectedText
        })
    }

    end {
        $word = Connect-WordApplication

        foreach ($documentGroup in $requests | Group-Object DocumentPath) {
            $document = Resolve-WordDocument -Application $word -DocumentPath $documentGroup.Name
            $orderedRequests = @($documentGroup.Group | Sort-Object Start -Descending)

            # Validate every precondition before changing any range.
            foreach ($request in $orderedRequests) {
                $actualText = [string]$document.Range($request.Start, $request.End).Text
                if ($actualText -cne $request.ExpectedText) {
                    throw "Range precondition failed at $($request.Start)-$($request.End). Expected '$($request.ExpectedText)' but found '$actualText'."
                }
            }

            $description = "Replace $($orderedRequests.Count) range(s) with '$ReplacementText'"
            if (-not $PSCmdlet.ShouldProcess([string]$document.FullName, $description)) {
                foreach ($request in $orderedRequests | Sort-Object Start) {
                    [pscustomobject]@{
                        PSTypeName      = 'OfficeCursor.Word.RangeTextChange'
                        Document        = [string]$document.FullName
                        Start           = $request.Start
                        End             = $request.End
                        PreviousText    = $request.ExpectedText
                        ReplacementText = $ReplacementText
                        Applied         = $false
                        Verified        = $false
                    }
                }
                continue
            }

            $results = [Collections.Generic.List[object]]::new()
            Invoke-WordUndoRecord -Application $word -Name 'Office Cursor: replace range text' -Action {
                foreach ($request in $orderedRequests) {
                    $range = $document.Range($request.Start, $request.End)
                    $range.Text = $ReplacementText
                    $actualReplacement = [string]$document.Range(
                        $request.Start,
                        $request.Start + $ReplacementText.Length
                    ).Text

                    $results.Add([pscustomobject]@{
                        PSTypeName      = 'OfficeCursor.Word.RangeTextChange'
                        Document        = [string]$document.FullName
                        Start           = $request.Start
                        End             = $request.Start + $ReplacementText.Length
                        PreviousText    = $request.ExpectedText
                        ReplacementText = $ReplacementText
                        Applied         = $true
                        Verified        = $actualReplacement -ceq $ReplacementText
                    })
                }
            }

            $results | Sort-Object Start
        }
    }
}

