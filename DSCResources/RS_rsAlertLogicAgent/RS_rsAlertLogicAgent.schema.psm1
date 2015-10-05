Configuration RS_rsAlertLogicAgent
{
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [Parameter(Mandatory = $true)]
        [System.String]
        $RegistrationKey,

        [System.String]
        $DownloadLink = "https://scc.alertlogic.net/software/al_agent-LATEST.msi",

        [System.String]
        $DownloadPath = "C:\DevOps\Packages\AlertLogic",

        [ValidateSet("host", "role")]
        [System.String]
        $Mode = "role",

        [System.String]
        $SensorHost,

        [System.Int16]
        $SensorPort
    )


    # Make sure the Download Destination exists
    File DownloadFolder 
    {
        Ensure          = "Present"
        Type            = "Directory"
        DestinationPath = $DownloadPath
    }


    # Set static name for Destination file, then download the installer
    $FileName = "al_agent-installer.msi"
    $OutFile = (Join-Path -Path $DownloadPath -ChildPath $FileName)
    Script DownloadInstaller
    {
        GetScript = {
            @{
                Result = $using:OutFile
            }
        }

        SetScript = {
            $OutFile = $using:OutFile
            if ($using:Ensure -eq "Present")
            {
                Invoke-WebRequest -Uri $using:DownloadLink -OutFile $OutFile
            }
            else
            {
                Remove-Item -Path $OutFile -Force -ErrorAction SilentlyContinue
            }
        }
        TestScript = {
            $OutFile = $using:OutFile
            $Complying = ($using:Ensure -ne "Present") -xor (Test-Path -Path $OutFile -PathType Leaf)
            $Complying
        }
        DependsOn = "[File]DownloadFolder"
    }


    # Construct the Arguments String passed to the msi installer
    $SensorHostParam = ""
    if ($SensorHost)
    {
        $SensorHostParam = " sensor_host=$SensorHost"
    }
    $SensorPortParam = ""
    if ($SensorPort)
    {
        $SensorPortParam = " sensor_port=$SensorPort"
    }
    $Parameters = "prov_key=$RegistrationKey prov_only=$Mode$SensorHostParam$SensorPortParam"
    

    # Install the msi Package
    Package AlertLogicAgent
    {
        Ensure = $Ensure
        Name = "AL Agent"
        Path = $OutFile
        Arguments = $Parameters
        ProductId = ""
        DependsOn = "[Script]DownloadInstaller"
    }


    # Set the startupt type of the agent service to Automatic and Start the service
    if ($Ensure -eq "Present")
    {
        Service AlertLogicAgent
        {
            Name = "al_agent"
            State = "Running"
            StartupType = "Auomatic"
            DependsOn = "[Package]AlertLogicAgent"
        }
    }
}
