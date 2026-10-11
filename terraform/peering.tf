resource "aws_vpc" "tools_vpc" {
  cidr_block           = var.tools_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "depi-sec-tools-vpc" }
}

resource "aws_subnet" "tools_private" {
  vpc_id            = aws_vpc.tools_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "depi-sec-tools-a" }
}

resource "aws_route_table" "tools_rt" { vpc_id = aws_vpc.tools_vpc.id }

resource "aws_route_table_association" "tools_assoc" {
  subnet_id      = aws_subnet.tools_private.id
  route_table_id = aws_route_table.tools_rt.id
}

resource "aws_security_group" "tools_sg" {
  name   = "depi-sec-tools-sg"
  vpc_id = aws_vpc.tools_vpc.id
}

resource "aws_vpc_security_group_egress_rule" "tools_egress" {
  security_group_id = aws_security_group.tools_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "tools_endpoint_sg" {
  name   = "depi-sec-tools-endpoint-sg"
  vpc_id = aws_vpc.tools_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "tools_endpoint_https" {
  security_group_id = aws_security_group.tools_endpoint_sg.id
  cidr_ipv4         = var.tools_vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "tools_endpoint_egress" {
  security_group_id = aws_security_group.tools_endpoint_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_endpoint" "tools_ssm" {
  vpc_id              = aws_vpc.tools_vpc.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.tools_private.id]
  security_group_ids  = [aws_security_group.tools_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "tools_ssmmessages" {
  vpc_id              = aws_vpc.tools_vpc.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.tools_private.id]
  security_group_ids  = [aws_security_group.tools_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "tools_ec2messages" {
  vpc_id              = aws_vpc.tools_vpc.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.tools_private.id]
  security_group_ids  = [aws_security_group.tools_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_instance" "tools" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.tools_private.id
  vpc_security_group_ids      = [aws_security_group.tools_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              systemctl enable --now amazon-ssm-agent
              systemctl restart amazon-ssm-agent
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "depi-sec-tools-monitor"
  }
}

resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.tools_vpc.id
  peer_vpc_id = aws_vpc.app_vpc.id
  auto_accept = true
  tags        = { Name = "depi-sec-peering" }
}

resource "aws_route" "app_to_tools" {
  route_table_id            = aws_route_table.private_rt.id
  destination_cidr_block    = aws_vpc.tools_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "tools_to_app" {
  route_table_id            = aws_route_table.tools_rt.id
  destination_cidr_block    = aws_vpc.app_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_tools" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "10.1.1.0/24"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "icmp_from_tools" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "10.1.1.0/24"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
}
