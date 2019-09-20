provider "aws" {
	region			="us-east-2"
	access_key		="AKIAIKPCVLHA2RZ7JP4A"
	secret_key		="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"
	}
	
variable "vpcid"
{
default	="vpc-0013700f9e3aeb2fa"
}

variable "subnetid"
{
default	="subnet-0432f3496eb371acb "
}

variable "subnetid_1"
{
default = "subnet-7f470005"
}

variable "subnetid_2"
{
default = "subnet-1a7bd456"
}

variable	"keypair_name"
{
default	="ELB"
}

variable	"sg_cidr"
{
default	=""
}

variable	"amiid"
{
default	="ami-0d8f6eb4f641ef691"
}

variable	"region_az"
{
default	="us-east-2"
}


