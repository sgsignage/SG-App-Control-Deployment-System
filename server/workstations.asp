<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->

<%
Dim cn, mySQL, rs, i, myCounter, LastCheckIn, minutesDiff

Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString
mySQL = "SELECT id, WorkstationName, WorkstationPrimaryUser, LastCheckIn FROM WorkstationList ORDER BY WorkstationName"
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
        <h1>Workstations</h1>
        <p>Update / Add / Delete Workstations here</p>
    </header>

    <form method="POST" action="workstationsProcess.asp">
    <table class="sticky-column-table" align="center">
        <thead>
            <tr>
                <th>Workstation ID</th>
                <th>Workstation Name</th>
                <th>Workstation Primary User</th>
                <th>Last Check-in</th>
                <th>X</th>
            </tr>
        </thead>
        <tbody>
    <%
    i = 1
    Do Until rs.EOF
        If rs("LastCheckIn") <> "" And IsNull(rs("LastCheckIn")) = False Then
            minutesDiff = DateDiff("n", rs("LastCheckIn"), now())
            If minutesDiff > 30 And minutesDiff < 1441 Then
                LastCheckIn = "<span style=""color: orange;"">" & rs("LastCheckIn") & "</span>"
            ElseIf minutesDiff > 1441 Then
                LastCheckIn = "<span style=""color: red;"">" & rs("LastCheckIn") & "</span>"
            Else
                LastCheckIn = rs("LastCheckIn")
            End If
            LastCheckIn = LastCheckIn & " (" & minutesDiff & " minutes ago)"
        Else
            LastCheckIn = "Never"
        End If
        %>
        <tr>
            <th scope="row"><%= rs("ID") %><input type="hidden" name="id-<%= i %>" value="<%= rs("ID") %>"></th>
            <td><input type="text" name="WorkstationName-<%= i %>" value="<%= rs("WorkstationName") %>"></td>
            <td><input type="text" name="WorkstationPrimaryUser-<%= i %>" value="<%= rs("WorkstationPrimaryUser") %>"></td>
            <td><%= LastCheckIn %></td>
            <td><input type="checkbox" name="Remove-<%= i %>"></td>
        </tr>
        <%
        rs.MoveNext
        i = i + 1
        myCounter = myCounter + 1
    Loop

    For i = 1 to maxNumOfWorkstationsToAddAtATime
        %>

        <tr>
            <th scope="row">&nbsp;</th>
            <td><input type="text" name="AddWorkstationName-<%= i %>"></td>
            <td><input type="text" name="AddWorkstationPrimaryUser-<%= i %>"></td>
            <td>&nbsp;</td>
            <td>&nbsp;</td>
        </tr>

        <%
    Next
    %>
    <input type="hidden" name="TotalNumOfWorkstations" value="<%= myCounter - 1 %>">
</tbody>
    </table>
    <div align="center">
        <input type="submit" value="Update/Add/Delete Workstations" class="btnOther">
    </div>
</form>



</body>

<%
rs.Close
Set rs = nothing
cn.Close
Set cn = nothing
%>