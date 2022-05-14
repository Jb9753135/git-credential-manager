# Arguments
param ($CONFIGURATION)

# Perform pre-execution checks
if (!$CONFIGURATION)
{
    $CONFIGURATION = "Debug"
}

# Directories
$THISDIR = $pwd.path
$ROOT = (Get-Item $THISDIR).parent.parent.parent.FullName
$PAYLOAD = "$ROOT/out/windows/Installer.Windows/bin/$CONFIGURATION/net472/win-x86"

# Layout and pack
.\layout.ps1 -Configuration "$CONFIGURATION" -Output "$PAYLOAD"
dotnet build --configuration="$CONFIGURATION"

Write-Output "Build of Installer.Windows complete."