# FAQ

### 1. How do I run and make changes to PA locally?

First, fork this repository and clone the master branch. Then, navigate into /.../client/AM.PA.MonitoringTool and open the "AM.PA.MonitoringTool.sln" file in an IDE 
(Visual Studio is recommended). Finally, in the solution explorer, right-click on "PersonalAnalytics" and click "Set as startup project".


# General Tips

- If you have PA installed and you also want to debug PA, temporarily change the "pa.dat" file to "pa.orig.dat". You can find this file if you right-click on the system tray icon 
and choose open collected data. For your debugging, use another sqlite db (e.g "pa.debug.dat"). This ensures that you do not interfere with your own retrospection.
