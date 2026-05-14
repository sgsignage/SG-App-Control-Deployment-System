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

' 2. Load Deployed and Pending Removal statuses into a Dictionary
Set dictStatus = Server.CreateObject("Scripting.Dictionary")

' Union DeployedPolicies with PoliciesToBeRemoved to identify pending deletions
mySQL = "SELECT WorkstationID, PolicyID, 'Deployed' as Status, 0 as RecordID FROM DeployedPolicies " & _
        "UNION ALL " & _
        "SELECT WorkstationID, PolicyID, 'Removing' as Status, id as RecordID FROM PoliciesToBeRemoved"
Set rs = cn.Execute(mySQL)

Do Until rs.EOF
    Dim key : key = CStr(rs("WorkstationID") & "-" & rs("PolicyID"))
    ' Store Status and RecordID together
    Dim val : val = CStr(rs("Status") & "") & "|" & CStr(rs("RecordID") & "") 
    
    If Not dictStatus.Exists(key) Then
        dictStatus.Add key, val
    Else
        ' Prioritize the 'Removing' status if it exists
        ' Checking the status portion of the piped string
        If Left(val, 8) = "Removing" Then
            dictStatus(key) = val
        End If
    End If
    rs.MoveNext
Loop
rs.Close

' 3. Get Policies for the rows
mySQL = "SELECT id, FriendlyPolicyName, isLockedPolicy, isBasePolicy FROM PolicyList ORDER BY FriendlyPolicyName"
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
    <link href="sgwdac-removepolicies.css" rel="stylesheet" type="text/css">
    <link href="sgwdac-navbar.css" rel="stylesheet" type="text/css">
    <link href="sgwdac-common.css" rel="stylesheet" type="text/css">
</head>
<body>

    <%= navBarHTML %>

    <header style="padding: 5px 0; text-align: center;">
        <h1 class="remove-header">App Control Policies and Workstations - <span style="color: red;">REMOVE</span></h1>
        <p>Use the checkboxes for each policy you want to <span style="color: red;">REMOVE</span> from the corresponding workstation. 
            Click the red 'slash' (<span style="font-weight:bold;color:red;"><%= cancelPendingIcon %></span>) to cancel a pending removal.
        </p>
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

    <form method="POST" action="removePoliciesProcess.asp">
    <table class="sticky-column-table">
        <thead>
            <tr>
                <th>Application Name</th>
                <% 
                If IsArray(workstations) Then
                    For i = startIdx To endIdx ' Use sliced index
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
                For i = startIdx To endIdx ' Use sliced index
                    Dim wID : wID = CStr(workstations(0, i))
                    Dim lookupKey : lookupKey = wID & "-" & CStr(pID)
                    
                    Response.Write "<td style='text-align:center;'>"
                    
                    If dictStatus.Exists(lookupKey) Then
                        ' Split the piped string to get status and ID[cite: 3]
                        Dim statusParts : statusParts = Split(dictStatus.Item(lookupKey), "|")
                        Dim currentStatus : currentStatus = statusParts(0)
                        Dim recordID : recordID = statusParts(1)
                    
                        If currentStatus = "Removing" Then
                            ' Display "Pending" label and the red cancel icon[cite: 3, 5]
                            Response.Write "<span style='color:orange; font-weight:bold; font-size:0.8em;'>Pending</span><br>"
                            Response.Write "<span style='font-weight:bold; font-size:1.0em;'>"
                            ' Note the pendingAction=remove parameter for the processing script[cite: 3]
                            Response.Write "<a href='cancelPending.asp?id=" & recordID & "&pendingAction=remove' "
                            Response.Write "style='color:red; text-decoration:none;' title='Cancel Removal'>" & cancelPendingIcon & "</a>"
                            Response.Write "</span>"
                        Else
                            If rs("IsLockedPolicy") Then 
                                Response.Write lockedIcon ' Locked icon from source 5[cite: 5]
                            Else
                                ' Policy is deployed and available for removal[cite: 5]
                                Response.Write "<input type='checkbox' name='remove' class='col-" & wID & "' value='" & wID & "|" & pID & "'>" 
                            End If
                        End If
                    Else
                        ' No policy found in DeployedPolicies, nothing to remove[cite: 5]
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
        <input type="submit" value="Queue for Removal" class="btnRemoval">
    </div>
</form>

<script>
function toggleRow(source) {
    var checkboxes = source.closest('tr').querySelectorAll('input[type="checkbox"][name="remove"]');
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