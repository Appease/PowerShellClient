[Hashtable]@{
	"Tasks" = [Ordered]@{
		"PushChocolateyPackage" = [Hashtable]@{
			"PackageVersion" = [String]"0.0.11"; 
			"Name" = [String]"PushChocolateyPackage"; 
			"PackageId" = [String]"PushChocolateyPackage"; 
			"Parameters" = [Hashtable]@{
				"IncludeNupkgFilePath" = [String[]]@(
					[String]".\Src\*"
				)
			}
		}
	}
}
