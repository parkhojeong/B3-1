# 리소스 정리 체크리스트

과금 방지를 위해 실습 리소스를 생성 시점부터 정리 대상으로 추적한다.

## 추적 기준

- **태그**: 모든 리소스에 `Project=b3-1` 태그가 붙는다. 남은 리소스는 이 태그로 찾는다.
- **이름 규칙**: 리소스 이름은 `b3-1-`로 시작한다. 예: `b3-1-vpc`, `b3-1-web`.
- **Terraform state**: `terraform state list`가 Terraform이 만든 리소스 목록이다. destroy 후 비어 있어야 한다.
- **리전**: 모든 리소스는 ap-northeast-2에만 만든다.

## 1. 삭제 전 기록

```bash
terraform -chdir=terraform state list
```

출력된 8개 리소스(`aws_` 로 시작하는 줄)를 캡처한다. 맨 위 `data.aws_ami.al2023`은 AMI를 조회만 하는 데이터 소스라 삭제 대상이 아니다. → `docs/screenshots/cleanup-before.png`

## 2. 삭제 실행

```bash
terraform -chdir=terraform destroy
```

Terraform이 만든 순서의 역순으로 지운다.

1. EC2 종료. 루트 EBS는 AMI 기본 설정상 인스턴스와 함께 삭제된다.
2. 보안 그룹, 키페어 삭제
3. Route Table 연결 해제와 Route Table 삭제
4. Subnet 삭제
5. Internet Gateway 분리(Detach)와 삭제
6. VPC 삭제. VPC 기본 Route Table, 기본 보안 그룹, 기본 NACL도 함께 삭제된다.

출력 마지막 줄 `Destroy complete! Resources: 8 destroyed.`를 캡처한다.
→ `docs/screenshots/cleanup-destroy.png`

## 3. 삭제 확인

먼저 프로필과 리전을 지정한다.

```bash
export AWS_PROFILE=b3-1 AWS_REGION=ap-northeast-2
```

| 확인 | 항목 | 확인 명령 | 기대 결과 | 확인 결과 |
| --- | --- | --- | --- | --- |
| [x] | **EC2** Terminated | `aws ec2 describe-instances --filters Name=tag:Project,Values=b3-1 --query "Reservations[].Instances[].State.Name" --output text` | `terminated` | `terminated` (i-002280e850402a04f) |
| [x] | **EBS** 볼륨 삭제(미사용 포함) | `aws ec2 describe-volumes --query "Volumes[].[VolumeId,State]" --output text` | 출력 없음 | 출력 없음 (루트 볼륨 vol-08ced65596c887861 인스턴스와 함께 삭제) |
| [x] | **Elastic IP** Release | `aws ec2 describe-addresses --query "Addresses[].PublicIp" --output text` | 출력 없음 (이번 실습은 할당하지 않음) | 출력 없음 |
| [x] | **Internet Gateway** Detach 및 삭제 | `aws ec2 describe-internet-gateways --filters Name=tag:Project,Values=b3-1 --query "InternetGateways[].InternetGatewayId" --output text` | 출력 없음 | 출력 없음 (igw-072d41aa0591c9de9) |
| [x] | **VPC** 삭제 | `aws ec2 describe-vpcs --filters Name=tag:Project,Values=b3-1 --query "Vpcs[].VpcId" --output text` | 출력 없음 | 출력 없음 (vpc-002f37c9faebdea7b) |
| [x] | Subnet / Route Table 삭제 | `aws ec2 describe-subnets --filters Name=tag:Project,Values=b3-1 --query "Subnets[].SubnetId" --output text` | 출력 없음 | 출력 없음 (subnet-07b436f223036166c, rtb-05e501bed406be8f0) |
| [x] | 보안 그룹 삭제 | `aws ec2 describe-security-groups --filters Name=tag:Project,Values=b3-1 --query "SecurityGroups[].GroupId" --output text` | 출력 없음 | 출력 없음 (sg-06ae163504a7a3ee3) |
| [x] | 키페어 삭제 | `aws ec2 describe-key-pairs --filters Name=key-name,Values=b3-1-key --query "KeyPairs[].KeyName" --output text` | 출력 없음 | 출력 없음 (b3-1-key) |
| [x] | Terraform state 비어 있음 | `terraform -chdir=terraform state list` | 출력 없음 | 출력 없음 |

EBS 확인은 태그로 거르지 않고 리전 전체 볼륨을 본다. 태그가 없는 미사용 볼륨도 놓치지 않기 위해서다.
종료된 인스턴스는 약 1시간 동안 목록에 `terminated`로 남았다가 사라진다. 과금은 되지 않는다.

캡처 → `docs/screenshots/cleanup-verify.png`

## 4. 생성하지 않은 과금 리소스

이번 구성은 아래 리소스를 만들지 않는다. Terraform 코드에 해당 리소스가 없고, plan 결과에도 없다.

| 확인 | 항목 | 근거 |
| --- | --- | --- |
| [x] | NAT Gateway | `aws ec2 describe-nat-gateways --query "NatGateways[?State!='deleted'].NatGatewayId" --output text` 출력 없음 |
| [x] | ELB/ALB | 미생성. Terraform 코드와 state에 없음 |
| [x] | RDS | 미생성. Terraform 코드와 state에 없음 |

## 5. (권장) Billing 확인

- [ ] 모든 리소스 삭제 후 Billing and Cost Management → 청구서에서 ap-northeast-2의 EC2, VPC(퍼블릭 IPv4) 항목이 더 늘지 않는지 확인
- 캡처 → `docs/screenshots/billing.png` (선택)

## 정리 완료 기록

- 정리 일시: 2026-10-29 17:39 (KST)
- 확인자: 
- 비고: `terraform destroy` → `Destroy complete! Resources: 8 destroyed.` 삭제 확인 명령 결과 EC2는 `terminated`, 나머지는 모두 출력 없음. 증빙: `cleanup-before.png`, `cleanup-destroy.png`, `cleanup-verify.png`
