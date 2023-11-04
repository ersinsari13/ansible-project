//This Terraform Template creates 4 Ansible Machines on EC2 Instances
//Ansible Machines will run on Red Hat Enterprise Linux 9 with custom security group
//allowing SSH (22), 5000, 3000 and 5432 connections from anywhere.
//User needs to select appropriate variables form "tfvars" file when launching the instance.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  #  secret_key = ""
  #  access_key = ""
}

resource "aws_instance" "control_node" {
  ami = var.myami
  instance_type = var.controlinstancetype
  key_name = var.mykey
  iam_instance_profile = aws_iam_instance_profile.ec2full.name
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  tags = {
    Name = "ansible_control"
    stack = "ansible_project"
  }
}

resource "aws_instance" "nodes" {
  ami = var.myami
  instance_type = var.instancetype
  count = var.num
  key_name = var.mykey
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  tags = {
    Name = "ansible_${element(var.tags, count.index )}"
    stack = "ansible_project"
    environment = "development"
  }
  user_data = file("userdata.sh")
}

resource "aws_iam_role" "ec2full" {
  name = "projectec2full-${var.user}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
}

resource "aws_iam_instance_profile" "ec2full" {
  name = "projectec2full-${var.user}"
  role = aws_iam_role.ec2full.name
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "tf-sec-gr" {
  name = "${var.mysecgr}-${var.user}"
  vpc_id = data.aws_vpc.default.id
  tags = {
    Name = var.mysecgr
  }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5000
    protocol    = "tcp"
    to_port     = 5000
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    protocol    = "tcp"
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5432
    protocol    = "tcp"
    to_port     = 5432
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "config" {
  depends_on = [aws_instance.control_node]
  connection {
    host = aws_instance.control_node.public_ip
    type = "ssh"
    user = "ec2-user"
    private_key = file("${var.mykey}.pem")
    # Do not forget to define your key file path correctly!
  }

  provisioner "file" {
    source = "./ansible.cfg"
    destination = "/home/ec2-user/.ansible.cfg"
  }

  provisioner "file" {
    source = "./inventory_aws_ec2.yml"
    destination = "/home/ec2-user/inventory_aws_ec2.yml"
  }

  provisioner "file" {
    # Do not forget to define your key file path correctly!
    source = "${var.mykey}.pem"
    destination = "/home/ec2-user/${var.mykey}.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname Control-Node",
      "sudo yum install -y python3",
      "sudo yum install -y python3-pip",
      "pip3 install --user ansible",
      "pip3 install --user boto3",
      "chmod 400 ${var.mykey}.pem",
      "sudo echo postgresql_server_prip=${aws_instance.nodes[0].private_ip} >> varsip.yaml",
      "sudo echo nodejs_server_prip=${aws_instance.nodes[1].private_ip} >> varsip.yaml",
      "sudo echo react_server_prip=${aws_instance.nodes[2].private_ip} >> varsip.yaml",
      "sudo echo postgresql__pubip=${aws_instance.nodes[0].public_ip} >> varsip.yaml",
      "sudo echo nodejs__pubip=${aws_instance.nodes[1].public_ip} >> varsip.yaml",
      "sudo echo react__pubip=${aws_instance.nodes[2].public_ip} >> varsip.yaml",
    ]
  }

}

output "controlnodeip" {
  value = aws_instance.control_node.public_ip
}

output "privates" {
  value = aws_instance.control_node.*.private_ip
}

output "managed-node-public-ips" {
  value = [for managed-node in aws_instance.nodes : "ssh ec2-user@${managed-node.public_ip}"]
}

output "managed-nodes-private-ips" {
  value = aws_instance.nodes.*.private_ip
}
