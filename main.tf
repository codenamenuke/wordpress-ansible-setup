locals {
  ami_id = "ami-08fdec01f5df9998f"
  vpc_id = "vpc-0994a29c9c1a7a19a"
  ssh_user = "ubuntu"
  key_name = "wpserver"
  private_key_path = "/home/labsuser/terransible/wpserver.pem"
}

provider "aws" {
  access_key = ""
  secret_key = ""
  region = "us-east-1"
}

resource "aws_security_group" "wpserver" {
  name = "wpserver"
  vpc_id = local.vpc_id
  
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2wpserver" {
  ami = local.ami_id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.wpserversg.id]
  key_name = local.key_name
  
  tags = {
    Name = "WordPress Server"
  }
  
  provisioner "remote-exec" "sshhandshake" {
    connection {
      type = "ssh"
      host = aws_instance.ec2wpserver.public_ip
      user = local.ssh_user
      private_key = file(local.private_key_path)
      timeout = "4m"
    }
  }
}

# Creating a local hosts file for Ansible to use
resource "local_file" "hosts" {
  content = templatefile("${path.module}/templates/hosts",
    {
      public_ipaddr = aws_instance.ec2wpserver.public_ip
      key_path = local.private_key_path
      ansible_user = local.ssh_user
    }
  )
  filename = "${path.module}/hosts"
}

# We will use a null resource to execute the playbook with a local-exec provisioner.

resource "null_resource" "run_playbook" {
  depends_on = [
    
    # Running of the playbook depends on the successfull creation of the EC2
    # instance and the local inventory file.
    
    aws_instance.ec2wpserver,
    local_file.hosts,
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts playbook.yml"
  }
}
