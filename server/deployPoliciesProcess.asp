<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, deployItems, iItem, ids, wID, pID
Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString

' Retrieve the comma-separated list of "WorkstationID|PolicyID"
deployItems = Request.Form("deploy")
'Response.Write deployItems
'Response.End

If deployItems <> "" Then
    ' Split the list into individual workstation-policy pairs
    For Each iItem In Split(deployItems, ",")
        ' Split the pair back into individual IDs
        ids = Split(Trim(iItem), "|") 
        
        If UBound(ids) = 1 Then
            wID = ids(0)
            pID = ids(1)
            
            ' Insert into the queue table
            ' You may want to add a check here to prevent duplicate pending entries
            cn.Execute("INSERT INTO PoliciesToBeDeployed (WorkstationID, PolicyID) VALUES (" & wID & ", " & pID & ")")
            'Response.Write "INSERT INTO PoliciesToBeDeployed (WorkstationID, PolicyID) VALUES (" & wID & ", " & pID & ") <br>" & vbCrLf
        End If
    Next
End If

cn.Close
Set cn = Nothing

' Redirect back to the matrix
Response.Redirect "deployPolicies.asp"


%>
