# IAM 관리 가이드

## 개요

이 문서는 AWS IAM 사용자, 그룹, CI/CD 서비스 Role 구성을 설명합니다.

---

## IAM 그룹 및 권한

| 그룹 | 권한 | 용도 |
|------|------|------|
| **backend** | CloudWatchLogsFullAccess, ECR Pull | 백엔드 개발자 |
| **frontend** | S3 ReadOnly, ECR Pull | 프론트엔드 개발자 |
| **projectmanage** | Billing ReadOnly | PM/PD |
| **AI** | CloudWatchLogsFullAccess, ECR Pull | AI 엔지니어 |
| **security** | SecurityAudit, WAF Full, CloudTrail Read | 보안팀 |
| **infra** | AdministratorAccess | 인프라팀 |

> 모든 그룹에 `IAMUserChangePassword` 정책이 공통으로 포함됩니다.

---

## IAM 사용자 목록

### Product Group (projectmanage)
| 사용자 | 역할 |
|--------|------|
| PM-jehyun | PM |
| PM-hs | PM |
| PD-seyoun9 | PD |
| PD-jbyun | PD |

### Backend Group (backend)
| 사용자 | 역할 |
|--------|------|
| BE-seulgi | Backend |
| BE-ejinn | Backend |

### Frontend Group (frontend)
| 사용자 | 역할 |
|--------|------|
| FE-hyogi | Frontend |

### Fullstack (backend + frontend)
| 사용자 | 역할 |
|--------|------|
| FS-siyeon | Fullstack |

### AI Group (AI)
| 사용자 | 역할 |
|--------|------|
| AI-jihyeoniu | AI |
| AI-donghoon | AI |

### Security Group (security)
| 사용자 | 역할 |
|--------|------|
| CS-minwook | Security |
| CS-wanwoo | Security |
| CS-jiseo | Security |

### Infra Group (infra)
| 사용자 | 역할 |
|--------|------|
| CN-7eehy3 | Cloud Native |
| CN-chamchi | Cloud Native |
| CN-wonny | Cloud Native |

---

## CI/CD 서비스 IAM Roles

CI/CD 도구들은 IAM User 대신 **IAM Role**을 사용합니다. Access Key 없이 임시 자격증명으로 동작하여 보안성이 높습니다.

### 1. GitHub Actions (OIDC)

**Role 이름:** `github-actions-role`

**인증 방식:** OpenID Connect (OIDC)

**사용법:**
```yaml
# .github/workflows/example.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/services/github-actions-role
          aws-region: ap-northeast-2

      - run: aws s3 ls  # AWS 명령어 사용 가능
```

**GitHub Secrets 설정:**
- `AWS_ROLE_ARN`: Role ARN 저장

---

### 2. TeamCity (EC2 Instance Profile)

**Role 이름:** `teamcity-role`
**Instance Profile:** `teamcity-instance-profile`

**인증 방식:** EC2 Instance Profile (EC2에서 실행 시 자동 인증)

**사용법:**

EC2 인스턴스 생성 시 Instance Profile 지정:
```hcl
resource "aws_instance" "teamcity" {
  ami                  = "ami-xxxxx"
  instance_type        = "t3.medium"
  iam_instance_profile = "teamcity-instance-profile"
  # ...
}
```

TeamCity에서는 별도 설정 없이 AWS CLI/SDK가 자동으로 자격증명을 획득합니다.

---

### 3. Jenkins (EC2 Instance Profile)

**Role 이름:** `jenkins-role`
**Instance Profile:** `jenkins-instance-profile`

**인증 방식:** EC2 Instance Profile

**사용법:**

TeamCity와 동일하게 EC2 생성 시 Instance Profile 지정:
```hcl
resource "aws_instance" "jenkins" {
  ami                  = "ami-xxxxx"
  instance_type        = "t3.medium"
  iam_instance_profile = "jenkins-instance-profile"
  # ...
}
```

---

### 4. ArgoCD (EKS IRSA)

**Role 이름:** `argocd-role`

**인증 방식:** IAM Roles for Service Accounts (IRSA)

**사전 요구사항:**
- EKS 클러스터에 OIDC Provider 설정 필요
- Terraform variables 설정 필요

**Terraform 설정:**
```hcl
# environments/prod/main.tf 또는 shared/main.tf
module "iam" {
  source = "../../modules/iam"

  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url
}
```

**Kubernetes ServiceAccount 설정:**
```yaml
# argocd-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/services/argocd-role
```

---

## 사용자 추가 방법

### 1. 새 사용자 추가

`modules/iam/users.tf` 파일의 `users_map`에 추가:

```hcl
locals {
  users_map = {
    # 기존 사용자들...

    # 새 사용자 추가
    "BE-newuser" = ["backend"]           # 단일 그룹
    "FS-newuser" = ["backend", "frontend"] # 복수 그룹
  }
}
```

### 2. 새 그룹 추가

`modules/iam/groups.tf` 파일의 `group_config`에 추가:

```hcl
locals {
  group_config = {
    # 기존 그룹들...

    # 새 그룹 추가
    "newgroup" = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    ]
  }
}
```

### 3. 적용

```bash
cd environments/shared  # 또는 해당 환경
terraform plan
terraform apply
```

---

## 보안 주의사항

1. **최소 권한 원칙**: 필요한 권한만 부여
2. **정기 감사**: `security` 그룹이 CloudTrail/SecurityAudit으로 모니터링
3. **Access Key 지양**: CI/CD는 반드시 IAM Role 사용
4. **MFA 권장**: 콘솔 로그인 시 MFA 활성화 권장

---

## 관련 파일

| 파일 | 설명 |
|------|------|
| `modules/iam/groups.tf` | 그룹 및 정책 정의 |
| `modules/iam/users.tf` | 사용자 및 그룹 멤버십 |
| `modules/iam/roles.tf` | CI/CD 서비스 Role |
| `modules/iam/outputs.tf` | 출력값 (Role ARN 등) |
