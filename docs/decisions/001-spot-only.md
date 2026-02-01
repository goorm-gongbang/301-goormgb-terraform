# ADR-001: 100% Spot Instance 사용

## 상태

승인됨

## 컨텍스트

4개월 프로젝트로 비용 최적화가 중요하며, 티켓팅 플랫폼 특성상 트래픽이 일시적으로 급증한다.

## 결정

EKS 노드와 ECS Fargate 모두 100% Spot으로 운영한다.

### EKS
- Karpenter로 Spot 노드 관리
- 인스턴스 타입 혼합 (m5, m5a, m6i, c5)
- 여러 AZ 분산으로 동시 회수 확률 감소

### ECS Fargate
- Fargate Spot 사용
- prod: 2개 Task (AZ 분산)로 HA 확보
- dev: 1개 Task

## 결과

### 긍정적
- 비용 60-70% 절감 (월 ~$350)
- 4개월 총 ~$1,400 절감 예상

### 부정적
- Spot 회수 시 일시적 서비스 영향
- 티켓 오픈 시 수동 스케일업 필요

### 위험 완화
- 모든 Pod replicas >= 2
- PodDisruptionBudget 설정
- Karpenter spot interruption handling
- 티켓 오픈 30분 전 수동 스케일업
