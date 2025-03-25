provider "aws"{
  region = "eu-central-1"
}

variable vpc_cidr_block{}
variable subnet_cidr_block{}
variable avail_zone{}
variable env_prefix{}
variable my_ip{}
variable instance_type{}
variable public_key_location{}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "myapp-igw" { # like virtual modem that connects to internet
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

# use default rtb. Subnet association will happen by default if using default rtb
resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0" # opens to internet
    gateway_id = aws_internet_gateway.myapp-igw.id # need a gw
  }
  tags = {
    Name: "${var.env_prefix}-main-rtb"
  }
}

resource "aws_default_security_group" "default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id

  ingress { # for ssh into ec2 & accessing from browser
    from_port = 22
    to_port = 22 # can configure a range but doing just 22 for now
    protocol = "TCP"
    cidr_blocks = [var.my_ip] # range that are allowed
  }
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"] #open
  }

  egress { # for installations and fetching docker image
    from_port = 0
    to_port = 0
    protocol = "-1" #any
    cidr_blocks = ["0.0.0.0/0"] #open
    prefix_list_ids = []
  }

  tags = {
    Name: "${var.env_prefix}-default-sg"
  }

}

# fetch AMI id from AWS
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

}

output "aws-ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2-public_ip" {
  value = aws_instance.myapp-server.public_ip
}


resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location) # so I dont hardcode "server-key_pair" name from AWS
}


resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id # should not be hardcoded because it can be updated on AWS
  instance_type = "t2.micro"

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  # allows to ssh into instance. AWS rejects SSH request if permissions
  # are not set correctly on .pem file
  key_name = aws_key_pair.ssh-key.key_name

  user_data = file("entry-script.sh")

  # user_data runs again if something in it changes
  user_data_replace_on_change = true

  tags = {
    Name: "${var.env_prefix}-server"
  }
}
