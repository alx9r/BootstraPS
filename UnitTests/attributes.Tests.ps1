Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe Get-CustomAttributeArgument {
    Add-Type @'
    class a_83753c70Attribute : System.Attribute
    {
        public a_83753c70Attribute (int a, int b) {}
    }
    public enum e_83753c70
    {
        [a_83753c70(1,2)]A
    }
'@
    $ca = [e_83753c70] | Get-MemberField A | Get-FieldCustomAttribute 'a_83753c70'
    Context 'whole object' {
        It 'returns one object' {
            $r = $ca | Get-CustomAttributeArgument -Position 0
            $r.Count | Should be 1
        }
        It 'returns argument object' {
            $r = $ca | Get-CustomAttributeArgument -Position 0
            $r | Should beOfType([System.Reflection.CustomAttributeTypedArgument])
        }
        It 'returns nothing for non-existent argument' {
            $r = $ca | Get-CustomAttributeArgument -Position 2
            $r | Should beNullOrEmpty
        }
    }
    Context 'value only' {
        It 'returns value' {
            $r = $ca | Get-CustomAttributeArgument -Position 0 -ValueOnly
            $r | Should -Be 1
        }
    }
}
}
