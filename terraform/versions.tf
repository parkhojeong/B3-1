terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2" # 서울 리전
  profile = "b3-1"           # aws login으로 로그인한 실습용 IAM 사용자

  # 모든 리소스에 Project 태그를 붙여 정리할 때 찾기 쉽게 한다.
  default_tags {
    tags = { Project = "b3-1" }
  }
}
