
# Access
#variable "access_key" {}
#variable "secret_key" {}

# Region
variable "region" {
  default =  "us-east-1"
}

 # Availability Zones
 
variable "azs" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "keyname" {
  default = "mediawiki"
}


variable "aws_ami" {
  default="ami-0d5eff06f840b45e9"
}

# VPC and Subnet
variable "aws_cidr_vpc" {
  default = "10.0.0.0/16"
}

variable "aws_cidr_subnet1" {
  default = "10.0.1.0/24"
}

variable "aws_cidr_subnet2" {
  default = "10.0.4.0/24"
}

variable "aws_cidr_subnet3" {
  default = "10.0.0.0/24"
}

variable "aws_sg" {
  default = "sg_mediawiki"
}

variable "aws_tags" {
  type = map(string)
  default = {
    "webserver1" = "MediaWiki-Web-1"
	  "webserver2" = "MediaWiki-Web-2"
    "dbserver" = "MediaWikiDB" 
  }
}

variable "aws_instance_type" {
  default = "t2.micro"
}

variable "aws_profile" {
  default = "default"
}
