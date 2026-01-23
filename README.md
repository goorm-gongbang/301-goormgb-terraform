# 프로젝트 구조
대충 이런식으로 간다는 정도고 완전 동일은 아님..
```
my-project-terraform/
├── backend.tf          # State 파일 저장소 설정 (S3)
├── provider.tf         # AWS Provider 및 버전 설정
├── main.tf             # [핵심] 모듈들을 조립하는 곳 (여기가 Prod 설계도)
├── variables.tf        # 프로젝트 전역 변수 (리전, 프로젝트명 등)
├── outputs.tf          # 최종적으로 출력할 정보 (예: 로드밸런서 DNS 주소)
├── terraform.tfvars    # (옵션) 실제 변수값 입력 파일 (Git 제외 필수!)
├── .gitignore          # .terraform, .tfstate 등 제외 설정
│
└── modules/            # 재사용 가능한 리소스 묶음
    ├── network/        # VPC, Subnet, G/W
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── iam/            # IAM User, Group, Policy (아까 질문하신 부분)
    │   ├── ...
    ├── eks/            # (또는 compute) EKS, Node Group
    │   ├── ...
    └── database/       # RDS, ElastiCache
        ├── ...
```