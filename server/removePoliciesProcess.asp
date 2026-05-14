<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, removeItems, iItem, ids, wID, pID
Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString

' Retrieve the comma-separated list of "WorkstationID|PolicyID" from the 'remove' checkboxes
removeItems = Request.Form("remove") 

If removeItems <> "" Then
    For Each iItem In Split(removeItems, ",")
        ids = Split(Trim(iItem), "|") 
        
        If UBound(ids) = 1 Then
            wID = ids(0)
            pID = ids(1)
            
            ' Insert into the PoliciesToBeRemoved table
            cn.Execute("INSERT INTO PoliciesToBeRemoved (WorkstationID, PolicyID) VALUES (" & wID & ", " & pID & ")")
            'Response.Write "INSERT INTO PoliciesToBeRemoved (WorkstationID, PolicyID) VALUES (" & wID & ", " & pID & ") <br>" & vbCrLf
        End If
    Next
End If

cn.Close
Set cn = Nothing

' Redirect back to the removal matrix
Response.Redirect "removePolicies.asp"
%>