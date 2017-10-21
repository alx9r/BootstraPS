Get-Module Bootstraps | Remove-Module
Import-Module "$PSScriptRoot\..\Bootstraps.psm1"

InModuleScope Bootstraps {

Describe Get-MemberField {
    Add-Type 'public enum e_cebb5432 {a,b}'
    It 'returns one parameter info object for existent field' {
        $r = [e_cebb5432] | Get-MemberField a
        $r.Count | Should be 1
        $r.Name | Should be 'a'
        $r | Should beOfType ([System.Reflection.FieldInfo])
    }
    It 'returns nothing for non-existent field' {
        $r = [e_cebb5432] | Get-MemberField x
        $r | Should beNullOrEmpty
    }
    It 'returns all fields for omitted field name' {
        $r = [e_cebb5432] | Get-MemberField
        $r.Count | Should be 3
    }
    It 'returns value__ for no input fields' {
        Add-Type 'public enum e_1ee4631e {}'
        $r = [e_1ee4631e] | Get-MemberField
        $r.Name | Should -Be 'value__'
    }
}

Describe Get-FieldCustomAttribute {
    Add-Type @'
    class a_2a05b41bAttribute : System.Attribute
    {
        public a_2a05b41bAttribute () {}
    }
    public enum e_2a05b41b
    {
        [a_2a05b41b()]A
    }
'@
    It 'returns one object' {
        $r = [e_2a05b41b] | Get-MemberField | Get-FieldCustomAttribute 'a_2a05b41b'
        $r.Count | Should be 1
    }
    It 'returns attribute object' {
        $r = [e_2a05b41b] | Get-MemberField | Get-FieldCustomAttribute 'a_2a05b41b'
        $r | Should beOfType ([System.Reflection.CustomAttributeData])
    }
    It 'returns nothing for non-existent attribute' {
        $r = [e_2a05b41b] | Get-MemberField | Get-FieldCustomAttribute 'non-existent'
        $r | Should beNullOrEmpty
    }
}
}