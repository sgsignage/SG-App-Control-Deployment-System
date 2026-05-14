<%
Const conString = "driver={SQL Server};Description=SGSQL;SERVER=YOURSQLSERVERSCOMPUTERNAME\YOURSQLSERVERINSTANCENAME;UID=YOURAUTHORIZEDSQLUSERNAME;PWD=YOURAUTHORIZEDSQLUSERPASSWORD;DATABASE=SGAppControl"

Const maxNumOfWorkstationsToAddAtATime = 5
Const maxNumOfPoliciesToAddAtATime = 5
Const maxNumOfWorkstationsPerPage = 18

Const lockedIcon = "&#128274;"
Const cancelPendingIcon = "&osol;"

Const titleTag = "<title>SG WDAC App Control Management System</title>"



Dim navBarHTML
navBarHTML = navBarHTML & "<nav class=""simple-nav"">" & vbCrLf
navBarHTML = navBarHTML & "<ul>" & vbCrLf
navBarHTML = navBarHTML & "<li><a href=""deployPolicies.asp"">Deploy Policies</a></li>" & vbCrLf
navBarHTML = navBarHTML & "<li><a href=""redeployPolicies.asp"">Redeploy Policies</a></li>" & vbCrLf
navBarHTML = navBarHTML & "<li><a href=""removePolicies.asp"">Remove Policies</a></li>" & vbCrLf
navBarHTML = navBarHTML & "<li><a href=""policies.asp"">Policies</a></li>" & vbCrLf
navBarHTML = navBarHTML & "<li><a href=""workstations.asp"">Workstations</a></li>" & vbCrLf
navBarHTML = navBarHTML & "</ul>" & vbCrLf
navBarHTML = navBarHTML & "</nav>" & vbCrLf           
            
%>
