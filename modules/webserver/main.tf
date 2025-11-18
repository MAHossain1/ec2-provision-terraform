resource "aws_default_security_group" "default-sg" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Java App: 8080
  ingress {
    description      = "Java App"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Open to public (change if needed)
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow phpMyAdmin: 8082
  ingress {
    description      = "phpMyAdmin"
    from_port        = 8082
    to_port          = 8082
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow MySQL external access (not recommended for public)
  ingress {
    description      = "MySQL"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # ⚠️ Dangerous — better restrict to your IP
    ipv6_cidr_blocks = ["::/0"]
  }



  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env_prefix}-default-sg"
  }
}

# data "aws_ami" "latest-amazon-linux-image" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = [var.image_name]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ec2-provision-key"
  public_key = file(var.public_key_location)
}



resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.ubuntu_2204.id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  availability_zone      = var.avail_zone

  associate_public_ip_address = true
  key_name                    = aws_key_pair.ssh-key.key_name

  # user_data = file("entry-script.sh")

  tags = {
    Name = "${var.env_prefix}-server"
  }

}


resource "null_resource" "configure_server" {
  triggers = {
    trigger = aws_instance.myapp-server.public_ip
  }

  provisioner "local-exec" {
    working_dir = "/home/arman/learn-devops/ansible/learn-ansible"
    command     = <<EOT
    sleep 20 &&
    ansible-playbook -i '${aws_instance.myapp-server.public_ip},' \
      --private-key ${var.private_key_location} \
      --user ubuntu \
      deploy-docker-on-ubuntu.yaml
  EOT
  }
}
