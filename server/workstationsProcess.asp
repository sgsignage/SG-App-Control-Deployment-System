<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, mySQL, rs, i

Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString



' UPDATE existing workstations
For i = 1 to Request.Form("TotalNumOfWorkstations")

    If Request.Form("Remove-" & i) = "on" Then 'If the remove checkbox is checked, this takes priority
        mySQL = "DELETE FROM WorkstationList WHERE ID = " & Request.Form("ID-" & i)
        'Response.Write mySQL & "<br>" & vbCrLf
        Set rs = cn.execute(mySQL)
    Else ' The remove checkbox is not checked, so we can update as long as BOTH WorkstationName and WorkstationPrimaryUser has data in it
        If Request.Form("WorkstationName-" & i) <> "" And Request.Form("WorkstationPrimaryUser-" & i) <> "" Then
            mySQL = "UPDATE WorkstationList SET WorkstationName = '" & Request.Form("WorkstationName-" & i) & "', WorkstationPrimaryUser = '" & Request.Form("WorkstationPrimaryUser-" & i) & "' WHERE ID = " & Request.Form("ID-" & i)
            'Response.Write mySQL & "<br>" & vbCRLf
            Set rs = cn.execute(mySQL)
        End If
    End If

Next




' ADD new workstations
For i = 1 to maxNumOfWorkstationsToAddAtATime

    ' As long as a WorkstationName AND WorkstationPrimaryUser are entered, we can add it to the database
    If Request.Form("AddWorkstationName-" & i) <> "" And Request.Form("AddWorkstationPrimaryUser-" & i) <> "" Then
        mySQL = "INSERT INTO WorkstationList (WorkstationName, WorkstationPrimaryUser) VALUES ('" & Request.Form("AddWorkstationName-" & i) & "', '" & Request.Form("AddWorkstationPrimaryUser-" & i) & "')"
        'Response.Write mySQL & "<br>" & vbCRLf
        Set rs = cn.execute(mySQL)
    End If

Next







cn.Close
Set cn = Nothing

' Redirect back to the workstations page
Response.Redirect "workstations.asp"

%>