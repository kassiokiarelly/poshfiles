function Get-GitRepositories
{
    Get-ChildItem -Directory | Where-Object { Test-Path "$($_.FullName)/.git" }
}

function Test-IsRepositoryUpToDate
{
    $output = Invoke-Expression -Command "git status"
    $matchUpToDate = $output | Select-String "up to date"
    $matchUpToDate.Length -gt 0
}

function Get-Branch
{
    git branch --show-current
}

function Get-DefaultBranch
{
    $branchList = Invoke-Expression -Command "git branch"
    if (($branchList | Select-String "master").Matches.Count -gt 0 )
    {
        "master"
    }
    elseif (($branchList | Select-String "main").Matches.Count -gt 0 )
    {
        "main"
    }
    else 
    {
        "develop"
    }
}

function Sync-Repositories
{
    $rep_dir = $PWD
    $repo_list = Get-GitRepositories

    foreach ($item in $repo_list) 
    {
        Write-Host "Checking repository: $($item.Name)" -ForegroundColor Blue
        Set-Location -Path $item.FullName
        $actualBranch = Get-Branch
        $defaultBranch = Get-DefaultBranch
        
        if ($actualBranch -ne $defaultBranch) 
        {
            git checkout $defaultBranch
        }

        Invoke-Expression -Command "git fetch --all"
        $isUpToDate = Test-IsRepositoryUpToDate
        if (!$isUpToDate)
        {
            git pull
        }

        if ($actualBranch -ne $defaultBranch) 
        {
            git checkout $actualBranch
        }
    }

    Set-Location -Path $rep_dir
    Write-Host "Done pulling git repositories at $rep_dir" -ForegroundColor Green
}

function Get-GitUsernName 
{
    git config --get user.name
}

function Get-GitLog
{
    param (
        # Start date to export git diff yyyy-MM-dd 
        [Parameter(Mandatory=$true)]
        [string]
        ${DateFrom}
    )
    $author  = Get-GitUsernName
    $format  =  "%h - %an<%ae>, %ad : %s"
    Invoke-Expression -Command "git log -p --author='$author' --since='$DateFrom' --pretty='format:$format'"
}

function Export-Diff()
{
    param (
        # Path where to export diff file 
        [Parameter(Mandatory=$true)]
        [string]
        ${OutputDir},
        # Start date to export git diff yyyy-MM-dd 
        [Parameter(Mandatory=$true)]
        [string]
        ${DateFrom}        
    )

    $directoryName = Split-Path -Path $PWD -Leaf
    $branch = Get-Branch
    $escapedBranchName = $branch -replace "[\\/]", "-"
    $outputFile = Join-Path $OutputDir "${directoryName}_${escapedBranchName}.diff"
    $log = Get-GitLog -DateFrom $dateFrom

    if ($log)
    {
        $log | Out-File -FilePath $outputFile
    }
}

function Export-GitDiff()
{
    param (
        # Path where to find git repositories 
        [Parameter(Mandatory=$true)]
        [string]
        ${Path},
        # Directory where to export diff files 
        [Parameter(Mandatory=$true)]
        [string]
        ${DirName},        
        # Start date to export git diff yyyy-MM-dd 
        [Parameter(Mandatory=$true)]
        [string]
        ${DateFrom}
    )

    $saveTo  = Join-Path $env:USERPROFILE "Documents" "GitDiff" $DirName
    Set-Location -Path $Path
    New-Item -Path $saveTo -ItemType "Directory" -Force
    $currentDir = $PWD
    $repo_list = Get-GitRepositories

    foreach ($item in $repo_list) 
    {
        Write-Host "Creating diff for repository: $($item.Name)" -ForegroundColor Blue
        Set-Location -Path $item.FullName
        $branch = Get-Branch
        $defaultBranch = Get-DefaultBranch

        if ($branch -ne $defaultBranch) 
        {
            Export-Diff -OutputDir $saveTo -DateFrom $DateFrom
            git checkout $defaultBranch
        }

        Export-Diff -OutputDir $saveTo -DateFrom $DateFrom

        if ($branch -ne $defaultBranch) 
        {
            git checkout $branch
        }
    }

    Set-Location -Path $currentDir
    Write-Host "Done exporting diff files at $saveTo" -ForegroundColor Green

    Write-Host "Creating zip with diff files" -ForegroundColor Blue
    $zipSource = "$saveTo\*.diff"
    $zipFile = Join-Path $saveTo "$DirName.zip"
    Compress-Archive -Path $zipSource -DestinationPath $zipFile
    Write-Host "Zip file created!" -ForegroundColor Green
}