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

' 2. Load ALL deployment statuses into a Dictionary at once
Set dictStatus = Server.CreateObject("Scripting.Dictionary")

' We union both tables to see what is already there or pending and we select the ID from the pending table so we can cancel it later
mySQL = "SELECT WorkstationID, PolicyID, 'Deployed' as Status, 0 as RecordID FROM DeployedPolicies " & _
        "UNION ALL " & _
        "SELECT WorkstationID, PolicyID, 'Pending' as Status, id as RecordID FROM PoliciesToBeDeployed"
Set rs = cn.Execute(mySQL)

Do Until rs.EOF
    Dim key : key = CStr(rs("WorkstationID") & "-" & rs("PolicyID"))
    ' Store both the Status and the RecordID separated by a pipe
    Dim val : val = CStr(rs("Status") & "") & "|" & CStr(rs("RecordID") & "") 
    
    If Not dictStatus.Exists(key) Then
        dictStatus.Add key, val
    Else
        If Left(val, 8) = "Deployed" Then
            dictStatus(key) = val
        End If
    End If
    rs.MoveNext
Loop
rs.Close

' 3. Get Policies for the rows
mySQL = "SELECT id, FriendlyPolicyName, IsBasePolicy FROM PolicyList ORDER BY FriendlyPolicyName"
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

<%= titleTag %>

<link href="sgwdac-deploy.css" rel="stylesheet" type="text/css">
<link href="sgwdac-navbar.css" rel="stylesheet" type="text/css">
<link href="sgwdac-common.css" rel="stylesheet" type="text/css">

<body>

    <%= navBarHTML %>

    <header style="padding: 5px 0; text-align: center;">
        <h1>App Control Policies and Workstations - <span style="color: #3EC13E;">Deploy</span></h1>
        <p>All policies/workstations, and which policies are applied to each workstation.<br> 
            Use the checkboxes for each policy you want to deploy to the corresponding workstation.
            Click the red 'slash' (<span style="font-weight:bold;color:red;"><%= cancelPendingIcon %></span>) to cancel a pending deployment.
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

    <form method="POST" action="deployPoliciesProcess.asp">
    <table class="sticky-column-table">
        <thead>
            <tr>
                <th>Application Name</th>
                <% 
                If IsArray(workstations) Then
                    For i = startIdx To endIdx ' Use sliced index
                        Dim workstationName : workstationName = workstations(1, i)
                        Dim wsID_col : wsID_col = workstations(0, i)
                        %>
                        <th>
                            <%= workstationName %><br />
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
                        Dim statusParts : statusParts = Split(dictStatus.Item(lookupKey), "|")
                        Dim currentStatus : currentStatus = statusParts(0)
                        Dim recordID : recordID = statusParts(1)

                        If currentStatus = "Deployed" Then
                            Response.Write "<span style='color:green; font-weight:bold;'>&check;</span>"
                        Else
                            ' It is Pending - Show the label and the Cancel link
                            Response.Write "<span style='color:orange; font-weight:bold; font-size:0.8em;'>Pending</span><br>"
                            Response.Write "<span style='font-weight:bold; font-size:1.0em;'>"
                            Response.Write "<a href='cancelPending.asp?id=" & recordID & "&pendingAction=deploy' "
                            Response.Write "style='color:red; text-decoration:none;' title='Cancel Deployment'>" & cancelPendingIcon & "</a>"
                            Response.Write "</span>"
                    End If
                Else
                    ' Show checkbox for new deployment
                    Response.Write "<input type='checkbox' name='deploy' class='col-" & wID & "' value='" & wID & "|" & pID & "'>" 
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
        <input type="submit" value="Queue for Deployment" class="btnDeploy">
    </div>
</form>

<script>
// Selects all checkboxes in a specific row
function toggleRow(source) {
    // Find the parent <tr> and then find all checkboxes within it
    var checkboxes = source.closest('tr').querySelectorAll('input[type="checkbox"][name="deploy"]');
    for (var i = 0; i < checkboxes.length; i++) {
        checkboxes[i].checked = source.checked;
    }
}

// Selects all checkboxes in a specific column based on the workstation ID class
function toggleColumn(wsID) {
    var checkboxes = document.getElementsByClassName('col-' + wsID);
    // Use the first checkbox to determine if we are checking or unchecking all
    var targetState = event.target.checked;
    for (var i = 0; i < checkboxes.length; i++) {
        checkboxes[i].checked = targetState;
    }
}
</script>

</body>

<%
Set dictStatus = Nothing
rs.Close
cn.Close
%>
