using namespace System.Collections.Generic

function ConvertTo-DhcpSearchSuffixList {
    <#
    .SYNOPSIS
    Convert to a binary encoded DHCP search suffix list
    .DESCRIPTION
    Convert to a binary encoded DHCP search suffix list. Returns an array of
    strings suitable for Set-DhcpServerv4OptionValue.
    .PARAMETER SearchDomains
    Array of search domains
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '', Scope='Function')]
    [OutputType([string[]])]
    [CmdletBinding()]
    param(

        [Parameter(
            Mandatory,
            Position=1
        )]
        [string[]]
        $SearchDomains

    )

    # this function outputs the length of the string followed by the
    # integer values for each character
    function __ConvertToOption119BinaryData ( [string]$String ) {

        # if the string is empty we don't want to return anything
        if ( [string]::IsNullOrWhiteSpace( $String ) ) { return }

        $String.Split('.').ForEach({

            $_.Length

            $_.ToCharArray().ForEach({ [int]$_ })

        })

    }

    # holds domains while processing
    $DomainList = [List[pscustomobject]]::new()

    # holds binary data prior to conversion
    $BinaryData = [List[int]]::new()

    $SearchDomains | ForEach-Object {

        # create a PSCustomObject with the needed attributes
        
        $DomainObject = $_.ToLower() | Select-Object `
            @{ N = 'Name';          E = { $_                                            } },
            # the next line triggers PSAvoidAssignmentToAutomaticVariable, however
            # this is the most efficient way to get all segments of the domain
            # i.e. host.domain.tld ends up a list containing: host.domain.tld, domain.tld, tld
            @{ N = 'Parts';         E = { do { $_ } while ( $_ = $_.Split('.',2)[1] )   } },
            @{ N = 'Linked';        E = { $null                                         } },
            @{ N = 'Offset';        E = { $null                                         } },
            @{ N = 'StartIndex';    E = { $BinaryData.Count                             } }

        # if there is a domain in $DomainList that has a matching part
        # link the domain to the current $DomainObject
        $DomainObject.Linked = $DomainList |
            Where-Object { $_.Parts | Where-Object { $_ -in $DomainObject.Parts } | Select-Object -First 1 } |
            Select-Object -First 1

        # if there is a linked domain we process the link first
        if ( $DomainObject.Linked ) {

            # find the matching part
            $MatchingPart = $DomainObject.Linked.Parts |
                Where-Object { $_ -in $DomainObject.Parts } |
                Select-Object -First 1

            # find the offset of the matched part in the full domain name
            $DomainObject.Offset = $DomainObject.Linked.Name.IndexOf( $MatchingPart )

            # domain has a unique part, encode that and then add a pointer
            if ( $DomainObject.Name -ne $MatchingPart ) {

                $UniquePart = $DomainObject.Name -replace "\.$MatchingPart$"

                __ConvertToOption119BinaryData $UniquePart |
                    ForEach-Object { $BinaryData.Add( $_ ) }
                    
            }

            # add the pointer
            $BinaryData.Add( 192 )
            $BinaryData.Add( ( $DomainObject.Linked.StartIndex + $DomainObject.Offset ) )

        }
        
        # if there is no linked domain we just output the encoded domain
        else {

            __ConvertToOption119BinaryData $DomainObject.Name |
                ForEach-Object { $BinaryData.Add( $_ ) }

            $BinaryData.Add( 0 )

        }

        $DomainList.Add( $DomainObject )

    }

    # output the encoded search suffix list
    $BinaryData | ForEach-Object { '0x{0:x2}' -f $_ }

}

function ConvertFrom-DhcpSearchSuffixList {
    <#
    .SYNOPSIS
    Convert from a binary encoded DHCP search suffix list
    .DESCRIPTION
    Convert from a binary encoded DHCP search suffix list. Returns an array of
    strings.
    .PARAMETER SearchList
    The binary encoded search list
    #>
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
    
        [Parameter(
            Mandatory,
            Position = 1
        )]
        [int[]]
        $SearchList
        
    )

    $Index              = 0                     # where we are in the array
    $RealIndex          = 0                     # where we are in the array, if we have followed a pointer
    $StartIndex         = $null                 # where the current domain starts (just for verbosity)
    $EndIndex           = $null                 # where the current domain ends
    $LastIndex          = $SearchList.Count - 1 # where the array ends

    # holds the current domain's chars while being collected
    $CurrentDomainChars = [List[char]]::new()

    # note that the ORDER of the operations inside this while loop is critical
    while ( $true ) {

        Write-Debug "$Index - start value $($SearchList[$Index])"

        # if the current index indicates the end of the domain (0x00) return
        # and reset or exit
        if ( $SearchList[ $Index ] -eq 0x00 ) {

            Write-Debug "$Index - found end of domain"

            # output the current domain and reset
            $CurrentDomainChars -join ''
            $CurrentDomainChars.Clear()
            
            # check if $RealIndex -gt $Index, if so it means we followed a
            # pointer and $Index should be reset
            if ( $RealIndex -gt $Index ) {

                Write-Debug "$Index - setting `$Index to `$RealIndex"

                $Index = $RealIndex

            }

            
            # check for $LastIndex and exit if found
            if ( $Index -eq $LastIndex ) {

                Write-Debug "$Index - `$Index -eq `$LastIndex, done"

                return

            }

            $Index ++

        }

        # if the current index indicates a pointer (0Xc0) we set index to the
        # value of the next index
        if ( $SearchList[ $Index ] -eq 0xc0 ) {

            Write-Debug "$Index - found pointer"
        
            $RealIndex = $Index + 1
            $Index = $SearchList[ $RealIndex ]

        }

        # if $EndIndex is not set we set to value of $Index + the value
        # contained in the current index
        if ( -not $EndIndex ) {

            Write-Debug "$Index - setting `$EndIndex"

            $StartIndex = $Index + 1

            $EndIndex = $StartIndex + $SearchList[ $Index ]

            # we append a '.' if the $CurrentDomainChars has any items since setting
            # the $EndIndex indicates that we are at a sub-domain boundry
            if ( $CurrentDomainChars.Count -gt 0 ) {

                $CurrentDomainChars.Add( '.' )

            }

            $Index ++

        }

        # while the value of $Index is less than $EndIndex we append the value
        # to $CurrentDomainChars
        if ( $Index -le $EndIndex ) {

            Write-Debug "$Index - appending value $($SearchList[ $Index ])"

            $CurrentDomainChars.Add( $SearchList[ $Index ] )

            $Index ++

        }

        # if the current index is equal to $EndIndex we reset $EndIndex
        if ( $Index -eq $EndIndex ) {

            Write-Debug "$Index - resetting `$EndIndex"

            $EndIndex = $null

        }

        Write-Debug "$Index - end value $($SearchList[$Index])"

    }

}