# 트러블슈팅 보고서

실습 중 실제로 겪은 문제를 기록한다. 각 건은 **증상 → 가설 → 검증 → 조치 → 결과 → 재발방지** 순서로 쓴다.
가설은 로그, 명령 출력, 콘솔 화면 같은 근거로 검증한 뒤에 조치한다.

## 점검 순서 (외부 접속이 안 될 때)

바깥에서 안쪽으로 한 단계씩 좁혀 간다.

| 단계 | 확인 내용 | 명령 / 위치 |
| --- | --- | --- |
| 1. 라우팅 | 서브넷 Route Table에 `0.0.0.0/0 → igw-` 경로가 있고 서브넷에 연결됐는가 | `aws ec2 describe-route-tables --filters Name=tag:Project,Values=b3-1` |
| 2. 보안 그룹 | 해당 포트가 열려 있고, SSH 소스가 현재 내 IP와 같은가 | `aws ec2 describe-security-group-rules --filters Name=group-id,Values=<sg-id>` / `curl -s https://checkip.amazonaws.com` |
| 3. 퍼블릭 IP | 인스턴스에 퍼블릭 IP가 있고, 접속하는 주소가 그 IP인가 | `terraform output public_ip` |
| 4. 서버 프로세스 | Nginx가 실행 중이고 80 포트에서 대기 중인가 | `systemctl status nginx`, `sudo ss -tlnp \| grep :80` |
| 5. 로그 | 부팅 스크립트와 Nginx 오류 로그 | `/var/log/cloud-init-output.log`, `/var/log/nginx/error.log`, `aws ec2 get-console-output --instance-id <id>` |

증상으로 대략 구분할 수 있다.

- **연결 시간 초과(timeout)** 는 패킷이 중간에서 버려진 경우다. 라우팅, 보안 그룹, 퍼블릭 IP 쪽을 먼저 의심한다.
- **연결 거부(connection refused)** 는 서버까지 도달했지만 그 포트에서 대기하는 프로세스가 없는 경우다. 서버 프로세스와 로그를 본다.
- **권한 오류(UnauthorizedOperation, AccessDenied)** 는 IAM 문제다. 오류 메시지의 액션 이름을 확인하고 그 액션만 정책에 추가한다. 권한을 한꺼번에 넓히지 않는다.

---

## 사례 1. SSH 접속 시간 초과 (HTTP는 정상)

- 발생 일시: 2026-10-29 17:27 (KST)
- 관련 리소스: sg-06ae163504a7a3ee3 (b3-1-web-sg), i-002280e850402a04f (b3-1-web)

| 항목 | 내용 |
| --- | --- |
| 증상(문제 상황) | `terraform apply` 직후 `curl http://13.125.231.232/health`는 `200 OK`였지만, `ssh -i ~/.ssh/b3-1 ec2-user@13.125.231.232`는 `Operation timed out` |
| 원인 가설 | 80은 되고 22만 안 되므로 라우팅·퍼블릭 IP·인스턴스 문제는 아니다. 거부(refused)가 아니라 시간 초과이므로 SG가 패킷을 버리는 것으로 보았다. SG의 SSH 소스 IP가 현재 내 IP와 다를 수 있다 |
| 검증 방법 | ① `curl -s https://checkip.amazonaws.com` → `112.216.150.166` (tfvars에 넣은 값은 `121.125.111.193`) ② SG 규칙 조회 → `22  121.125.111.193/32` ③ `nc -vz 13.125.231.232 22` 실패, `nc -vz 13.125.231.232 80` 성공, `nc -vz github.com 22` 성공 → 내 네트워크가 22 포트를 막는 것은 아님 |
| 조치 내용 | `terraform/terraform.tfvars`의 `my_ip`를 `112.216.150.166/32`로 바꾸고 `terraform apply`. plan은 `0 to add, 1 to change` (SG만 그 자리에서 수정, 인스턴스 유지) |
| 결과 | `Apply complete! Resources: 0 added, 1 changed` 후 SSH 접속 성공. 서버 안에서 `systemctl is-active nginx` → `active`, `curl http://localhost/health` → `200 OK` |
| 재발 방지 | 네트워크(와이파이)를 바꾸면 공인 IP가 바뀐다. 접속 전에 `curl -s https://checkip.amazonaws.com`과 tfvars 값을 비교하고, 다르면 tfvars를 고쳐 apply한다. SSH를 `0.0.0.0/0`으로 넓혀서 해결하지 않는다 |

**근거 자료**

```text
$ ssh -i ~/.ssh/b3-1 ec2-user@13.125.231.232
ssh: connect to host 13.125.231.232 port 22: Operation timed out

$ curl -s https://checkip.amazonaws.com
112.216.150.166

$ aws ec2 describe-security-groups --group-ids sg-06ae163504a7a3ee3 \
    --query 'SecurityGroups[0].IpPermissions[].[FromPort,IpRanges[0].CidrIp]' --output text
80	0.0.0.0/0
22	121.125.111.193/32

$ nc -vz -G 5 13.125.231.232 22
nc: connectx to 13.125.231.232 port 22 (tcp) failed: Operation timed out
$ nc -vz -G 5 13.125.231.232 80
Connection to 13.125.231.232 port 80 [tcp/http] succeeded!
```

스크린샷: `docs/screenshots/troubleshooting-1.png`

---

## 사례 2. terraform apply 시 자격 증명 만료

- 발생 일시: 2026-10-29 (apply 직전)
- 관련 리소스: 없음 (AWS에 아무것도 만들어지지 않음)

| 항목 | 내용 |
| --- | --- |
| 증상(문제 상황) | `terraform apply`가 리소스를 만들기 전에 `No valid credential sources found` / `login session has expired, please reauthenticate` 오류로 멈춤 |
| 원인 가설 | `aws login`으로 받은 임시 자격 증명의 세션이 만료되었다 (액세스 키를 쓰지 않으므로 세션 시간이 정해져 있다) |
| 검증 방법 | 오류 메시지가 `login session has expired`라고 명시함. 다시 로그인한 뒤 `aws sts get-caller-identity --profile b3-1`이 `user/b3-1-user`를 반환 |
| 조치 내용 | `aws login --profile b3-1 --region ap-northeast-2`로 다시 로그인 |
| 결과 | `terraform apply` 재실행 → `Apply complete! Resources: 8 added` |
| 재발 방지 | 작업을 시작할 때와 destroy 전에 `aws sts get-caller-identity --profile b3-1`로 세션을 먼저 확인한다 |

**근거 자료**

```text
Error: No valid credential sources found
  with provider["registry.terraform.io/hashicorp/aws"],
  on versions.tf line 10, in provider "aws":
Error: failed to refresh cached credentials, create oauth2 token: login
session has expired, please reauthenticate
```
