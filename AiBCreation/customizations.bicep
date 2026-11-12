// Define the parameter for the Storage account name


// Define the customizations for the image
var customizations = [
  // Create a apps directory on the OS drive
  {
    type: 'PowerShell'
    name: 'Create Apps Directory on OS drive'
    runElevated: false
    runAsSystem: false
    inline: [
      // Use double backslashes to represent a single backslash in the file path
      'New-Item -ItemType Directory -Force -Path $env:SystemDrive\\apps\\'
    ]
  }

 
  // Install Windows updates, excluding preview updates
  {
    type: 'WindowsUpdate'
    searchCriteria: 'IsInstalled=0'
    filters: [
      'exclude:$_.Title -like \'*Preview*\'' // Exclude preview updates
      'include:$true'
    ]
    updateLimit: 20
  }

  // Restart the system after Windows updates have completed
  {
    type: 'WindowsRestart'
    restartCheckCommand: 'write-host \'restarting post Windows Updates\''
    restartTimeout: '10m'
  }

  // Copy BGInfo from the Storage account to the temporary directory
  /*
  {
    type: 'File'
    name: 'Copy BGInfo from Storage account'
    sourceUri: 'https://${stgaccountname}.blob.${environmentMetadata.suffixes.storage}/iac/bginfo/BGInfo.zip'
    destination: '$env:SystemDrive\\apps\\BGInfo.zip'
  }
*/

   // Install any Windows updates, that are left or needed after app installs
   {
    type: 'WindowsUpdate'
    searchCriteria: 'IsInstalled=0'
    filters: [
      'exclude:$_.Title -like \'*Preview*\'' // Exclude preview updates
      'include:$true'
    ]
    updateLimit: 20
  }

  // Restart the system after Windows updates have completed and fresh restart before sysprep.
  {
    type: 'WindowsRestart'
    restartCheckCommand: 'write-host \'restarting post image customisation\''
    restartTimeout: '10m'
  }

]

// Output the customizations array
output customizationsOutput array = customizations
