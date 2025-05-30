# MOA를 위한 GCP Terraform

이 저장소는 MOA 애플리케이션을 위한 Google Cloud Platform에 완전한 인프라를 배포하기 위한 Terraform 코드를 포함하고 있습니다.

## 생성 리소스

- VPC 네트워크 및 서브넷
- SSH, 웹 서비스 및 헬스 체크를 위한 방화벽 규칙
- Ubuntu 22.04가 설치된 백엔드 VM 인스턴스
- NVIDIA T4 GPU가 장착된 AI 서버
- 정적 프론트엔드 파일을 위한 Cloud Storage 버킷
- CDN이 포함된 프론트엔드 로드 밸런서
- API 라우팅이 포함된 백엔드 로드 밸런서
- 백엔드 서비스를 위한 인스턴스 그룹

## 사전 요구 사항

- Terraform 설치 (버전 >= 1.0)
- Google Cloud SDK 설치
- 결제가 활성화된 GCP 프로젝트
- 적절한 권한이 있는 서비스 계정

## 사용 방법

1. 예제를 기반으로 `terraform.tfvars` 파일 생성:
   ```
   cp terraform.tfvars.example terraform.tfvars
   ```
2. GCP 프로젝트 ID 및 기타 설정으로 `terraform.tfvars` 편집
3. Terraform 초기화:
   ```
   terraform init
   ```
4. 배포 계획:
   ```
   terraform plan
   ```
5. 구성 적용:
   ```
   terraform apply
   ```

## Variables

| 이름 | 설명 | 기본값 |
|------|-------------|---------|
| project_id | GCP 프로젝트 ID | (필수) |
| region | 리소스를 위한 GCP 리전 | asia-northeast3 |
| zone | 영역 리소스를 위한 GCP 영역 | asia-northeast3-c |
| environment | 환경 이름 (dev, staging, prod) | dev |

## Outputs

| 이름 | 설명 |
|------|-------------|
| vpc_id | VPC의 ID |
| subnet_id | 서브넷의 ID |
| instance_name | 백엔드 VM 인스턴스의 이름 |
| instance_external_ip | 백엔드 VM 인스턴스의 외부 IP |
| ai_instance_name | AI VM 인스턴스의 이름 |
| ai_instance_external_ip | AI VM 인스턴스의 외부 IP |
| frontend_bucket_name | 프론트엔드 정적 웹사이트 버킷의 이름 |
| frontend_bucket_url | 프론트엔드 정적 웹사이트의 URL |
| frontend_load_balancer_ip | 프론트엔드 로드 밸런서의 IP 주소 |
| backend_load_balancer_ip | 백엔드 로드 밸런서의 IP 주소 |
| backend_service_name | 백엔드 서비스의 이름 |

## 아키텍처

- **프론트엔드**: Cloud Storage에 호스팅된 정적 웹사이트, CDN이 포함된 글로벌 로드 밸런서를 통해 제공
- **백엔드**: 60GB 스토리지, e2-medium에서 실행되는 Ubuntu VM, 로드 밸런서를 통해 접근 가능
- **AI 서버**: 130GB 스토리지, n1-standard-4에서 NVIDIA T4 GPU로 실행되는 Ubuntu VM

## 참고 사항

- HTTPS를 활성화하기 전에 SSL 인증서를 구성해야 함
- HTTPS 프록시 구성에서 PROJECT_ID를 실제 GCP 프로젝트 ID로 교체해야 함