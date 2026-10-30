# Security Group: EC2 앞의 방화벽. 필요한 포트만 연다.
resource "aws_security_group" "web" {
  name   = "b3-1-web-sg"
  vpc_id = aws_vpc.main.id

  # HTTP(80): 누구나 웹 서비스에 접속
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH(22): 내 IP에서만 접속
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # 아웃바운드: 패키지 설치(dnf)와 외부 통신(curl)을 위해 전체 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "b3-1-web-sg" }
}
