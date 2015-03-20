#Project Guidelines

##Feature Design
When designing features:

1.	All features must support both interactive and non-interactive consumption via PowerShell. 


##Development

####1 General
#####1.1 Follow MSDN Guidelines
PowerShell usage must be consistent with, [MSDN guidelines](https://msdn.microsoft.com/en-us/library/dd835506(v=vs.85).aspx). (some useful links within those guidelines are: [Module Installation](https://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx), [Command naming](https://msdn.microsoft.com/en-us/library/ms714428%28v=vs.85%29.aspx), [Standard Cmdlet parameter Names and Types](https://msdn.microsoft.com/en-us/library/dd878352(v=vs.85).aspx)

####2 CI-Tasks
#####2.1 Use string[] For Parameters Being Passed To Things Outside Powershell
When defining a DevOps task, if a parameter will be used asa pass-through to something outside Powershell (example: invoking a .exe), make the parameter of type string[]. For a great background on why see [powershell-call-operator-using-an-array-of-parameters-to-solve-all-your-quoting-problems](https://com2kid.wordpress.com/2011/09/25/powershell-call-operator-using-an-array-of-parameters-to-solve-all-your-quoting-problems/)
