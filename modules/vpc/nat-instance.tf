# modules/vpc/nat-instance.tf

#------------------------------------------------------------------------------
# NAT Instance (비용 절감을 위해 NAT Gateway 대신 사용)
# 고가용성을 위해 각 AZ에 1개씩 배치 (총 2개)
#------------------------------------------------------------------------------

# Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# NAT Instance Security Group
resource "aws_security_group" "nat" {
  name        = "${var.name}-nat-sg"
  description = "Security group for NAT instances"
  vpc_id      = aws_vpc.this.id

  # Private subnet에서 오는 모든 트래픽 허용
  ingress {
    description = "All traffic from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [for s in aws_subnet.private : s.cidr_block]
  }

  ingress {
    description = "All traffic from database subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [for s in aws_subnet.database : s.cidr_block]
  }

  # SSH (관리용, 필요시만)
  dynamic "ingress" {
    for_each = length(var.admin_cidr_blocks) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.admin_cidr_blocks
    }
  }

  # 외부로 나가는 모든 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-nat-sg"
  })
}

#------------------------------------------------------------------------------
# NAT Instances (각 AZ에 1개씩)
#------------------------------------------------------------------------------
resource "aws_instance" "nat" {
  count = length(local.azs)

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  source_dest_check           = false # NAT에 필수
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

    # Configure iptables for NAT
    yum install -y iptables-services
    systemctl enable iptables
    systemctl start iptables

    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT

    service iptables save
  EOF

  tags = merge(var.tags, {
    Name = "${var.name}-nat-instance-${local.azs[count.index]}"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP for NAT Instances
resource "aws_eip" "nat" {
  count = length(local.azs)

  instance = aws_instance.nat[count.index].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}
