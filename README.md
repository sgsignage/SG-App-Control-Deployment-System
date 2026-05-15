# SG-App-Control-Deployment-System
A poor-man deployment system for Microsoft App Control (WDAC) policies. Uses a Powershell script on the client side, and IIS (classic .ASP pages) and MS SQL Server on the backend. Before we go any further, take a look at the Software Prerequisites section below. Don't worry - all the software needed can be obtained for free if you don't already have it.

## Features
- Simple, customizable, intuitive GUI Web-based interface
- Easily password-protect your web application
- Deploy policies to one or more workstations at once with just a couple clicks
- Re-deploy policies to one or more workstations at once with just a couple clicks
- Remove policies from one or more workstations at once with just a couple clicks
- Picks up 'unknown' policies from workstations and updates your database automatically
- Cancel any pending change (deployment or removal) with just a click
- Tracks your workstation's last check-in date/time
- Assign 'friendly' names to your policies in addition to the file name for quick identification
- 'Lock' policies (not the actual files, but the policies/deployment in the database) so that you don't accidently delete them
- Mark 'Base' policies as such

## Why
There are 3 reasons I built this:
1. We are a small company that does not use Intune. Intune is a paid service from Microsoft which we cannot afford. Unfortunately, from what I've gathered, Intune is the most popular method of deploying WDAC policies
2. I do not want to deploy all of our policies manually
3. I could not find any free deployment systems out there (there is a free program called 'AppControl Manager' which I checked out because I heard you can deploy policies from it, but guess what - it seems to use Intune! Doh!)

You can use GPO to distribute your policies, but I'm not too good at GPO and wanted something more powerful, visual, etc. anyway.

So if you're a small company that wants to utilize Microsoft App Control, but don't have Microsoft Intune, this may be perfect for you, so read on!

## Software Prerequisites
#### Microsoft Internet Information Services (IIS)
If you have a Windows Server, you may already have this installed (if it's not, you can install it via the 'Add Roles and Features Wizard'). If you don't have Windows Server (i.e. you're running Windows 11), you can download and install IIS Express from Microsoft for free at: https://www.microsoft.com/en-us/download/details.aspx?id=48264.

#### Microsoft SQL Server
If you do not have Microsoft SQL Server already, you can actually download it for free. Go to: https://www.microsoft.com/en-us/sql-server/sql-server-downloads and download the SQL Server 2025 Express, and install it. If you need a front-end in order to manage it (set up databases/tables/security/etc) like I do, you can download and install SQL Server Management Studio for free at: https://learn.microsoft.com/en-us/ssms/install/install

## How It Works (Bird's Eye View)
The way I see it there are 3 main components:
1. The PowerShell script that executes on the target/workstation.
2. The web application that runs on the 'server'
3. The database that assists in deployment, re-deployment, removal, and keeping track of everything, which also runs on the 'server'

## How It Works (The Gory Details)

## Installation Instructions

## Screenshots of the Management Interface

<img width="1882" height="888" alt="Deploy Policies" src="https://github.com/user-attachments/assets/f2f067ad-57ea-4cf0-a566-805837b079a4" />

<img width="1883" height="941" alt="Re-Deploy Policies" src="https://github.com/user-attachments/assets/3d8346fe-ca4f-43fe-b2f6-5d14f0a38d67" />

<img width="1885" height="938" alt="Remove Policies" src="https://github.com/user-attachments/assets/d3eff8b7-6e16-47b2-8edc-9bed0a24ad88" />

<img width="1884" height="942" alt="Policies" src="https://github.com/user-attachments/assets/644ba093-1b34-45ec-a7b5-970bf67101dc" />

<img width="1890" height="952" alt="Workstations" src="https://github.com/user-attachments/assets/2ac1b22f-ea2b-4f7c-a389-a8da63f90da8" />
