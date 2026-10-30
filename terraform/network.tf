# 1. VPC: 다른 네트워크와 격리된 나만의 네트워크
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "b3-1-vpc" }
}

# 2. Internet Gateway: VPC와 인터넷 사이의 출입구
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "b3-1-igw" }
}

# 3. Public Subnet: EC2가 놓이는 구역. 인스턴스에 퍼블릭 IP를 자동으로 붙인다.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "b3-1-public-subnet" }
}

# 4. Route Table: 인터넷(0.0.0.0/0)으로 가는 트래픽을 IGW로 보낸다.
#    이 경로가 있어야 Public Subnet이 된다.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "b3-1-public-rt" }
}

# 5. Route Table을 Subnet에 연결한다.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
