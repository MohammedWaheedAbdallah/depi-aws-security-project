data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name = "name"
    # Excludes al2023-ami-minimal images: they do not include the SSM Agent.
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "app_a" {
  depends_on                  = [aws_efs_mount_target.mt_a, aws_efs_mount_target.mt_b]
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_a.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # bootstrap-v3: standard AL2023 + S3 return NACL rule
              set -o pipefail
              dnf install -y nginx amazon-efs-utils || yum install -y nginx amazon-efs-utils
              systemctl enable --now amazon-ssm-agent
              systemctl enable --now nginx
              echo "<h1>DEPI Secure Platform - ${aws_subnet.private_a.availability_zone}</h1>" > /usr/share/nginx/html/index.html
              mkdir -p /mnt/shared
              mount -t efs -o tls,accesspoint=${aws_efs_access_point.ap.id} ${aws_efs_file_system.shared.id}:/ /mnt/shared
              grep -q "${aws_efs_file_system.shared.id}" /etc/fstab || echo "${aws_efs_file_system.shared.id}:/ /mnt/shared efs _netdev,tls,accesspoint=${aws_efs_access_point.ap.id} 0 0" >> /etc/fstab
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "depi-sec-app-a"
  }
}

resource "aws_instance" "app_b" {
  depends_on                  = [aws_efs_mount_target.mt_a, aws_efs_mount_target.mt_b]
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private_b.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # bootstrap-v3: standard AL2023 + S3 return NACL rule
              set -o pipefail
              dnf install -y nginx amazon-efs-utils || yum install -y nginx amazon-efs-utils
              systemctl enable --now amazon-ssm-agent
              systemctl enable --now nginx
              echo "<h1>DEPI Secure Platform - ${aws_subnet.private_b.availability_zone}</h1>" > /usr/share/nginx/html/index.html
              mkdir -p /mnt/shared
              mount -t efs -o tls,accesspoint=${aws_efs_access_point.ap.id} ${aws_efs_file_system.shared.id}:/ /mnt/shared
              grep -q "${aws_efs_file_system.shared.id}" /etc/fstab || echo "${aws_efs_file_system.shared.id}:/ /mnt/shared efs _netdev,tls,accesspoint=${aws_efs_access_point.ap.id} 0 0" >> /etc/fstab
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "depi-sec-app-b"
  }
}
