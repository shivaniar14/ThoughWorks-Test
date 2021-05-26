
  
#Cloud Provider Access
provider "aws" {
  region = "${var.region}"
  profile = "default"
}


# Setting up VPC
resource "aws_vpc" "mw_vpc" {
  cidr_block = "${var.aws_cidr_vpc}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "MediaWikiVPC"
  }
}

# Creating Internet Gateway to provide Internet to the Subnet
resource "aws_internet_gateway" "mw_igw" {
   vpc_id = "${aws_vpc.mw_vpc.id}"
   tags =  {
       Name = "MediaWiki Internet Gateway for Subnet1"
   }
}

# Grant the VPC internet access on its main route table

resource "aws_route_table" "mw_rt" {
 vpc_id = "${aws_vpc.mw_vpc.id}"
 route {
       cidr_block = "0.0.0.0/0"
       gateway_id = "${aws_internet_gateway.mw_igw.id}"
   }
}

resource "aws_route_table_association" "PublicAZA" {
   subnet_id = "${aws_subnet.mw_subnet1.id}"
   route_table_id = "${aws_route_table.mw_rt.id}"
}

resource "aws_route_table_association" "PublicAZB" {
   subnet_id = "${aws_subnet.mw_subnet2.id}"
   route_table_id = "${aws_route_table.mw_rt.id}"
}

resource "aws_route_table_association" "PublicAZC" {
   subnet_id = "${aws_subnet.mw_subnet3.id}"
   route_table_id = "${aws_route_table.mw_rt.id}"
}

resource "aws_subnet" "mw_subnet1" {
  vpc_id = "${aws_vpc.mw_vpc.id}"
  cidr_block = "${var.aws_cidr_subnet1}"
  availability_zone = "${element(var.azs, 1)}"

  tags = {
    Name = "MediaWikiSubnet1"
  }
}


resource "aws_subnet" "mw_subnet2" {
  vpc_id = "${aws_vpc.mw_vpc.id}"
  cidr_block = "${var.aws_cidr_subnet2}"
  availability_zone = "${element(var.azs, 2)}"
  tags =  {
    Name = "MediaWikiSubnet2"
  }
}

resource "aws_subnet" "mw_subnet3" {
  vpc_id = "${aws_vpc.mw_vpc.id}"
  cidr_block = "${var.aws_cidr_subnet3}"
  availability_zone = "${element(var.azs, 0)}"
  tags = {
    Name = "MediaWikiSubnet3"
  }
}


resource "aws_security_group" "mw_sg" {
  name = "mw_sg"
  vpc_id = "${aws_vpc.mw_vpc.id}"
  ingress {
    from_port = 22 
    to_port  = 22
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port = 80
    to_port  = 80
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 3306
    to_port  = 3306
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = "0"
    to_port  = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "tls_private_key" "mw_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = "${var.keyname}"
  public_key = "${tls_private_key.mw_key.public_key_openssh}"
}



# Launch the instance
resource "aws_instance" "webserver1" {
  ami           = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name  =  "${aws_key_pair.generated_key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.mw_sg.id}"]
  subnet_id     = "${aws_subnet.mw_subnet2.id}" 
  associate_public_ip_address = true
  tags  = {
    Name = "${lookup(var.aws_tags,"webserver1")}"
    group = "web"
  }
}

resource "aws_instance" "webserver2" {
  
  ami           = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name  = "${aws_key_pair.generated_key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.mw_sg.id}"]
  subnet_id     = "${aws_subnet.mw_subnet1.id}" 
  associate_public_ip_address = true
  tags = {
    Name = "${lookup(var.aws_tags,"webserver2")}"
    group = "web"
  }
}



resource "aws_instance" "dbserver" {
  
  ami           = "${var.aws_ami}"
  instance_type = "${var.aws_instance_type}"
  key_name  = "${aws_key_pair.generated_key.key_name}" 
  vpc_security_group_ids = ["${aws_security_group.mw_sg.id}"]
  subnet_id     = "${aws_subnet.mw_subnet2.id}"

  tags = {
    Name = "${lookup(var.aws_tags,"dbserver")}"
    group = "db"
  }
}





resource "aws_lb" "mw_nlb" {
  name               = "MediaWikiELB" 
  internal           = false
  load_balancer_type = "application"
  subnets            = ["${aws_subnet.mw_subnet1.id}", "${aws_subnet.mw_subnet2.id}"]

  enable_deletion_protection = false

}

resource "aws_lb_listener" "mw_listener" {
  load_balancer_arn = aws_lb.mw_nlb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mw_target.arn
  }
}

resource "aws_lb_target_group" "mw_target" {
  name     = "MediaWikiTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mw_vpc.id
  health_check   {
    port = 80
    protocol = "HTTP"
    unhealthy_threshold = 6
    healthy_threshold = 6
    interval =10
  }
}

resource "aws_lb_target_group_attachment" "mw_target_attachment1" {
  target_group_arn = aws_lb_target_group.mw_target.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "mw_target_attachment2" {
  target_group_arn = aws_lb_target_group.mw_target.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "null_resource" "null_provision"{
  depends_on = ["aws_lb_target_group.mw_target"]
   provisioner "local-exec" {
command = <<EOD
cat <<EOF > ../aws_hosts

[dev-mediawiki-web]
dev-mediawiki-web-1 ansible_host=${aws_instance.webserver1.public_ip}
dev-mediawiki-web-2 ansible_host=${aws_instance.webserver2.public_ip}

[dev-mediawiki-web:vars]
lb_url=${aws_lb.mw_nlb.dns_name}
database_ip=${aws_instance.dbserver.private_ip}

[dev-mediawiki-sql]
dev-mediawiki-sql-1 ansible_host=${aws_instance.dbserver.private_ip}

[dev-mediawiki-sql:vars]
web1=${aws_instance.webserver1.private_ip}
web2=${aws_instance.webserver2.private_ip}

[mysql-servers:children]
dev-mediawiki-sql

[apache-servers:children]
dev-mediawiki-web

EOF
EOD
}
  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.webserver1.id} ${aws_instance.webserver2.id} ${aws_instance.dbserver.id} --profile ${var.aws_profile} && cd .. && ansible-playbook -i aws_hosts? site.yml" 
  }
}
