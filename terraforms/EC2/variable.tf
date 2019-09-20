provider "aws" {
	region			="us-east-2"
	access_key		="*************"
	secret_key		="************************"
	}
	
variable "vpcid"
{
default	="vpc-a67d9bcd"
}

variable "subnetid"
{
default	="subnet-*****"
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
default	="ami-*********"
}

variable	"region_az"
{
default	="us-east-1"
}


