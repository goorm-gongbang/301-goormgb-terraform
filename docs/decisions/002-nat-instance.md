# ADR-002: NAT Instance 사용 (고가용성)

## 상태

승인됨 (업데이트됨)

## 컨텍스트

Private Subnet의 리소스가 외부 인터넷에 접근하려면 NAT가 필요하다.
AWS는 NAT Gateway (관리형)와 NAT Instance (EC2) 두 가지 옵션을 제공한다.

## 결정

NAT Gateway 대신 NAT Instance (t3.micro) × 2개를 사용한다.
각 AZ에 1개씩 배치하여 고가용성을 확보한다.

## 비교

| 항목 | NAT Gateway × 2 | NAT Instance × 2 |
|------|-----------------|------------------|
| 월 비용 | ~$90 + 데이터 처리비 | ~$16 |
| 가용성 | 관리형 HA | AZ별 1개 (HA) |
| 대역폭 | 45Gbps | 인스턴스 의존 |
| 관리 | AWS | 직접 |

## 구성

```
VPC
├── AZ-a
│   ├── Public Subnet
│   │   └── NAT Instance #1
│   ├── Private Subnet
│   │   └── Route Table → NAT Instance #1
│   └── Database Subnet
│       └── Route Table → NAT Instance #1
│
└── AZ-c
    ├── Public Subnet
    │   └── NAT Instance #2
    ├── Private Subnet
    │   └── Route Table → NAT Instance #2
    └── Database Subnet
        └── Route Table → NAT Instance #2
```

## 결과

### 긍정적
- 월 ~$74 절감 (NAT Gateway 대비)
- 4개월 ~$300 절감
- AZ 장애 시에도 다른 AZ는 정상 작동 (HA)

### 부정적
- 직접 관리 필요
- NAT Instance 장애 시 해당 AZ만 영향

### 위험 완화
- 각 AZ에 NAT Instance 배치로 SPOF 제거
- CloudWatch 알림 설정
- 장애 시 빠른 재생성 (Terraform)
