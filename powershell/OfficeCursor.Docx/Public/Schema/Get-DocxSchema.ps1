function Get-DocxSchema {
    <#
    .SYNOPSIS
    Lists or inspects reusable structured-data contracts registered by OfficeCursor.Docx.
    .DESCRIPTION
    With no name, lists the module's schema catalog. With -Name, projects that
    Draft 2020-12 JSON Schema into discoverable property records. -Path filters
    those records and supports wildcards. -AsJson returns the raw catalog or
    selected schema instead.
    .EXAMPLE
    Get-DocxSchema
    .EXAMPLE
    Get-DocxSchema -Name ParagraphEdit -Path RunFormatting
    .EXAMPLE
    Get-DocxSchema -Name ParagraphEdit -AsJson
    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [SupportsWildcards()][string]$Path,
        [switch]$AsJson
    )

    if ($Path -and -not $Name) { throw '-Path requires -Name.' }
    if ($AsJson -and $Path) { throw '-Path cannot be combined with -AsJson.' }

    $catalog = Get-DocxSchemaCatalogData
    if (-not $Name) {
        if ($AsJson) { return Get-DocxSchemaCatalogData -Raw }
        foreach ($registration in $catalog.schemas.PSObject.Properties) {
            $schema = Get-DocxSchemaData -Name $registration.Name
            [pscustomobject]@{
                PSTypeName  = 'OfficeCursor.Docx.SchemaRegistration'
                Name        = $registration.Name
                Version     = $schema.'x-version'
                Title       = $schema.title
                Description = $schema.description
                File        = $registration.Value.file
                UsedBy      = @($registration.Value.usedBy)
            }
        }
        return
    }

    if ($AsJson) { return Get-DocxSchemaData -Name $Name -Raw }
    $schema = Get-DocxSchemaData -Name $Name
    $records = [Collections.Generic.List[object]]::new()

    function Resolve-SchemaReference {
        param([object]$Root, [string]$Reference)
        if (-not $Reference.StartsWith('#/')) {
            throw "Only local JSON Schema references are supported by discovery: $Reference"
        }
        $node = $Root
        foreach ($segment in $Reference.Substring(2).Split('/')) {
            $name = $segment.Replace('~1', '/').Replace('~0', '~')
            $property = $node.PSObject.Properties | Where-Object Name -CEQ $name | Select-Object -First 1
            if (-not $property) { throw "JSON Schema reference could not be resolved: $Reference" }
            $node = $property.Value
        }
        return $node
    }

    function Add-SchemaPropertyRecords {
        param(
            [object]$Root,
            [object]$Definition,
            [string]$Prefix,
            [string[]]$InheritedActions,
            [Collections.Generic.List[object]]$Destination
        )
        $required = @($Definition.required)
        foreach ($property in $Definition.properties.PSObject.Properties) {
            $value = $property.Value
            $reference = $value.'$ref'
            $resolved = if ($reference) { Resolve-SchemaReference -Root $Root -Reference $reference } else { $value }
            $type = if ($value.type) { [string]$value.type }
                elseif ($resolved.type) { [string]$resolved.type }
                elseif ($reference) { ($reference -split '/')[-1] }
                elseif ($null -ne $value.const) { $value.const.GetType().Name }
                else { 'object' }
            $allowed = if ($value.enum) { @($value.enum) }
                elseif ($resolved.enum) { @($resolved.enum) }
                elseif ($null -ne $value.const) { @($value.const) }
                else { @() }
            $propertyPath = if ($Prefix) { "$Prefix.$($property.Name)" } else { $property.Name }
            $propertyActions = @($value.'x-applicableActions')
            if (-not $propertyActions.Count) { $propertyActions = $InheritedActions }
            $Destination.Add([pscustomobject]@{
                PSTypeName         = 'OfficeCursor.Docx.SchemaProperty'
                SchemaName        = $Name
                Path              = $propertyPath
                Type              = $type
                Required          = $property.Name -in $required
                RequiredForActions = @($value.'x-requiredForActions')
                ApplicableActions = $propertyActions
                AllowedValues     = $allowed
                Minimum           = if ($null -ne $value.minimum) { $value.minimum } else { $resolved.minimum }
                Maximum           = if ($null -ne $value.maximum) { $value.maximum } else { $resolved.maximum }
                Default           = if ($null -ne $value.default) { $value.default } else { $resolved.default }
                Pattern           = if ($value.pattern) { $value.pattern } else { $resolved.pattern }
                Description       = if ($value.description) { $value.description } else { $resolved.description }
            })
            if ($resolved.properties) {
                Add-SchemaPropertyRecords -Root $Root -Definition $resolved -Prefix $propertyPath `
                    -InheritedActions $propertyActions -Destination $Destination
            }
        }
    }

    $rootDefinition = if ($schema.type -eq 'array' -and $schema.items.'$ref') {
        Resolve-SchemaReference -Root $schema -Reference $schema.items.'$ref'
    }
    else { $schema }
    Add-SchemaPropertyRecords -Root $schema -Definition $rootDefinition -Prefix '' `
        -InheritedActions @() -Destination $records

    $result = $records
    if ($Path) {
        if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path)) {
            $result = @($records | Where-Object { $_.Path -ilike $Path })
        }
        else {
            $result = @($records | Where-Object { $_.Path -ieq $Path -or $_.Path -ilike "$Path.*" })
        }
        if (-not $result.Count) { throw "Schema path was not found in '$Name': $Path" }
    }
    return $result
}
