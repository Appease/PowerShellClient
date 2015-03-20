[PSCustomObject]@{
	Tasks = [Ordered]@{
		CreateChocolateyPackage = [PSCustomObject]@{
			Name = [String]"CreateChocolateyPackage"; 
			PackageId = [String]"CreateChocolateyPackage"; 
			PackageVersion = [String]"0.0.21"
		}; 
		PushChocolateyPackage = [PSCustomObject]@{
			Name = [String]"PushChocolateyPackage"; 
			PackageId = [String]"PushChocolateyPackage"; 
			PackageVersion = [String]"0.0.9"; 
			Parameters = [Hashtable]@{
				IncludeNupkgFilePath = [String[]]@(
					[String]".\*"
				)
			}
		}
	}
}
