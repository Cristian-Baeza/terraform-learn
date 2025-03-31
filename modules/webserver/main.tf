resource "aws_default_security_group" "default-sg" {
  vpc_id = var.vpc_id

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
    values = [var.image_name]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location) # so I dont hardcode "server-key_pair" name from AWS
}

resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id # should not be hardcoded because it can be updated on AWS
  instance_type = "t2.micro"

  subnet_id = var.subnet_id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  # allows to ssh into instance. AWS rejects SSH request if permissions
  # are not set correctly on .pem file
  key_name = aws_key_pair.ssh-key.key_name

  user_data = file("${path.module}/entry-script.sh")

  # user_data runs again if something in it changes
  user_data_replace_on_change = true

  tags = {
    Name: "${var.env_prefix}-server"
  }
}
