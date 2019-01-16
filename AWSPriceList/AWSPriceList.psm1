$script:PriceListBaseUrl = "https://pricing.us-east-1.amazonaws.com"

Function Get-AWSPriceListOffersIndexFile {
	<#
		.SYNOPSIS
			Retrieves the contents of the offers index file.

		.DESCRIPTION
			The cmdlet retrieves the base offer index file from https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json. It can be returned as a PSCustomObject or a JSON string.

		.PARAMETER AsJson
            Specifies that the content is returned as a JSON string instead of a PSCustomObject.

        .EXAMPLE
			Get-AWSPriceListOffersIndexFile

			Retrieves all of the available services.	

		.INPUTS
			None

		.OUTPUTS
			System.Management.Automation.PSCustomObject, System.String

		.NOTES
			AUTHOR: Michael Haken
			LAST UPDATE: 1/16/2019
	#>
	[CmdletBinding()]
	Param(
        [Parameter()]
        [Switch]$AsJson
	)

	Begin {
	}

	Process {
		[System.String]$OfferIndexUrl = "$script:PriceListBaseUrl/offers/v1.0/aws/index.json"
        
        [Microsoft.PowerShell.Commands.WebResponseObject]$Response = Invoke-WebRequest -Uri $OfferIndexUrl -Method Get

        if ($AsJson)
        {
            Write-Output -InputObject ([System.Text.Encoding]::UTF8).GetString($Response.Content)
        }
        else
        {
            Write-Output -InputObject (ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8).GetString($Response.Content))
        }
	}

	End {
	}
}

Function Get-AWSPriceListCurrentOfferUrls {
	<#
		.SYNOPSIS
			Retrieves a list of the offer index files for each available service.

		.DESCRIPTION
			The cmdlet retrieves the base offer index file from https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json. It parses out the urls for the available services. These urls can be used to retrieve the specific pricing information for those services.

		.EXAMPLE
			Get-AWSPriceListCurrentOfferUrl

			Retrieves all of the offer index file urls.		

		.INPUTS
			None

		.OUTPUTS
			System.String[]

		.NOTES
			AUTHOR: Michael Haken
			LAST UPDATE: 1/16/2019
	#>
	[CmdletBinding()]
	Param(
	)

	Begin {
	}

	Process {
		[PSCustomObject]$IndexFileContents = Get-AWSPriceListOffersIndexFile

		[System.String[]]$Results = @()

        $IndexFileContents.offers | Get-Member -MemberType *Property | ForEach-Object {
			try 
			{
				$Name = $_.Name
				$Results += "$script:PriceListBaseUrl$($IndexFileContents.offers | Select-Object -ExpandProperty $_.Name | Select-Object -ExpandProperty currentVersionUrl)"
			}
			catch 
			{
				Write-Warning -Message "Error parsing $Name : $_.Exception.Message"
			}
        }

		Write-Output -InputObject $Results
	}

	End {
	}
}

Function Get-AWSPriceListServices {
	<#
		.SYNOPSIS
			Retrieves a list of the available services in the price list api.

		.DESCRIPTION
			The cmdlet retrieves the base offer index file from https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/index.json. It parses out the the available services from the offer file.

		.EXAMPLE
			Get-AWSPriceListServices

			Retrieves all of the available services.	

		.INPUTS
			None

		.OUTPUTS
			System.String[]

		.NOTES
			AUTHOR: Michael Haken
			LAST UPDATE: 1/16/2019
	#>
	[CmdletBinding()]
	Param(
	)

	Begin {
	}

	Process {
		[PSCustomObject]$IndexFileContents = Get-AWSPriceListOffersIndexFile

		[System.String[]]$Results = @()

        $IndexFileContents.offers | Get-Member -MemberType *Property | ForEach-Object {
			try 
			{
                $Name = $_.Name
				$Results += $Name
			}
			catch 
			{
				Write-Warning -Message "Error parsing $Name : $_.Exception.Message"
			}
        }

		Write-Output -InputObject $Results
	}

	End {
	}
}

Function Get-AWSPriceListProductInformation {
	<#
		.SYNOPSIS
			This cmdlet evaluates the data in the AWS Price List API json and returns information about products that match the search criteria.

		.DESCRIPTION
			The cmdlet parses the json in a specified file on disk retrieved from the price list API or downloads it directly from the provided Url. It matches products
			against the specified attributes. This is useful to find say all of the different SKUs and Operation codes for db.m4.large instances in US East (N. Virginia).

		.PARAMETER Path
			The path to the downloaded price list API file.

		.PARAMETER Url
			The Url containing the price list information for the product you want.

		.PARAMETER Product
			The product you want to download price list information for.

		.PARAMETER Filter
			The attributes used to match specific skus in the price list API. The filter will look like: @{"location" = "US East (N. Virginia)"; "instanceType" = "db.m4.large"; "databaseEngine" = "PostgreSQL"}. The key values will be matched against the product attribute key values.

		.EXAMPLE
			Get-AWSProductInformation -Product AmazonRDS -Filter @{"location" = "US East (N. Virginia)"; "instanceType" = "db.m4.large"; "databaseEngine" = "PostgreSQL"}

			Gets matching RDS skus for the attributes specified

		.EXAMPLE
			Get-AWSPriceListProductInformation -Url https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRDS/current/index.json -Filter @{"location" = "US East (N. Virginia)"; "instanceType" = "db.m4.large"; "databaseEngine" = "PostgreSQL"}

			Gets matching RDS skus for the attributes specified

		.EXAMPLE
			Get-AWSPriceListProductInformation -Product AmazonEC2 -Filter @{"location" = "US East (N. Virginia)"; "instanceType" = "m4.large"}

			Gets matching EC2 skus for the attributes specified

		.EXAMPLE
			Get-AWSPriceListProductInformation -Path index.json -Filter @{"location" = "US East (N. Virginia)"; "instanceType" = "m4.large"}
	
			Gets matching EC2 skus for the attributes specified

		.INPUTS
			None

		.OUTPUTS
			System.Management.Automation.PSCustomObject

		.NOTES
			AUTHOR: Michael Haken
			LAST UPDATE: 1/16/2019

	#>
	[CmdletBinding(DefaultParameterSetName = "Path")]
	Param(
		[Parameter(Mandatory = $true, ParameterSetName = "Path")]
		[ValidateScript({Test-Path $_})]
		[System.String]$Path,

		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[System.Collections.Hashtable]$Filter
	)

	DynamicParam {
		[System.Management.Automation.RuntimeDefinedParameterDictionary]$ParamDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary

		[PSCustomObject]$OfferIndexFile = Get-AWSPriceListOffersIndexFile

		[System.String[]]$Urls = @()
		[System.String[]]$Products = @()

		$OfferIndexFile.offers | Get-Member -MemberType *Property | ForEach-Object {
			try 
			{
				$Products += $_.Name
				$Urls += "$script:PriceListBaseUrl$($OfferIndexFile.offers | Select-Object -ExpandProperty $_.Name | Select-Object -ExpandProperty currentVersionUrl)"
			}
			catch 
			{
				Write-Verbose -Message "Error parsing $Name : $_.Exception.Message"
			}
        }

		New-DynamicParameter -Name "Url" -Type ([System.Uri]) -ValidateSet $Urls -Mandatory -ParameterSets "Url" -ValidateNotNullOrEmpty -RuntimeParameterDictionary $ParamDictionary | Out-Null	

		New-DynamicParameter -Name "Product" -Type ([System.String]) -ValidateSet $Products -Mandatory -ParameterSets "Product" -ValidateNotNullOrEmpty -RuntimeParameterDictionary $ParamDictionary | Out-Null

		Write-Output -InputObject $ParamDictionary
	}

	Begin {
	}

	Process
	{

		switch ($PSCmdlet.ParameterSetName)
		{
			"Url" {
				[System.String]$private:Response = [System.Text.Encoding]::UTF8.GetString((Invoke-WebRequest -Uri $PSBoundParameters["Url"] -Method Get | Select-Object -ExpandProperty Content))
				break
			}
			"Product" {
				$private:Url = "$script:PriceListBaseUrl$($OfferIndexFile.offers | Select-Object -ExpandProperty $PSBoundParameters["Product"] | Select-Object -ExpandProperty currentVersionUrl)"
				[System.String]$private:Response = [System.Text.Encoding]::UTF8.GetString((Invoke-WebRequest -Uri $private:Url -Method Get | Select-Object -ExpandProperty Content))
				break
			}
			"Path" {
				[System.String]$private:Response = Get-Content -Path $Path -Raw
				break
			}
			default {
				throw "The parameter set $($PSCmdlet.ParameterSetName) was not recognized."
			}
		}

		<#
			The converted Obj object will look like the following:

			formatVersion   : v1.0
			disclaimer      : This pricing list is for informational purposes only. All prices are subject to the additional terms included in the pricing pages on http://aws.amazon.com. All Free Tier 
							  prices are also subject to the terms included at https://aws.amazon.com/free/
			offerCode       : AmazonElastiCache
			version         : 20170419194925
			publicationDate : 2017-04-19T19:49:25Z
			products        : @{HBRQZSXXSY2DXJ77=; 3Y8QARGM5NXC9EBW=; ... }
			terms           : @{OnDemand=; Reserved=}
		#>
		$private:ConvertedResponse = ConvertFrom-Json -InputObject $private:Response

		[PSCustomObject[]]$private:Results = @()

		# Expanding the products property gets us a single object with members like
		# RBW79EQZWRSDB85D : @{sku=RBW79EQZWRSDB85D; productFamily=Database Instance; attributes=}
		# W3PUKFKG7RDK3KA5 : @{sku=W3PUKFKG7RDK3KA5; productFamily=Data Transfer; attributes=}
		
		# We want to expand the property of the products object for each sku to access the hash table that has the data
		<#
			Products will look like
			8W42JWEZE64YAUET : @{sku=8W42JWEZE64YAUET; productFamily=Cache Instance; attributes=}
			T64VHYZ5FZP9JDEC : @{sku=T64VHYZ5FZP9JDEC; productFamily=Cache Instance; attributes=}
		#>
		[PSCustomObject]$private:Products = $private:ConvertedResponse | Select-Object -ExpandProperty products 

		# Getting the members of Products will get us all of the sku properties, we want to iterate each
		# one and select it, expanded from the products object, which will provide the hash table of data
		# which includes sku, productFamily, and attributes
		Get-Member -InputObject $private:Products -MemberType *Property | ForEach-Object {
			
            # The Get-Member results will have a name property, that is the sku data for each product
			# By expanding the name property, we get the values of the sku index, which are the properties
			# like attributes and productfamily
			[PSCustomObject]$private:ProductData = $private:Products | Select-Object -ExpandProperty $_.Name

            [System.Collections.Hashtable]$private:TempHashTable = @{}
            
            # Convert the PSCustomObject to a hash table
            $private:ProductData.attributes.psobject.Properties | ForEach-Object  {
                $private:TempHashTable[$_.Name] = $_.Value
            }

			# Assume the product matches the filters, and prove it false
			$private:Matches = $true

			# Now that we have product object, we can filter based on the key value pairs provided
			foreach ($Key in $Filter.Keys)
			{
                # If the hash table doesn't contain the key and the values are not alike, it doesn't match
                # Otherwise, keep going
                if (-not ($private:TempHashTable.ContainsKey($Key) -and $private:TempHashTable[$Key] -like $Filter[$Key]))
                {                    
                    $private:Matches = $false
                    break                    
                }
			}

			if ($private:Matches -eq $true)
			{
                $private:Results += [PSCustomObject]@{"Sku" = $private:ProductData.sku; "ProductFamily" = $private:ProductData.productFamily; "Attributes" = $TempHashTable}
			}
		}

		Write-Output -InputObject $private:Results
	}

	End {		
	}
}