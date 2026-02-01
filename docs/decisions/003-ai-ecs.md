# ADR-003: AI 서비스 ECS Fargate 분리

## 상태

승인됨

## 컨텍스트

AI 서비스는 봇 방어/퀴즈 검증 API로, Backend/Frontend와 독립적으로 운영된다.
AI 팀이 독립적으로 배포하고 관리할 수 있어야 한다.

## 결정

AI 서비스를 EKS가 아닌 ECS Fargate로 분리 배포한다.

## 이유

1. **AI 팀 독립성**: K8s 지식 없이 운영 가능
2. **간단한 구조**: GPU 불필요, 단순 API 서버
3. **별도 스케일링**: EKS 트래픽과 무관
4. **CI/CD 분리**: GitHub Actions로 독립 파이프라인

## 결과

### 긍정적
- AI 팀 독립적 운영/배포
- EKS 복잡성 회피
- 장애 격리

### 부정적
- ArgoCD GitOps 미적용 (ECS는 K8s 아님)
- 서비스 메시 (Istio) 미적용

### 대안
- AI도 EKS에 배포: ArgoCD 통합 가능하지만 AI팀 K8s 학습 필요
- 현재 결정 유지: 4개월 프로젝트, 단순함 우선

## CI/CD

- **Backend/Frontend**: TeamCity → ArgoCD (GitOps)
- **AI**: GitHub Actions → ECS update-service
