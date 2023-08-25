# xDhcpServerOption119
This DSC resource helps you to correctly configure DHCP option 119 on your Microsoft DHCP server. This module works best as an extension to [xDhcpServer](https://github.com/dsccommunity/xDhcpServer).

## Example

```powershell
Configuration DHCPServer {
    
    param (

        [string[]]
        $ComputerName = 'localhost'

    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xDhcpServer' -ModuleVersion '3.1.1'
    Import-DscResource -ModuleName 'xDhcpServerOption119' -ModuleVersion '0.9'

    Node $ComputerName {

        WindowsFeature DhcpServer {
            Name   = 'Dhcp'
            Ensure = 'Present'
        }

        xDhcpServerOptionDefinition Option119 {
            AddressFamily = 'IPv4'
            OptionId      = 119
            Name          = 'DNS Suffix Search List'
            Description   = 'List of search domains encoded per RFC1035'
            Type          = 'Byte'
            VendorClass   = ''
            DefaultValue  = '0x00'
            Multivalued   = $true
            Ensure        = 'Present'
            DependsOn     = '[WindowsFeature]DhcpServer'
        }

        # note that because SearchDomains expects a string[] you must always
        # use an array, even if there is only one domain
        DhcpServerOption119 ServerValue {
            SearchDomains = @( 'domain.tld' )
            Ensure        = 'Present'
            DependsOn     = '[xDhcpServerOptionDefinition]Option119'
        }

    }

}
```

