resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support = var.enable_dns_support


  tags = merge(
    var.common_tags,
    {
        Name = var.project_name
    },
    var.vpc_tags
  )
}
#IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
        Name = var.project_name
    },
    var.igw_tags
  )
}
#public Subnet
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr)
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-Public-${local.azs[count.index]}"
    }    
  )
}
#private Subnet
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-Private-${local.azs[count.index]}"
    }
  )
}
#database subnet
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidr)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidr[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-Database-${local.azs[count.index]}"
    }
  )
}
#Public routetable
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-PublicRT"
    }
  )
}
#Private routetable
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-PrivateRT"
    }
  )
}
#Database routetable
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-DatabaseRT"
    }
  )
}

#Adding route to Public RT
resource "aws_route" "public" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

#create Elastic IP
resource "aws_eip" "eip" {
  domain   = "vpc"
}

#Create NAT GW
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    {
        Name = var.project_name
    },
    var.natgw_tags
  )
  depends_on = [aws_internet_gateway.gw]
}

#Adding route to private RT
resource "aws_route" "private" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.natgw.id
}

#Adding route to Database RT
resource "aws_route" "database" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.natgw.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidr)
  subnet_id      = element(aws_subnet.public[*].id,count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidr)
  subnet_id      = element(aws_subnet.private[*].id,count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidr)
  subnet_id      = element(aws_subnet.database[*].id,count.index)
  route_table_id = aws_route_table.database.id
} 