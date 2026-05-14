<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, rsWS, workstations, mySQL, rs, dictStatus, i, policyName
Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString 

' 1. Load Workstations into array
Set rsWS = cn.Execute("SELECT id, WorkstationName FROM WorkstationList ORDER BY WorkstationName")
If Not rsWS.EOF Then workstations = rsWS.GetRows()
rsWS.Close

' 2. Load Deployed and Pending Deployment statuses into a Dictionary
Set dictStatus = Server.CreateObject("Scripting.Dictionary")

' Union DeployedPolicies with PoliciesToBeDeployed to identify pending re-deployments
' We pull the ID from the pending table so we can cancel it
mySQL = "SELECT WorkstationID, PolicyID, 'Deployed' as Status, 0 as RecordID FROM DeployedPolicies " & _
        "UNION ALL " & _
        "SELECT WorkstationID, PolicyID, 'Pending' as Status, ID as RecordID FROM PoliciesToBeDeployed"
Set rs = cn.Execute(mySQL)

Do Until rs.EOF
    Dim key : key = CStr(rs("WorkstationID") & "-" & rs("PolicyID"))
    ' Store Status and RecordID together
    Dim val : val = CStr(rs("Status") & "") & "|" & CStr(rs("RecordID") & "") 
    
    If Not dictStatus.Exists(key) Then
        dictStatus.Add key, val
    Else
        ' Prioritize 'Pending' status so users know a re-deployment is already queued
        ' Note: We check the first part of the piped value
        If Left(val, 7) = "Pending" Then
            dictStatus(key) = val
        End If
    End If
    rs.MoveNext
Loop
rs.Close

' 3. Get Policies for the rows
mySQL = "SELECT id, FriendlyPolicyName, IsLockedPolicy, IsBasePolicy FROM PolicyList ORDER BY FriendlyPolicyName"
Set rs = cn.Execute(mySQL)




' --- Pagination Configuration ---
Dim currentPage, startIdx, endIdx, nextXAmount, totalWorkstations

currentPage = Request.QueryString("page")
If currentPage = "" Or Not IsNumeric(currentPage) Then currentPage = 1
currentPage = CInt(currentPage)

If IsArray(workstations) Then
    totalWorkstations = UBound(workstations, 2) + 1
    ' Calculate the slice of the array to show
    startIdx = (currentPage - 1) * maxNumOfWorkstationsPerPage
    endIdx = startIdx + (maxNumOfWorkstationsPerPage - 1)
    
    ' Ensure we don't go out of bounds on the last page
    If endIdx > UBound(workstations, 2) Then endIdx = UBound(workstations, 2)
End If
%>

<!DOCTYPE html>
<html>
<head>
    <%= titleTag %>
    <link href="sgwdac-redeploy.css" rel="stylesheet" type="text/css">
    <link href="sgwdac-navbar.css" rel="stylesheet" type="text/css">
    <link href="sgwdac-common.css" rel="stylesheet" type="text/css">
</head>
<body>

    <%= navBarHTML %>

    <header style="padding: 5px 0; text-align: center;">
        <h1>App Control Policies and Workstations - <span style="color: #1976d2;">Re-Deploy</span></h1>
        <p>Use the checkboxes to <span style="color: #1976d2;">RE-DEPLOY</span> a policy that is already in place (e.g., for version updates).
         Click the red 'slash' (<span style="font-weight:bold;color:red;"><%= cancelPendingIcon %></span>) to cancel a pending re-deployment.</p>
    </header>

    <div class="pagination-controls" style="text-align:center; margin-bottom: 10px; margin-top: -20px;">
        <p>
            <% If startIdx > 0 Then %>
                <a href="<%= Request.ServerVariables("SCRIPT_NAME") %>?page=<%= currentPage - 1 %>">&laquo; Previous <%= maxNumOfWorkstationsPerPage %></a>
            <% End If %>
            
            <span style="margin: 0 20px;">
                Showing Workstations <%= startIdx + 1 %> - <%= endIdx + 1 %> of <%= totalWorkstations %>
            </span>

            <%
            If endIdx < UBound(workstations, 2) Then
                If totalWorkstations - (endIdx + 1) > maxNumOfWorkstationsPerPage Then
                    nextXAmount = maxNumOfWorkstationsPerPage
                    Response.Write "<a href=" & Request.ServerVariables("SCRIPT_NAME") & "?page=" & currentPage + 1 & ">Next " & nextXAmount & " &raquo;</a>"
                Else
                    nextXAmount = totalWorkstations - (endIdx + 1)
                    Response.Write "<a href=" & Request.ServerVariables("SCRIPT_NAME") & "?page=" & currentPage + 1 & ">Next " & nextXAmount & " &raquo;</a>"
                End If
            End If
            %>
        </p>
    </div>

    <form method="POST" action="redeployPoliciesProcess.asp">
    <table class="sticky-column-table">
        <thead>
            <tr>
                <th>Application Name</th>
                <% 
                If IsArray(workstations) Then
                    For i = startIdx To endIdx 'Use sliced index
                        Dim wsID_col : wsID_col = workstations(0, i)
                        %>
                        <th>
                            <%= workstations(1, i) %><br />
                            <input type="checkbox" onclick="toggleColumn('<%= wsID_col %>')">
                        </th>
                        <%
                    Next
                End If 
                %>
            </tr>
        </thead>
        <tbody>
    <%
    Do Until rs.EOF
        Dim pID : pID = rs("id")
        If rs("IsBasePolicy") Then
            policyName = "*** " & rs("FriendlyPolicyName") & " ***"
        Else
            policyName = rs("FriendlyPolicyName")
        End If
        %>
        <tr>
            <th scope="row">
                <%= policyName %> - 
                <input type="checkbox" onclick="toggleRow(this)">
            </th>
            <%
            If IsArray(workstations) Then
                For i = startIdx To endIdx 'Use sliced index
                    Dim wID : wID = CStr(workstations(0, i))
                    Dim lookupKey : lookupKey = wID & "-" & CStr(pID)
                    
                    Response.Write "<td style='text-align:center;'>"
                    
                    If dictStatus.Exists(lookupKey) Then
                    ' Split the status and RecordID
                    Dim statusParts : statusParts = Split(dictStatus.Item(lookupKey), "|")
                    Dim currentStatus : currentStatus = statusParts(0)
                    Dim recordID : recordID = statusParts(1)
                    
                        If currentStatus = "Pending" Then
                            ' Display Pending label and the red cancel icon
                            Response.Write "<span style='color:orange; font-weight:bold; font-size:0.8em;'>Pending</span><br>"
                            Response.Write "<span style='font-weight:bold; font-size:1.0em;'>"
                            Response.Write "<a href='cancelPending.asp?id=" & recordID & "&pendingAction=deploy' "
                            Response.Write "style='color:red; text-decoration:none;' title='Cancel Re-Deployment'>" & cancelPendingIcon & "</a>"
                            Response.Write "</span>"
                        Else
                            If rs("IsLockedPolicy") Then 
                                Response.Write "&#128274;" ' Locked icon
                            Else
                                ' Deployed; allow checking for re-deployment
                                Response.Write "<input type='checkbox' name='redeploy' class='col-" & wID & "' value='" & wID & "|" & pID & "'>"
                            End If
                        End If
                    Else
                        ' Not currently deployed, nothing to re-deploy
                        Response.Write "<span style='color:#ccc; font-size:0.8em;'>N/A</span>"
                    End If
                    
                    Response.Write "</td>"
                Next
            End If
            %>
        </tr>
        <%
        rs.MoveNext
    Loop
    %>
</tbody>
    </table>
    <div class="pagination-controls" style="text-align:center; margin-bottom: 10px; margin-top: 20px;">
        <p>
            <% If startIdx > 0 Then %>
                <a href="<%= Request.ServerVariables("SCRIPT_NAME") %>?page=<%= currentPage - 1 %>">&laquo; Previous <%= maxNumOfWorkstationsPerPage %></a>
            <% End If %>
            
            <span style="margin: 0 20px;">
                Showing Workstations <%= startIdx + 1 %> - <%= endIdx + 1 %> of <%= totalWorkstations %>
            </span>

            

            <%
            If endIdx < UBound(workstations, 2) Then
                If totalWorkstations - (endIdx + 1) > maxNumOfWorkstationsPerPage Then
                    nextXAmount = maxNumOfWorkstationsPerPage
                    Response.Write "<a href=" & Request.ServerVariables("SCRIPT_NAME") & "?page=" & currentPage + 1 & ">Next " & nextXAmount & " &raquo;</a>"
                Else
                    nextXAmount = totalWorkstations - (endIdx + 1)
                    Response.Write "<a href=" & Request.ServerVariables("SCRIPT_NAME") & "?page=" & currentPage + 1 & ">Next " & nextXAmount & " &raquo;</a>"
                End If
            End If
            %>
        </p>
    </div>
    <div align="center">
        <input type="submit" value="Queue for Re-Deployment" class="btnRedeploy">
    </div>
</form>

<script>
function toggleRow(source) {
    var checkboxes = source.closest('tr').querySelectorAll('input[type="checkbox"][name="redeploy"]');
    for (var i = 0; i < checkboxes.length; i++) { checkboxes[i].checked = source.checked; }
}

function toggleColumn(wsID) {
    var checkboxes = document.getElementsByClassName('col-' + wsID);
    var targetState = event.target.checked;
    for (var i = 0; i < checkboxes.length; i++) { checkboxes[i].checked = targetState; }
}
</script>

</body>
</html>
<%
Set dictStatus = Nothing
rs.Close
cn.Close
%>