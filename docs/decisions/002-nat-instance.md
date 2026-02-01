# ADR-002: NAT Instance 사용

## 상태

승인됨

## 컨텍스트

Private Subnet의 리소스가 외부 인터넷에 접근하려면 NAT가 필요하다.
AWS는 NAT Gateway (관리형)와 NAT Instance (EC2) 두 가지 옵션을 제공한다.

## 결정

NAT Gateway 대신 NAT Instance (t3.micro)를 사용한다.

## 비교

| 항목 | NAT Gateway | NAT Instance |
|------|-------------|--------------|
| 월 비용 | ~$45 + 데이터 처리비 | ~$8 |
| 가용성 | 관리형 HA | 단일 인스턴스 |
| 대역폭 | 45Gbps | 인스턴스 의존 |
| 관리 | AWS | 직접 |

## 결과

### 긍정적
- 월 ~$37 절감
- 4개월 ~$150 절감

### 부정적
- 단일 장애점 (SPOF)
- NAT Instance 장애 시 수동 복구 필요

### 위험 완화
- CloudWatch 알림 설정
- 장애 시 빠른 재생성 (Terraform)
- 4개월 프로젝트로 리스크 수용 가능
