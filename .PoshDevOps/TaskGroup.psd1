[PSCustomObject]@{
	Tasks = [Ordered]@{
		CreateChocolateyPackage = [PSCustomObject]@{
			Name = [String]"CreateChocolateyPackage"; 
			PackageId = [String]"CreateChocolateyPackage"; 
			PackageVersion = [String]"0.0.25"
		}; 
		PushChocolateyPackage = [PSCustomObject]@{
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
