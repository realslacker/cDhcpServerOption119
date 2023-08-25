using module ..\..\xDhcpServerOption119.psm1


function Test-TargetResource {

    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(

        [Parameter()]
        [ValidateSet( 'Present', 'Absent' )]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $PolicyName,
        
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $SearchDomains

    )

    $Resource = Get-TargetResource @PSBoundParameters

    $InDesiredState = `
        $Ensure -eq $Resource.Ensure -and
        -not( Compare-Object -ReferenceObject $SearchDomains -DifferenceObject $Resource.SearchDomains )

    return $InDesiredState

}


function Get-TargetResource {

    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(

        [Parameter()]
        [ValidateSet( 'Present', 'Absent' )]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $PolicyName,
        
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $SearchDomains

    )

    $Resource = @{
        Ensure        = 'Absent'
        PolicyName    = $PolicyName
        SearchDomains = [string[]]@()
    }

    if ( -not( Get-Module DhcpServer -ListAvailable ) ) {
        return $Resource
    }

    $Current = Get-DhcpServerv4OptionValue -PolicyName $PolicyName -OptionId 119 -ErrorAction SilentlyContinue

    if ( $Current ) {
        $Resource.Ensure        = 'Present'
        $Resource.SearchDomains = [string[]]( ConvertFrom-DhcpSearchSuffixList -SearchList $Current.Value )
    }

    return $Resource

}


function Set-TargetResource {

    [CmdletBinding()]
    param(

        [Parameter()]
        [ValidateSet( 'Present', 'Absent' )]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $PolicyName,
        
        [Parameter(Mandatory = $true)]
        [System.String[]]
        $SearchDomains

    )

    Import-Module -Name DhcpServer -Verbose:$false -ErrorAction Stop

    $Resource = Get-TargetResource @PSBoundParameters

    $InDesiredState = `
        $Ensure -eq $Resource.Ensure -and
        -not( Compare-Object -ReferenceObject $SearchDomains -DifferenceObject $Resource.SearchDomains )

    if ( $InDesiredState ) {
        
        Write-Verbose 'Option value in desired state.'
        return
    
    }

    Write-Verbose 'Option value configuration starting.'

    if ( $Ensure -eq 'Absent' -and $Resource.Ensure -eq 'Present' ) {

        Remove-DhcpServerv4OptionValue -PolicyName $PolicyName -OptionId 119 -Confirm:$false > $null
        return

    }

    $Value = ConvertTo-DhcpSearchSuffixList -SearchDomains $SearchDomains

    Set-DhcpServerv4OptionValue -PolicyName $PolicyName -OptionId 119 -Value $Value -Force -Confirm:$false > $null

}

