# Amazon Linux 2023 최신 AMI
# 기본 디스크는 gp3 8GiB이고, 인스턴스를 종료하면 함께 삭제된다.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# SSH 키페어: 내 PC에서 만든 공개 키만 AWS에 등록한다.
resource "aws_key_pair" "main" {
  key_name   = "b3-1-key"
  public_key = file("~/.ssh/b3-1.pub")
}

# EC2: 첫 부팅 때 user_data.sh로 Nginx를 설치하고 실행한다.
resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.main.key_name
  user_data              = file("user_data.sh")

  tags = { Name = "b3-1-web" }

  # 인터넷 경로가 연결된 뒤에 띄워야 부팅 중 Nginx 설치가 성공한다.
  depends_on = [aws_route_table_association.public]
}
