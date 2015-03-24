[Hashtable]@{
	Tasks = [Ordered]@{
		PushChocolateyPackage = [Hashtable]@{
			Name = [String]"PushChocolateyPackage"; 
			PackageId = [String]"PushChocolateyPackage"; 
			PackageVersion = [String]"0.0.11"; 
			Parameters = [Hashtable]@{
				IncludeNupkgFilePath = [String[]]@(
					[String]".\Src\*"
				)
			}
		}
	}
}
