provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "MyVPC"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "MyIGW"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zone

  tags = {
    Name = "PrivateSubnet"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "frontend_sg" {
  vpc_id      = aws_vpc.my_vpc.id
  name        = "frontend-sg"
  description = "Allow HTTP inbound traffic for frontend"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FrontendSG"
  }
}

resource "aws_security_group" "backend_sg" {
  vpc_id      = aws_vpc.my_vpc.id
  name        = "backend-sg"
  description = "Allow inbound traffic from frontend and SSH for backend"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "BackendSG"
  }
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "frontend_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name      = aws_key_pair.my_key_pair.key_name

  tags = {
    Name = "FRONTEND"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "./frontend.sh"
    destination = "/tmp/frontend.sh"
  }

  provisioner "file" {
    source      = "./APP/FRONTEND/index.html"
    destination = "/tmp/index.html"
  }

  provisioner "file" {
    source      = "./APP/FRONTEND/Dockerfile"
    destination = "/tmp/Dockerfile.frontend"
  }
}

resource "aws_instance" "backend_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name      = aws_key_pair.my_key_pair.key_name

  tags = {
    Name = "BACKEND"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = self.private_ip
    timeout     = "10m"
    bastion_host = aws_instance.frontend_instance.public_ip
    bastion_user = "ubuntu"
  }

  provisioner "file" {
    source      = "./backend.sh"
    destination = "/tmp/backend.sh"
  }

  provisioner "file" {
    source      = "./APP/BACKEND/app.py"
    destination = "/tmp/app.py"
  }

  provisioner "file" {
    source      = "./APP/BACKEND/requirements.txt"
    destination = "/tmp/requirements.txt"
  }

  provisioner "file" {
    source      = "./APP/BACKEND/Dockerfile"
    destination = "/tmp/Dockerfile.backend"
  }
}

# This null resource waits for the frontend instance to be reachable via SSH
resource "null_resource" "wait_for_frontend" {
  depends_on = [aws_instance.frontend_instance]

  provisioner "local-exec" {
    command = "for i in $(seq 1 100); do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa -l ubuntu ${aws_instance.frontend_instance.public_ip} -C 'exit 0' && exit 0 || sleep 5; done; exit 1"
  }
}

# This null resource handles the deployment of the backend application
resource "null_resource" "deploy_backend_app" {
  depends_on = [
    aws_instance.backend_instance,
    null_resource.wait_for_frontend
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = aws_instance.backend_instance.private_ip
    bastion_host = aws_instance.frontend_instance.public_ip
    bastion_user = "ubuntu"
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/backend.sh",
      "sudo mv /tmp/app.py /tmp/APP_app.py",
      "sudo mv /tmp/requirements.txt /tmp/APP_requirements.txt",
      "sudo mv /tmp/Dockerfile.backend /tmp/APP_Dockerfile.backend",
      "sudo /tmp/backend.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Verifying Docker installation on Backend...'",
      "docker info || { echo 'Docker not installed or running on Backend!'; exit 1; }",
      "echo 'Verifying Backend container status...'",
      "docker ps -a | grep backend-app || { echo 'Backend container not running!'; exit 1; }",
      "echo 'Backend application deployed successfully!'"
    ]
  }
}

# This null resource handles the deployment of the frontend application
resource "null_resource" "deploy_frontend_app" {
  depends_on = [
    aws_instance.frontend_instance,
    null_resource.deploy_backend_app
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host        = aws_instance.frontend_instance.public_ip
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /tmp/frontend.sh ${aws_instance.frontend_instance.private_ip} ${aws_instance.backend_instance.private_ip}"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Verifying Docker installation on Frontend...'",
      "docker info || { echo 'Docker not installed or running on Frontend!'; exit 1; }",
      "echo 'Verifying Frontend container status...'",
      "docker ps -a | grep frontend-app || { echo 'Frontend container not running!'; exit 1; }",
      "echo 'Frontend application deployed successfully!'"
    ]
  }
}

