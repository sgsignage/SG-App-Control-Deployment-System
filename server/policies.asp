<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->

<%
Dim cn, mySQL, rs, i, myCounter

Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString
mySQL = "SELECT id, FriendlyPolicyName, PolicyFileName, IsBasePolicy, IsLockedPolicy FROM PolicyList ORDER BY FriendlyPolicyName"
Set rs = cn.execute(mySQL)

myCounter = 1
%>


<!DOCTYPE html>

<%= titleTag %>

<link href="sgwdac-other.css" rel="stylesheet" type="text/css">
<link href="sgwdac-navbar.css" rel="stylesheet" type="text/css">
<link href="sgwdac-common.css" rel="stylesheet" type="text/css">

<body>

    <%= navBarHTML %>

    <header style="padding: 5px 0; text-align: center;">
        <h1>Policies</h1>
        <p>Update / Add / Delete Policies here</p>
    </header>

    <form method="POST" action="policiesProcess.asp">
    <table class="sticky-column-table" align="center">
        <thead>
            <tr>
                <th>Policy ID</th>
                <th>Friendly Policy Name</th>
                <th>Policy File Name</th>
                <th>Base Policy</th>
                <th>Locked</th>
                <th>X</th>
            </tr>
        </thead>
        <tbody>
    <%
    i = 1
    Do Until rs.EOF
        %>
        <tr>
            <th scope="row"><%= rs("ID") %><input type="hidden" name="id-<%= i %>" value="<%= rs("ID") %>"></th>
            <td><input type="text" name="FriendlyPolicyName-<%= i %>" value="<%= rs("FriendlyPolicyName") %>" Size="50"></td>
            <td><input type="text" name="PolicyFileName-<%= i %>" value="<%= rs("PolicyFileName") %>" size="50"></td>
            <td><input type="checkbox" name="IsBasePolicy-<%= i %>" <% If rs("IsBasePolicy") Then Response.Write "checked" %>></td>
            <td><input type="checkbox" name="IsLockedPolicy-<%= i %>" <% If rs("IsLockedPolicy") Then Response.Write "checked" %>></td>
            <td>
                <%
                If rs("IsLockedPolicy") Then
                    Response.Write lockedIcon
                Else
                    Response.Write "<input type=""checkbox"" name=""Remove-" & i & """>" & vbCrLf
                End If
                %>
                
            </td>
        </tr>
        <%
        rs.MoveNext
        i = i + 1
        myCounter = myCounter + 1
    Loop

    For i = 1 to maxNumOfPoliciesToAddAtATime
        %>

        <tr>
            <th scope="row">&nbsp;</th>
            <td><input type="text" name="AddFriendlyPolicyName-<%= i %>" size="50"></td>
            <td><input type="text" name="AddPolicyFileName-<%= i %>" size="50"></td>
            <td><input type="checkbox" name="AddIsBasePolicy-<%= i %>"></td>
            <td><input type="checkbox" name="AddIsLockedPolicy-<%= i %>"></td>
            <td>&nbsp;</td>
        </tr>

        <%
    Next
    %>
    <input type="hidden" name="TotalNumOfPolicies" value="<%= myCounter - 1 %>">
</tbody>
    </table>
    <div align="center">
        <input type="submit" value="Update/Add/Delete Policies" class="btnOther">
    </div>
</form>



</body>

<%
rs.Close
Set rs = nothing
cn.Close
Set cn = nothing
%>