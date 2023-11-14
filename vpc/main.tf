variable "environment" {
  
}

variable "vpc" {
  type = object({
    default_az = string
    cidr = string
    azs = list(string)
    public_cidrs = list(string)
    private_cidrs = list(string)
  })
}


resource "aws_vpc" "global_vpc" {
    cidr_block = var.vpc.cidr
    enable_dns_support = true // must have for eks
    enable_dns_hostnames = true // must have for eks
    
    tags = {
        Name = "global_vpc"
        Environment = var.environment
    }
  
}

resource "aws_security_group" "global_sg" {
    name = "sg_global"
    description = "Global security group which apply EC2 instance"
    vpc_id = aws_vpc.global_vpc.id
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
        description = "Managed by terraform - HTTPS traffic"
    }    

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags = {
        Name = "global_sg"
        Environment = var.environment
    }
}


resource "aws_subnet" "global_public_subnet" {
  count = length(var.vpc.public_cidrs)
  vpc_id = aws_vpc.global_vpc.id
  cidr_block = element(var.vpc.public_cidrs, count.index)
  availability_zone = element(var.vpc.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_${var.environment}_public_${format("%03d", count.index +1)}"
    Environment = var.environment
    "kubernetes.io/role/internal-elb" = "1"

  }
}

resource "aws_internet_gateway" "global_ig" {
    vpc_id = aws_vpc.global_vpc.id

    tags = {
        Name = "global_ig_${var.environment}"
        Environment = var.environment
    }

}

resource "aws_eip" "global_eip" {
  vpc = true
}

resource "aws_nat_gateway" "global_nat" {
  allocation_id = aws_eip.global_eip.id
  subnet_id = aws_subnet.global_public_subnet[0].id
  depends_on = [ 
    aws_internet_gateway.global_ig,
    aws_eip.global_eip
   ]

   tags = {
    Name = "global_nat_${var.environment}"
    Environment = var.environment
   }
}

resource "aws_route_table" "global_public_rtb" {
    vpc_id = aws_vpc.global_vpc.id
    tags = {
      Name = "public_route_table_${var.environment}"
      Environment = var.environment
    }
  
}

resource "aws_route" "rt_route_global_public" {
    route_table_id = aws_route_table.global_public_rtb.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.global_ig.id
}

resource "aws_route_table_association" "rtb_association_global_public" {
    count = length(var.vpc.azs)
    subnet_id = element(aws_subnet.global_public_subnet.*.id, count.index)
    route_table_id = aws_route_table.global_public_rtb.id
  
}


resource "aws_subnet" "global_private_subnet" {
    count = length(var.vpc.private_cidrs)
    vpc_id = aws_vpc.global_vpc.id
    cidr_block = element(var.vpc.private_cidrs, count.index)
    availability_zone = element(var.vpc.azs, count.index)
    tags = {
        Name = "subnet_${var.environment}_private_${format("%03d", count.index +1)}"
        Environment = var.environment
        "kubernetes.io/role/internal-elb" = "1"
    }
}

resource "aws_route_table" "global_private_rtb" {
    vpc_id = aws_vpc.global_vpc.id

    tags = {
        Name = "private_route_table_${var.environment}"
        Environment = var.environment
    }
  
}

resource "aws_route" "rt_route_global_private" {
    route_table_id = aws_route_table.global_private_rtb.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.global_nat.id

}

resource "aws_route_table_association" "rtb_association_global_private" {
    count = length(var.vpc.azs)
    subnet_id = element(aws_subnet.global_private_subnet.*.id, count.index)
    route_table_id = aws_route_table.global_private_rtb.id
  
}

output "vpc_id" {
  value = aws_vpc.global_vpc.id
}

output "vpc_sg_id" {
  value = aws_security_group.global_sg.id
}

output "vpc_public_rt_id" {
  value = aws_route_table.global_public_rtb
}


output "vpc_nat_public_ip" {
  value = aws_nat_gateway.global_nat.public_ip
}

output "vpc_subnet_public_ids" {
  value = aws_subnet.global_public_subnet.*.id
}

output "vpc_subnet_private_ids" {
  value = aws_subnet.global_private_subnet.*.id
}