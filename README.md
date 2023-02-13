# DBADashExt
## DBADash Extension - Alerting Project

This is v0.2 of the DBADash Alerting Extenstion Project.

Please keep in mind that this is still wip and changes are most likely to occur. 

High level overview:
![image](https://user-images.githubusercontent.com/20295322/217355558-1e182939-8d08-440c-be3e-e3a13a994706.png)

You are free to download, change, modify the scripts here to better suit your needs. For now, this script is under no license.

With regards to the DBADash, full licensing terms can be found here: https://github.com/trimble-oss/dba-dash

Current development directions:
- add more alerts. To name a few: corruption, running queries (duration, critical waits, etc), DBs with no or old backups 
- currently, overriding alert defaults only works if alerts are targeted at specific tag names / tag values. There's a development direction to overcome this limitation and make overrides work all the time
