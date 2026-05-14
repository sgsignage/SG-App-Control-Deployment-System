<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, reqID, action
Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString

reqID = Request.QueryString("id")
action = Request.QueryString("pendingAction")

If IsNumeric(reqID) Then
    ' Based on the action, we know which table to delete from
    If action = "deploy" Then
        cn.Execute("DELETE FROM PoliciesToBeDeployed WHERE id = " & reqID)
    ElseIf action = "remove" Then
        cn.Execute("DELETE FROM PoliciesToBeRemoved WHERE id = " & reqID)
    End If
End If

cn.Close
Set cn = Nothing

' Redirect back to the page you came from
Response.Redirect Request.ServerVariables("HTTP_REFERER") 
%>