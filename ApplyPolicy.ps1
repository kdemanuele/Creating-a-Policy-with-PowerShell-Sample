Install-Module Az.Accounts -AllowClobber -Scope CurrentUser
Install-Module Az.Resources -AllowClobber -Scope CurrentUser

try {
    Get-AzSubscription  1>$null 2>$null
} catch {
    $ARM_Password = ConvertTo-SecureString -String $env:SUBSCRIPTION_CLIENT_SECRET -AsPlainText -Force
    $Credentials = New-Object -TypeName System.Management.Automation.PSCredential($env:SUBSCRIPTION_CLIENT_ID, $ARM_PASSWORD)
    Connect-AzAccount -ServicePrincipal -Credential $Credentials -Tenant $env:TENANT_ID
}

# Fetching an In-Built Policy to copy information
Get-AzPolicyDefinition | `
    Where-Object {$_.Properties.metadata.category -eq "Tags"} | `
    Select-Object { $_.Properties.DisplayName }
$Policy = Get-AzPolicyDefinition | Where-Object { $_.Properties.DisplayName -eq 'Add or replace a tag on resources'}
Write-Host -ForegroundColor Green "Policy IF"
$Policy.Properties.PolicyRule.if| ConvertTo-Json
Write-Host -ForegroundColor Green "Policy THEN"
$Policy.Properties.PolicyRule.then | ConvertTo-Json
Write-Host -ForegroundColor Green "Policy THEN-DETAILS"
$Policy.Properties.PolicyRule.then.details | ConvertTo-Json

$PolicyMetadata = $Policy.Properties.Metadata | ConvertTo-Json
$PolicyParameters = $Policy.Properties.Parameters | ConvertTo-Json

$PolicyRuleFile = ".\storage_tag_enforcement.json"

# Creating a new Custom Policy
$StorageTagPolicy = New-AzPolicyDefinition `
    -Name 'StorageTag' `
    -DisplayName "Tag on Storage Accounts" `
    -Policy $PolicyRuleFile `
    -Parameter $PolicyParameters `
    -Metadata $PolicyMetadata

# Assign at Subscription Level
$SubscriptionId = Get-AzSubscription | Select-Object -First 1 -ExpandProperty Id

$PolicyAssignment = New-AzPolicyAssignment `
    -Name 'StorageTag' `
    -PolicyDefinition $StorageTagPolicy `
    -Scope "/subscriptions/$($SubscriptionId)" `
    -AssignIdentity `
    -Location "West Europe" `
    -PolicyParameterObject @{
        'tagName' = 'label'
        'tagValue' = 'policy-applied'
    }

Start-AzPolicyRemediation -Name "Set tag on all storage accounts" -PolicyAssignmentId $PolicyAssignment.ResourceId