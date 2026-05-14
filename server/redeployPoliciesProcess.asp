<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, redeployItems, iItem, ids, wID, pID
Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString

' Retrieve the comma-separated list of "WorkstationID|PolicyID" from 'redeploy' checkboxes
redeployItems = Request.Form("redeploy") 

If redeployItems <> "" Then
    For Each iItem In Split(redeployItems, ",")
        ids = Split(Trim(iItem), "|") 
        
        If UBound(ids) = 1 Then
            wID = ids(0)
            pID = ids(1)
            
            ' Insert into the PoliciesToBeDeployed table 
            cn.Execute("INSERT INTO PoliciesToBeDeployed (WorkstationID, PolicyID) VALUES (" & wID & ", " & pID & ")")
            'Response.Write "INSERT INTO PoliciesToBeDeployed (WorkstationID, PolicyID) VALUES (" & wID & ", " & pID & ") <br>" & vbCrLf
        End If
    Next
End If

cn.Close
Set cn = Nothing

' Redirect back to the re-deploy matrix
Response.Redirect "redeployPolicies.asp"
%>