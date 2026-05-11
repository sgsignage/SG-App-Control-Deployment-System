# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SG App Control Client PS v1.1 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#
#
#  ------------------------------- What this script does from a high level: -------------------------------
#  ------------------------------------ Note - some of the logic has changed in v1.1 !!! -----------------------------------
#
# 1. Create variables/constants (though the 'constants' are just variables)
#
# 2. Create functions
#
# 3. Look up the ID of this workstation in the 'WorkstationList' table
#	(And exit the entire script if none is found)
#
# 4. Retrieve any policies to be deployed (from the 'PoliciesToBeDeployed' table) to this workstation and load into a list
#
# 5. Retrieve any policies to be removed (from the 'PoliciesToBeRemoved' table) to this workstation and load into a list
#
# 6. If there are any policies to be deployed, go ahead and deploy them (copy the actual file to the appropriate location on the workstation's HDD),
#    then remove the corresponding entry in the 'PoliciesToBeDeployed' table so that we don't keep trying to deploy this policy file
#
# 7. Now in v1.1, instead of removing all records from the 'DeployedPolicies' for this Workstation, we:
#    Cycle through all DeployedPolicies, and stuff them into '$PolicyLookupHashTable' (a hash table) for fast lookup later
#
# 8. If there are any policies to be removed, go ahead and remove them (delete the actual file from the appropriate location on the workstation's HDD),
#    then remove the corresponding entry in the 'PoliciesToBeRemoved' table so that we don't keep trying to delete this policy file
#
# 9. Cycle through every policy file on the workstation. Using each filename, 1st look up and see if there is a corresponding entry in the 'PolicyList' table.
#    If there is - simply add a record in the 'DeployedPolicies' table with the workstation ID and the found policy ID
#    If there is not - 1st add a record in the 'PolicyList' table, retrieving the ID of this new record, AND THEN add a record in the 'DeployedPolicies' table with the
#          workstation ID and the new Policy's ID
#
# 10. Update the last check in time for this workstation ('WorkstationList' table)
#
# 11. If a policy was removed or deployed, run the 'CiTool --refresh -json' command to refresh the workstation's local policies
#
#
# ------------------------------- End what this script does from a high level -------------------------------





# TO-DOS:
# 
# 1. Add logging
#
# 2. Add a check to verify that actual policy file exists (on policies page at the very least) at the deployment location (Currently D:\AppControlPoliciesReadyToDeploy)
#
#




Set-StrictMode -Version 2.0

$ThisScriptVersion = "1.1"

# Define our connection parameters
$ServerName = "MYSERVERNAME\MYSQLSERVERINSTANCE" # Include the instance here!
$DatabaseName = "SGAppControl"

# Define some other stuff
$ComputerName     = $env:COMPUTERNAME
$PolicySourcePath = "\\MYSERVERNAME\MYSHARETHATCONTAINSBINARYPOLICYFILES\"
$LocalPolicyPath  = "C:\Windows\System32\CodeIntegrity\CIPolicies\Active"
#$LocalPolicyPath  = "C:\Temp\App Control" # USE THIS ONE FOR TESTING
$PoliciesToBePulledDeployed = $false
$PoliciesToBeRemoved = $false
$LocalPolicyRefreshTrigger = $false
$MyWorkstationID = 0






Write-Host
Write-Host "********************** Welcome to SG App Control Client PS v$ThisScriptVersion*******************************"
Write-Host ""








########### Set up the connection string for all database connections ###########
$ConnString = "Server=$ServerName;Database=$DatabaseName;Integrated Security=True;" # This will even be used in our functions that access the database
$Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString) # This will not be used by functions that access the database (they will set up their own connections)










# **************************** BEGIN Remove-DBPolicyToBeDeployedOrRemovedIsCompletedRecord FUNCTION **********************
# This function will delete entries from the 'PoliciesToBeDeployed' table. It will be called after they have actually been deployed
# Note that it just deletes 1 record, using the ID of the record
function Remove-DBPolicyToBeDeployedOrRemovedIsCompletedRecord {
    param($PoliciesToBeDeployedOrRemovedID, $TableNameToUse) # These are the 2 parameters that this function accepts - the ID of the record to be deleted, and the actual table to delete from
    
    # The $TableNameToUse should either contain the value: PoliciesToBeDeployed or PoliciesToBeRemoved
    $DeleteQuery = "DELETE FROM $TableNameToUse WHERE ID = $PoliciesToBeDeployedOrRemovedID"

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $Command = New-Object System.Data.SqlClient.SqlCommand($DeleteQuery, $Connection)

    try {
        $Connection.Open()
        
        # ExecuteNonQuery returns the count of affected rows
        $RowsAffected = $Command.ExecuteNonQuery()
        
        if ($RowsAffected -gt 0) {
            Write-Host "Success! Deleted $RowsAffected record(s) from table, $TableNameToUse ." -ForegroundColor Green
        } else {
            Write-Host "No records found matching that ID in table, $TableNameToUse . Nothing deleted." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "SQL Error: $($_.Exception.Message)"
    }
    finally {
        $Connection.Close()
    }
    
}
# **************************** END Remove-DBPolicyToBeDeployedOrRemovedIsCompletedRecord FUNCTION **********************

























# **************************** BEGIN Add-DBDeployedPolicyRecord FUNCTION **********************
# This function will create a new record/entry in the 'DeployedPolicies' table.
# It accepts 2 parameters - the ID of the workstation (from the WorkstationList table), and the PolicyID (from the PolicyListTable)
# This function will get called/used when we are cycling through all of the policy files on the workstation and we want to enter
#     a record into the 'DeployedPolicies' table for each policy file
function Add-DBDeployedPolicyRecord {
    param($IDOfWorkstation, $IDOfPolicy) # These are the 2 parameters that this function accepts - the ID of the Workstation, and the ID of the Policy
    
    $InsertQuery = "INSERT INTO DeployedPolicies (WorkstationID, PolicyID) VALUES ($IDOfWorkstation, $IDOfPolicy)"

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $Command = New-Object System.Data.SqlClient.SqlCommand($InsertQuery, $Connection)

    try {
        $Connection.Open()
        $RowsAffected = $Command.ExecuteNonQuery()
        Write-Host "Success! $RowsAffected row(s) added."
    }
    catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
    finally {
        $Connection.Close()
    }
    
}
# **************************** END Add-DBDeployedPolicyRecord FUNCTION **********************




















# **************************** BEGIN Add-DBNewPolicyRecord FUNCTION **********************
# This function will create a new record/entry in the 'PolicyList' table.
# It accepts 2 parameters - a Policy File Name, and a Friendly Policy Name
# It will only get called/used when a policy file on a workstation is found that is not already in the 
#       PolicyList table (this shouldn't happen too often)
function Add-DBNewPolicyRecord {
    param($PolicyFileName, $FriendlyPolicyName)
    
    $InsertQuery = "INSERT INTO PolicyList (PolicyFileName, FriendlyPolicyName) VALUES ('$PolicyFileName', '$FriendlyPolicyName'); SELECT SCOPE_IDENTITY();"

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $Command = New-Object System.Data.SqlClient.SqlCommand($InsertQuery, $Connection)

    try {
        $Connection.Open()

        # ExecuteScalar grabs the result of 'SELECT SCOPE_IDENTITY()'
        $NewID = $Command.ExecuteScalar()

        Write-Host "Success! New Record ID: $NewID"
        return $NewID
    }
    catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
    finally {
        $Connection.Close()
    }
    
}
# **************************** END Add-DBNewPolicyRecord FUNCTION **********************

















# **************************** BEGIN Add-DBLastCheckinRecord FUNCTION **********************
# This function will update a record/entry in the 'WorkstationList' table for the corresponding workstation that this is being ran from.
#   It updates the 'LastCheckIn' field to the current date/time
# It accepts 1 parameter - the ID of the workstation (from the WorkstationList table)
# It will get called near the end of the script
function Add-DBLastCheckinRecord {
    param($IDOfWorkstation) # This is the 1 parameter that this function accepts - the ID of the Workstation
    
    $currentDateTimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $UpdateQuery = "UPDATE WorkstationList SET LastCheckIn = '$currentDateTimeStamp' WHERE ID = $IDOfWorkstation"

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $Command = New-Object System.Data.SqlClient.SqlCommand($UpdateQuery, $Connection)

    try {
        $Connection.Open()
        #$RowsAffected = $Command.ExecuteNonQuery()
        #$Command.ExecuteNonQuery() # This outputs a value (the number of affected rows I think)
        $null = $Command.ExecuteNonQuery()
        #Write-Host "Success! Date/Timestamp updated for this workstation. ($RowsAffected) row updated."
        Write-Host "Success! Date/Timestamp updated for this workstation."
    }
    catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
    finally {
        $Connection.Close()
    }
    
}
# **************************** END Add-DBLastCheckinRecord FUNCTION **********************





















# **************************** BEGIN Remove-DBDeployedPolicyOrphanedRecordsForThisWorkstationRecord FUNCTION **********************
# This function will delete any 'orphaned' entries in the 'DeployedPolicies' table for a specific workstation.
function Remove-DBDeployedPolicyOrphanedRecordsForThisWorkstationRecord {
    param($WorkstationID, $ListOfActualDeployedPolicyIDs) # These are the 2 parameters that this function accepts - the ID of the workstation, and a list of actual deployed PolicyIDs

    $DeleteQuery = "DELETE FROM DeployedPolicies WHERE WorkstationID = $WorkstationID AND PolicyID NOT IN ($ListOfActualDeployedPolicyIDs)"
    #Write-Host $DeleteQuery

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $Command = New-Object System.Data.SqlClient.SqlCommand($DeleteQuery, $Connection)

    try {
        $Connection.Open()
        
        # ExecuteNonQuery returns the count of affected rows
        $RowsAffected = $Command.ExecuteNonQuery()
        
        if ($RowsAffected -gt 0) {
            Write-Host "Success! Deleted $RowsAffected Orphan(ed) Deployed Policy/Policies." -ForegroundColor Green
        } else {
            Write-Host "No orphaned policies found/deleted." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "SQL Error: $($_.Exception.Message)"
    }
    finally {
        $Connection.Close()
    }
    
}
# **************************** END Remove-DBDeployedPolicyOrphanedRecordsForThisWorkstationRecord FUNCTION **********************

















# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # Begin main logic # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #









# Query that we will use to retrive the 'ID' of this workstation
$QueryWorkstationID = @"
SELECT ID
FROM WorkstationList
WHERE WorkstationName = '$ComputerName'
"@




# Initialize an empty list to use for our database results
$PolicyFileNamesToBeAddedList = New-Object System.Collections.Generic.List[PSObject]
$PolicyFileNamesToBeRemovedList = New-Object System.Collections.Generic.List[PSObject]

try {
    $Connection.Open()


    # --- FIRST QUERY --- TO RETRIEVE THE ID OF THE RECORD FOR THIS WORKSTATION
    $Command = New-Object System.Data.SqlClient.SqlCommand($QueryWorkstationID, $Connection)
    $Reader = $Command.ExecuteReader()
    if ($Reader.Read()) {
        Write-Host "Workstation ID of $ComputerName : $($Reader[0])"
        $MyWorkstationID = $($Reader[0])
    } else {
        Write-Host "No entry in database found for this workstation! Tschuss!"
        $Reader.Close() # Close connection
        # WRITE TO A LOG FILE HERE?
        exit # Exit script - there's nothing we can do
    }
    $Reader.Close() # MUST close the reader before running another one on the same connection








# This query will check for any policies to be deployed to this workstation
    $QueryPoliciesToBeDeployed = @"
SELECT p.ID, p.PolicyID, s.PolicyID AS GUID, s.PolicyFileName, s.FriendlyPolicyName
FROM PoliciesToBeDeployed p
INNER JOIN PolicyList s ON p.PolicyID = s.id
WHERE p.WorkstationID = $MyWorkstationID
"@


    # -- RUN SECOND QUERY --- FOR THE ACTUAL DATA OF POLICIES TO DEPLOY
    $Command = New-Object System.Data.SqlClient.SqlCommand($QueryPoliciesToBeDeployed, $Connection)
    $Reader = $Command.ExecuteReader()

    # Iterate through the result set row by row
    while ($Reader.Read()) {
        # Accessing by column index (0, 1, 2...) is fastest
        $ObjectEntryInList = [PSCustomObject]@{
        IDToBeDeployedRecord = $Reader[0]    
        PolicyIDKeyVal = $Reader[1]
        PolicyGUID = $Reader[2]
        PolicyFileName = $Reader[3]
        PolicyFriendlyName = $Reader[4]
        #$MyWorkstationID = $Reader[5]
        }

        # Add each Policy ID to our list as we loop, the NEW OBJECT WAY:
        $null = $PolicyFileNamesToBeAddedList.Add($ObjectEntryInList)

        Write-Host "  > Policy ID Key Value: $($ObjectEntryInList.PolicyIDKeyVal)"
        Write-Host "  > Policy ID PolicyGUID: $($ObjectEntryInList.PolicyGUID)"

        $PoliciesToBePulledDeployed = $true # This flag will only get set to True if there were any results returned because this whole block won't execute unless something is returned
        $LocalPolicyRefreshTrigger = $true # This flag will only get set to True if there were any results returned because this whole block won't execute unless something is returned
    }
    $Reader.Close() # MUST close the reader before running another one on the same connection


#exit






# This query will check for any policies to be removed from this workstation
    $QueryPoliciesToBeRemoved = @"
SELECT p.ID, p.PolicyID, s.PolicyID AS GUID, s.PolicyFileName, s.FriendlyPolicyName
FROM PoliciesToBeRemoved p
INNER JOIN PolicyList s ON p.PolicyID = s.id
WHERE p.WorkstationID = $MyWorkstationID
"@


    # -- RUN THIRD QUERY --- FOR THE POLICIES TO REMOVED
    $Command = New-Object System.Data.SqlClient.SqlCommand($QueryPoliciesToBeRemoved, $Connection)
    $Reader = $Command.ExecuteReader()

    # Iterate through the result set row by row
    while ($Reader.Read()) {
        # Accessing by column index (0, 1, 2...) is fastest
        $RemovePoliciesObjectEntryInList = [PSCustomObject]@{
        RPIDToBeRemovedRecord = $Reader[0]    
        RPPolicyIDKeyVal = $Reader[1]
        RPPolicyGUID = $Reader[2]
        RPPolicyFileName = $Reader[3]
        RPPolicyFriendlyName = $Reader[4]
        #$MyWorkstationID = $Reader[5]
        }

        # Add each Policy ID to our list as we loop, the NEW OBJECT WAY:
        $null = $PolicyFileNamesToBeRemovedList.Add($RemovePoliciesObjectEntryInList)

        Write-Host "  > Policy TO BE REMOVED ID Key Value: $($RemovePoliciesObjectEntryInList.RPPolicyIDKeyVal)"
        Write-Host "  > Policy TO BE REMOVED ID PolicyGUID: $($RemovePoliciesObjectEntryInList.RPPolicyGUID)"

        $PoliciesToBeRemoved = $true # This flag will only get set to True if there were any results returned because this whole block won't execute unless something is returned
        $LocalPolicyRefreshTrigger = $true # This flag will only get set to True if there were any results returned because this whole block won't execute unless something is returned
    }


}
catch {
    Write-Error $_.Exception.Message
}

finally {
    # It is crucial to close the Reader and Connection
    if ($Reader) { $Reader.Close() }
    $Connection.Close()
}


Write-Host ""
Write-Host "Total policies to be ADDED: $($PolicyFileNamesToBeAddedList.Count)"

Write-Host ""
Write-Host "Total policies to be REMOVED: $($PolicyFileNamesToBeRemovedList.Count)"
Write-Host ""


















################################################################################################
##################################### DEPLOY POLICIES SECTION ##################################
################################################################################################

# This section does the actual deployment of each policy to be deployed
# (Just the copying of the files and the database update to reflect this... the 'Citool --refresh' command is done near/at the end of this script)

# If there are one or more policies to be deployed
if ($PoliciesToBePulledDeployed) {

    # 1st make sure that the share where the policies are stored is accessible. If it's not, error out
    if (!(Test-Path $PolicySourcePath)) {
        Write-Host "Can't access destination path!"
        throw "Server destination path $($PolicySourcePath) is unreachable." 
    }

    # Logic here to pull policy files to local workstation
    foreach ($Poolicy in $PolicyFileNamesToBeAddedList) {
        Write-Host "New policy to be deployed: $($Poolicy.PolicyGUID) ( $($Poolicy.PolicyFriendlyName) )"
        
        # Combine the source directory and filename safely
        $FullSourcePath = Join-Path -Path $PolicySourcePath -ChildPath $($Poolicy.PolicyFileName)


        try {
            # Copy the policy file to be deployed to the appropriate local policies folder
            Copy-Item -Path $FullSourcePath -Destination $LocalPolicyPath -Force -ErrorAction Stop
            
            # This block only runs if the copy succeeded
            Write-Host "File copy/deployment success! Continuing..."
            Write-Host "ID of record to be deleted: $($Poolicy.IDToBeDeployedRecord)"
            
            # If we got here, then the copy was a success - remove the corresponding record from the PoliciesToBeDeployed table
            Remove-DBPolicyToBeDeployedOrRemovedIsCompletedRecord $($Poolicy.IDToBeDeployedRecord) "PoliciesToBeDeployed"
        }
        catch {
            Write-Warning "The copy failed. Error: $($_.Exception.Message)"
        }
        
    }

}






















################################# NEW in v1.1!!! ##############################################

# This query will check for all policies that SHOULD be deployed at this workstation
    $QueryDeployedPoliciesForThisWorkstation = @"
SELECT PolicyID FROM DeployedPolicies WHERE WorkstationID = $MyWorkstationID
"@


$PolicyLookupHashTable = @{} # Create Hash Table

try {
        $Connection.Open()

        $Command = New-Object System.Data.SqlClient.SqlCommand($QueryDeployedPoliciesForThisWorkstation, $Connection)
        $Reader = $Command.ExecuteReader()
        
        # Iterate through the result set row by row
        while ($Reader.Read()) {
            $PolicyLookupHashTable[$Reader[0]] = $true # Load the PolicyID (the 1st/Index 0 field of the SELECT statement) of current record into our Hash Table
            #$PolicyLookupHashTable[[int]$Reader[0]] = $true # Load the PolicyID of current record into our Hash Table
        }
        $Reader.Close() # MUST close the reader before running another one on the same connection

    }
    catch {
        Write-Error $_.Exception.Message
    }

    finally {
        # It is crucial to close the Reader and Connection
        if ($Reader) { $Reader.Close() }
        $Connection.Close()
    }


################################# NEW in v1.1!!! ##############################################



































################################################################################################
##################################### REMOVE POLICIES SECTION ##################################
################################################################################################

# If there are one or more policies to be deployed
if ($PoliciesToBeRemoved) {


    # Logic here to delete policy files on local workstation
    foreach ($Pooplicy in $PolicyFileNamesToBeRemovedList) {
        Write-Host "Existing policy [file] to be removed: $($Pooplicy.RPPolicyGUID) ( $($Pooplicy.RPPolicyFriendlyName) )"
        
        # Combine the source directory and filename safely
        $FullSourcePath = Join-Path -Path $LocalPolicyPath -ChildPath $($Pooplicy.RPPolicyFileName)
        Write-Host "Full path: $FullSourcePath"

        if (Test-Path -Path $FullSourcePath) {
            try {
                # -ErrorAction Stop is required to force the error into the Catch block
                Remove-Item -Path $FullSourcePath -Force -ErrorAction Stop
                Write-Host "Success: File deleted." -ForegroundColor Green

                # If we got here, then the file removal was a success - remove the corresponding record from the PoliciesToBeRemoved table
                Remove-DBPolicyToBeDeployedOrRemovedIsCompletedRecord $($Pooplicy.RPIDToBeRemovedRecord) "PoliciesToBeRemoved"
            }
            catch {
                Write-Error "Failed to delete file. Reason: $($_.Exception.Message)"
            }
        }
        else {
            Write-Warning "Can not delete file because file does not exist at: $FullSourcePath"
            Write-Warning "Because the file does not exist, we'll just remove the record from the 'PoliciesToBeRemoved' table"

            # The file was not found, so it's kind of like the file was removed, so remove the corresponding record from the PoliciesToBeRemoved table
            Remove-DBPolicyToBeDeployedOrRemovedIsCompletedRecord $($Pooplicy.RPIDToBeRemovedRecord) "PoliciesToBeRemoved"

            # Update a log here saying that the file was already gone (so nothing to remove)
        }

        
    }

}

















#$LocalPolicyPath  = "C:\Temp\Temp2"

####################################### Updated in v1.1!!! ##############################################

#################################################################################################################
##################################### UPDATE DEPLOYED POLICIES RECORDS SECTION ##################################
#################################################################################################################

# This section will cycle through all the policy files on the local drive, and:
# Using a database query, run a check to see if that policy file exists in the 'PolicyList' table.
#    If it does not: 
#        Add an entry in the 'PolicyList' table for it (and grab the id of the new record), then:
#            Using that new ID and the ID of this workstation, enter a new record into the 'DeployedPolicies' table
#            Using the new ID from the new record in the 'PolicyList' table, add it to the array, $FoundPolicyIDsArray
#    If it does (therefore has a record ID):
#        Check our Hash Table, $PolicyLookupHashTable to see if the file we're looking at (via the record ID of the policy) is in the 'DeployedPolicies' table.
#            If it is NOT:
#                  Using the matched Policy record ID, and current Workstation ID, add an entry into the 'DeployedPolicies' table
#        Add the ID of the matching record in the 'PolicyList' table to the array, $FoundPolicyIDsArray
# 
# An important thing to remember here, is that we are loading the array, $FoundPolicyISsArray with ALL policies that are deployed on this workstation
#   Because later we're going to use this array to remove 'orphaned' records in 'DeployedPolicies' - anything that was not found as actually deployed, will be removed
# 

$FoundPolicyIDsArray = @()

# Get-ChildItem retrieves the items
# -File ensures you only get files, not folders
$FilesInLocalSecurityPolicyFolder = Get-ChildItem -Path $LocalPolicyPath -File

foreach ($file in $FilesInLocalSecurityPolicyFolder) { # Here is the loop where we cycle through each file
    # $file.Name gives you 'example.xml'
    # $file.FullName gives you 'C:\Windows\...\example.xml'
    Write-Host "Processing: $($file.Name)"

# This query will retrieve the id of the policy given the policy file name
        $QueryPolicyList = @"
SELECT p.ID
FROM PolicyList p
WHERE p.PolicyFileName = '$($file.Name)'
"@
    

    try {
        $Connection.Open()
        $Command = New-Object System.Data.SqlClient.SqlCommand($QueryPolicyList, $Connection)
        $Reader = $Command.ExecuteReader()

        # If NO entry is found in the PolicyList table for the current policy file we're looking at exists, we'll need to add one
        if (-not $Reader.Read()) {
            Write-Host "Doh! No entry in database found for this policy! One will have to be entered"
            #$Reader.Close() # Close connection
            $NewSupplmentalPolicyID = Add-DBNewPolicyRecord $($file.Name) "Unknown policy entered by $ComputerName" ### Enter the policy file into our database (PolicyList) table since it's not in the db already, AND grab the ID for the next line ###
            Add-DBDeployedPolicyRecord $MyWorkstationID $NewSupplmentalPolicyID ### Using the ID for the new Policy we just entered, enter new record into the DeployedPolicies table with new Policy ID and this workstation ###
            $FoundPolicyIDsArray += $NewSupplmentalPolicyID # Add the ID of the new policy in the 'PolicyList' table that we just created 2 lines above to our array, $FoundPolicyIDsArray
        } else {  # An entry WAS found in the PolicyList table, so...
           
            # If the current policy file we're looking at is NOT in the list of known DEPLOYED POLICIES for this workstation,
            if (-not $PolicyLookupHashTable.ContainsKey($($Reader[0]))) {
                Write-Host "[[[[[[[[[[[[[[[[[ Current deployed policy file not found in hash table, adding entry into DeployedPolicies table ]]]]]]]]]]]]]]]]]]]"
                # Add an entry for this policy and workstation to the 'DeployedPolicies' table!
                Add-DBDeployedPolicyRecord $MyWorkstationID $($Reader[0])
            } # Else, no action required

            # Add the ID of the matched policy record in the 'PolicyList' table to our array, $FoundPolicyIDsArray
            $FoundPolicyIDsArray += $($Reader[0])

        }

        $Reader.Close() # MUST close the reader before running another one on the same connection

    }
    catch {
        Write-Error $_.Exception.Message
    }

    finally {
        # It is crucial to close the Reader and Connection
        if ($Reader) { $Reader.Close() }
        $Connection.Close()
    }


}




Write-Host ""

#Write-Host "Found policies array: $FoundPolicyIDsArray"
$JoinedIDs = $FoundPolicyIDsArray -join ','

#Write-Host "Joined Ids: $JoinedIDs"

# If there are 1 or more values in our array, then call our function that will delete all DeployedPolicies for this workstation
#    that is NOT found in the array
# The only way that this would happen is if there were ZERO policy files in the appropriate folder. This will probably NEVER be the case,
#    but I found that the script chokes/errors out when this is the case. (I set the policies folder to a temporary/fake folder that
#         had no policies in it, and the script errored out and quit)
#    But to be safe, I added the following 'if' statement anyway
#
If ($FoundPolicyIDsArray) {
    Write-Host "Found policies array Has items"
    Write-Host ""
    Remove-DBDeployedPolicyOrphanedRecordsForThisWorkstationRecord $MyWorkstationID $JoinedIDs
 } else {
    Write-Host "Found policies array is Empty"
}
Write-Host ""




















###########################################################################################################################
##################################### UPDATE WORKSTATION LAST CHECK-IN TIMESTAMP SECTION ##################################
###########################################################################################################################

# Yes, really, this is it since it's in a nice tidy function
#
# Here we just update the 'LastCheckIn' field of the WorkstationList table to the current date/time for this corresponding workstation
Add-DBLastCheckinRecord $MyWorkstationID
Write-Host ""


















####################################################################################################################
######################################### REFRESH LOCAL POLICIES IF NEEDED #########################################
####################################################################################################################

if ($LocalPolicyRefreshTrigger) {
    Write-Host "Changes made. Need to refresh CI Policy. Pausing 4 seconds, then executing CITool --refresh, please wait"
    Start-Sleep -Seconds 4
    CiTool --refresh -json # Adding '-json' formats the output, and suppresses input so it won't prompt you to hit 'Enter' when it's done!
} else {
    Write-Host "No changes made. No need to refresh CI Policy."
}
