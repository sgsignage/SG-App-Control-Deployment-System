<%@ Language=VBScript %>
<% Option Explicit %>
<!-- #include file="includes.asp" -->
<%
Dim cn, mySQL, rs, i
Dim IsBasePolicy, IsLockedPolicy


Set cn = Server.CreateObject("ADODB.Connection")
cn.Open conString



' UPDATE existing workstations
For i = 1 to Request.Form("TotalNumOfPolicies")

    If Request.Form("IsBasePolicy-" & i) = "on" Then
        IsBasePolicy = 1
    Else
        IsBasePolicy = 0
    End If

    If Request.Form("IsLockedPolicy-" & i) = "on" Then
        IsLockedPolicy = 1
    Else
        IsLockedPolicy = 0
    End If

    If Request.Form("Remove-" & i) = "on" Then 'If the remove checkbox is checked, this takes priority
        mySQL = "DELETE FROM PolicyList WHERE ID = " & Request.Form("ID-" & i)
        'Response.Write mySQL & "<br>" & vbCrLf
        Set rs = cn.execute(mySQL)
    Else ' The remove checkbox is not checked, so we can update as long as BOTH PolicyFileName and FriendlyPolicyName has data in it
        If Request.Form("PolicyFileName-" & i) <> "" And Request.Form("FriendlyPolicyName-" & i) <> "" Then
            mySQL = "UPDATE PolicyList SET PolicyFileName = '" & Request.Form("PolicyFileName-" & i) & "', FriendlyPolicyName = '" & Request.Form("FriendlyPolicyName-" & i) & "', IsBasePolicy = " & IsBasePolicy & ", IsLockedPolicy = " & IsLockedPolicy & " WHERE ID = " & Request.Form("ID-" & i)
            'Response.Write mySQL & "<br>" & vbCRLf
            Set rs = cn.execute(mySQL)
        End If
    End If

Next




' ADD new policies
For i = 1 to maxNumOfPoliciesToAddAtATime

    If Request.Form("AddIsBasePolicy-" & i) = "on" Then
        IsBasePolicy = 1
    Else
        IsBasePolicy = 0
    End If

    If Request.Form("AddIsLockedPolicy-" & i) = "on" Then
        IsLockedPolicy = 1
    Else
        IsLockedPolicy = 0
    End If

    ' As long as a PolicyFileName AND FriendlyPolicyName are entered, we can add it to the database
    If Request.Form("AddPolicyFileName-" & i) <> "" And Request.Form("AddFriendlyPolicyName-" & i) <> "" Then
        mySQL = "INSERT INTO PolicyList (PolicyFileName, FriendlyPolicyName, IsBasePolicy, IsLockedPolicy) VALUES ('" & Request.Form("AddPolicyFileName-" & i) & "', '" & Request.Form("AddFriendlyPolicyName-" & i) & "', " & IsBasePolicy & "," & IsLockedPolicy & ")"
        'Response.Write mySQL & "<br>" & vbCRLf
        Set rs = cn.execute(mySQL)
    End If

Next



'Response.End



cn.Close
Set cn = Nothing

' Redirect back to the policies page
Response.Redirect "policies.asp"

%>