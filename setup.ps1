Clear-Host
write-host "Script started at $(Get-Date)"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

# Install Azure ML CLI
az extension remove -n azure-cli-ml
az extension remove -n ml
az extension add -n ml -y

# Handle cases where the user has multiple subscriptions
$subs = Get-AzSubscription | Select-Object
if($subs.GetType().IsArray -and $subs.length -gt 1){
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    for($i = 0; $i -lt $subs.length; $i++)
    {
            Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1)
    {
            $enteredValue = Read-Host("Enter 0 to $($subs.Length - 1)")
            if (-not ([string]::IsNullOrEmpty($enteredValue)))
            {
                if ([int]$enteredValue -in (0..$($subs.Length - 1)))
                {
                    $selectedIndex = [int]$enteredValue
                    $selectedValidIndex = 1
                }
                else
                {
                    Write-Output "Please enter a valid subscription number."
                }
            }
            else
            {
                Write-Output "Please enter a valid subscription number."
            }
    }
    $selectedSub = $subs[$selectedIndex].Id
    Select-AzSubscription -SubscriptionId $selectedSub
    az account set --subscription $selectedSub
}

# Set password for the SQL Database
$sqlUser = "sqladminuser"
$sqlPassword = "Password.123"

# Register resource providers
Write-Host "Registering resource providers...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute", "Microsoft.MachineLearningServices"
foreach ($provider in $provider_list){
    $result = Register-AzResourceProvider -ProviderNamespace $provider
    $status = $result.RegistrationState
    Write-Host "$provider : $status"
}

# Generate unique random suffix
[string]$suffix =  -join ((48..57) + (97..122) | Get-Random -Count 7 | % {[char]$_})
Write-Host "Your randomly-generated suffix for Azure resources is $suffix"
$resourceGroupName = "techconf2023-$suffix"

# Select region
$Region = "westeurope"

# Create resource group
Write-Host "Creating $resourceGroupName resource group in $Region ..."
New-AzResourceGroup -Name $resourceGroupName -Location $Region | Out-Null

# Create Azure Machine Learning workspace
$amlWorkspace = "aml$suffix"
Write-Host "Creating $amlWorkspace Azure Machine Learning workspace in $resourceGroupName resource group..."
az ml workspace create --name $amlWorkspace --resource-group $resourceGroupName --no-wait

# Create Synapse workspace
$synapseWorkspace = "synapse$suffix"
$dataLakeAccountName = "datalake$suffix"
$sparkPool = "spark$suffix"
$sqlDatabaseName = "sql$suffix"

Write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile "setup.json" `
    -Mode Incremental `
    -workspaceName $synapseWorkspace `
    -dataLakeAccountName $dataLakeAccountName `
    -sparkPoolName $sparkPool `
    -sqlDatabaseName $sqlDatabaseName `
    -sqlUser $sqlUser `
    -sqlPassword $sqlPassword `
    -uniqueSuffix $suffix `
    -Force

# Make the current user and the Synapse service principal owners of the data lake storage
Write-host "Granting permissions on the $dataLakeAccountName storage account..."
Write-host "(you can ignore any warnings!)"
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
$id = (Get-AzADServicePrincipal -DisplayName $synapseWorkspace).id
New-AzRoleAssignment -Objectid $id -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;

# Upload training file for customer churn prediction
Write-host "Uploading training file..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
$storageContext = $storageAccount.Context
$file = "./data/ml/customer_churn.csv"
$blobPath = "data/ml/customer_churn.csv"
Set-AzStorageBlobContent -File $file -Container "files" -Blob $blobPath -Context $storageContext

# Create database
Write-host "Creating the $sqlDatabaseName database..."
sqlcmd -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -I

# Pause SQL Pool
Write-host "Pausing the $sqlDatabaseName SQL Pool..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

# Create linked service for HTTP data source
Set-AzSynapseLinkedService -WorkspaceName $synapseWorkspace -Name "HttpServer1" -DefinitionFile "./linkedService/HttpServer1.json"

# Create HTTP datasets
Write-host "Creating HTTP datasets..."
Get-ChildItem "./dataset/*HTTP.json" -File | Foreach-Object {
    $name = $_.Basename
    $filepath = $_.FullName
    Set-AzSynapseDataset -WorkspaceName $synapseWorkspace -Name $name -DefinitionFile $filepath
}

# Create CSV datasets
Write-host "Creating CSV datasets..."
Get-ChildItem "./dataset/*CSV.json" -File | Foreach-Object {
    $name = $_.Basename
    $filepath = $_.FullName
    $filepathtemp = "./dataset/$name$suffix.json"
    $datasetJSON = Get-Content -Raw -Path $filepath
    $datasetJSON = $datasetJSON.Replace("synapsexxxxxxx", $synapseWorkspace)
    Set-Content -Path $filepathtemp -Value $datasetJSON
    Set-AzSynapseDataset -WorkspaceName $synapseWorkspace -Name $name -DefinitionFile $filepathtemp
    Remove-Item $filepathtemp
}

# Create data flows
Write-Host "Creating data flows..."
Get-ChildItem "./dataflow/*.json" -File | Foreach-Object {
    $name = $_.Basename
    $filepath = $_.FullName
    Set-AzSynapseDataFlow -WorkspaceName $synapseWorkspace -Name $name -DefinitionFile $filepath
}

# Create pipelines
Write-Host "Creating pipelines..."
Get-ChildItem "./pipeline/*.json" -File | Foreach-Object {
    $name = $_.Basename
    $filepath = $_.FullName
    Set-AzSynapsePipeline -WorkspaceName $synapseWorkspace -Name $name -DefinitionFile $filepath
}

# Create SQL scripts
Write-Host "Creating SQL scripts..."
Get-ChildItem "./sqlscript/*.sql" -File | Foreach-Object {
    $filepath = $_.FullName
    Set-AzSynapseSqlScript -WorkspaceName $synapseWorkspace -DefinitionFile $filepath
}

# Create notebooks
Write-Host "Creating notebooks..."
Get-ChildItem "./notebook/*.ipynb" -File | Foreach-Object {
    $filepath = $_.FullName
    Set-AzSynapseNotebook -WorkspaceName $synapseWorkspace -DefinitionFile $filepath
}

write-host "Script completed at $(Get-Date)"