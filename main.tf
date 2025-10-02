provider "aws" {}

variable vpc_cidr_block {} 
variable subnet_cidr_block {}
variable avail_zone {} 
variable env_prefix {} 
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable private_key_location {}

resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id 
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name = "${var.env_prefix}-subnet-1"
    }
}


/*
resource "aws_route_table" "myapp-route-table" {
    vpc_id = aws_vpc.myapp-vpc.id 

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-rtb"
    }
}
*/

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id 
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

/*
resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
}
*/

resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-main-rtb"
    }
}

# custom security group
/*    
resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-sg"
    }
}
*/

resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-default-sg"
    }
}

data "aws_ami" "latest-amazon-linux-image" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

output name {
  value = aws_instance.myapp-server.public_ip
}


resource "aws_key_pair" "ssh-key" {
    key_name = "ec2-provision-key"
    public_key = file(var.public_key_location)
}



resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name

    user_data = file("entry-script.sh")

    /* not recommended

       # Connection block: defines how Terraform connects to the EC2 instance for provisioning.
    connection {
        type       = "ssh"  # Use SSH for connection
        host       = self.public_ip  # Connect to the instance's public IP
        user       = "ec2-user"  # Default user for Amazon Linux
        private_key = file(var.private_key_location)  # Path to your private SSH key
    }

    # File provisioner: uploads a local script to the EC2 instance.
    provisioner "file" {
        source      = "entry-script.sh"  # Local script to upload
        destination = "/home/ec2-user/entry-script-on-ec2.sh"  # Destination path on the instance
    }

    # Remote-exec provisioner: runs a script on the EC2 instance after upload.
    provisioner "remote-exec" {
        script = file("entry-script-on-ec2.sh")  # Script to execute on the instance
    }

    # Local-exec provisioner: runs a command locally on your machine after instance creation.
    provisioner "local-exec" {
        command = "echo ${self.public_ip} > output.txt"  # Save the instance's public IP to a

    */

    tags = {
        Name = "${var.env_prefix}-server"
    }
}