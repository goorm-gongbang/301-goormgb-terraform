# GoormGB 운영 가이드 (Runbook)

## 목차

1. [Terraform 사용법](#terraform-사용법)
2. [EKS 운영](#eks-운영)
3. [ECS (AI) 운영](#ecs-ai-운영)
4. [데이터베이스 운영](#데이터베이스-운영)
5. [모니터링](#모니터링)
6. [장애 대응](#장애-대응)
7. [티켓 오픈 대비](#티켓-오픈-대비)

---

## Terraform 사용법

### 초기 설정

```bash
# AWS CLI 설정
aws configure
# Region: ap-northeast-2

# Terraform 버전 확인 (1.5+ 권장)
terraform version
```

### 적용 순서

```bash
# 1. shared (ECR, IAM) - 최초 1회
cd environments/shared
terraform init
terraform plan
terraform apply

# 2. dev (Route53)
cd ../dev
terraform init
terraform apply

# 3. prod (전체 인프라)
cd ../prod
terraform init
terraform plan -out=plan.out
terraform apply plan.out

# 4. AI (dev 또는 prod)
cd ../ai
terraform init
terraform apply -var="environment=dev"   # 또는 prod
```

### 상태 확인

```bash
# 리소스 목록
terraform state list

# 특정 리소스 상세
terraform state show aws_eks_cluster.main
```

### 변경 사항 적용

```bash
# 항상 plan 먼저
terraform plan -out=plan.out

# 변경 내용 확인 후 apply
terraform apply plan.out
```

### 리소스 삭제 (주의!)

```bash
# 특정 리소스만 삭제
terraform destroy -target=aws_instance.nat

# 전체 삭제 (프로젝트 종료 시)
terraform destroy
```

---

## EKS 운영

### kubeconfig 설정

```bash
aws eks update-kubeconfig --name goormgb-prod --region ap-northeast-2
```

### 노드 상태 확인

```bash
# 노드 목록
kubectl get nodes -o wide

# Spot 노드 확인
kubectl get nodes -l 'karpenter.sh/capacity-type=spot'

# 노드 상세 (Spot 종료 예정 확인)
kubectl describe node <node-name>
```

### Pod 상태 확인

```bash
# 전체 Pod
kubectl get pods -A

# 특정 네임스페이스
kubectl get pods -n backend

# Pod 로그
kubectl logs -f <pod-name> -n <namespace>
```

### Karpenter 확인

```bash
# Karpenter 로그
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Provisioner 상태
kubectl get provisioner

# NodePool 상태
kubectl get nodepool
```

### 수동 스케일업 (티켓 오픈 전)

```bash
# Deployment replicas 증가
kubectl scale deployment backend-auth --replicas=10 -n backend

# 또는 HPA 조정
kubectl patch hpa backend-auth -n backend -p '{"spec":{"minReplicas":10}}'
```

---

## ECS (AI) 운영

### 서비스 상태 확인

```bash
# 클러스터 목록
aws ecs list-clusters

# 서비스 상태
aws ecs describe-services \
  --cluster goormgb-ai-prod \
  --services ai-control-plane

# Task 목록
aws ecs list-tasks \
  --cluster goormgb-ai-prod \
  --service-name ai-control-plane
```

### Task 상세 확인

```bash
aws ecs describe-tasks \
  --cluster goormgb-ai-prod \
  --tasks <task-arn>
```

### 로그 확인

```bash
# CloudWatch Logs
aws logs tail /ecs/ai-control-plane --follow

# 또는 AWS 콘솔에서 확인
```

### 수동 배포

```bash
# 강제 새 배포 (이미지 업데이트 후)
aws ecs update-service \
  --cluster goormgb-ai-prod \
  --service ai-control-plane \
  --force-new-deployment
```

### Spot 종료 시 확인

```bash
# Task 종료 이유 확인
aws ecs describe-tasks \
  --cluster goormgb-ai-prod \
  --tasks <task-arn> \
  --query 'tasks[0].stoppedReason'

# "Spot interruption" 이면 정상 (자동 재시작됨)
```

---

## 데이터베이스 운영

### RDS 접속

```bash
# EKS Pod에서 접속
kubectl run -it --rm psql --image=postgres:15 \
  --env="PGPASSWORD=<password>" \
  -- psql -h <rds-endpoint> -U postgres -d goormgb_backend
```

### RDS 상태 확인

```bash
aws rds describe-db-instances \
  --db-instance-identifier goormgb-prod \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address}'
```

### Redis 접속

```bash
# EKS Pod에서 접속
kubectl run -it --rm redis-cli --image=redis:7 \
  -- redis-cli -h <elasticache-endpoint> -p 6379
```

### Redis 대기열 모니터링

```bash
# 대기열 길이 확인
redis-cli LLEN ticket_queue

# 순번 확인
redis-cli ZCARD ticket_order
```

---

## 모니터링

### Grafana 접속

```bash
# port-forward (임시)
kubectl port-forward svc/grafana 3000:80 -n monitoring

# 또는 CloudFront 도메인으로 접속
# https://grafana.goormgb.space
```

### 주요 대시보드

- **EKS Overview**: 노드/Pod 상태
- **Application**: 서비스별 메트릭
- **Redis Queue**: 대기열 모니터링
- **AI Service**: AI 응답 시간/에러율

### 알림 확인

- Slack 채널: #goormgb-alerts
- CloudWatch Alarms: AWS 콘솔

---

## 장애 대응

### Spot 노드 전체 종료 시

```bash
# 1. 노드 상태 확인
kubectl get nodes

# 2. Pending Pod 확인
kubectl get pods -A | grep Pending

# 3. Karpenter 로그 확인 (노드 프로비저닝 중인지)
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# 4. 수동 노드 추가 (긴급 시)
# → Karpenter NodePool 조정 또는 ASG min 증가
```

### ECS Task 시작 실패 시

```bash
# 1. 실패 이유 확인
aws ecs describe-tasks \
  --cluster goormgb-ai-prod \
  --tasks <task-arn> \
  --query 'tasks[0].{Status:lastStatus,Reason:stoppedReason}'

# 2. 일반적인 원인
# - Spot 용량 부족 → 잠시 대기 (자동 재시도)
# - 이미지 pull 실패 → ECR 확인
# - 리소스 부족 → Task 정의 확인
```

### RDS 연결 실패 시

```bash
# 1. RDS 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier goormgb-prod

# 2. Security Group 확인
# - EKS/ECS → RDS 인바운드 허용 여부

# 3. 네트워크 확인 (VPC 내부 통신)
```

### Redis 연결 실패 시

```bash
# 1. ElastiCache 상태 확인
aws elasticache describe-cache-clusters \
  --cache-cluster-id goormgb-prod

# 2. 연결 테스트 (EKS 내부에서)
kubectl run -it --rm redis-test --image=redis:7 \
  -- redis-cli -h <endpoint> ping
```

---

## 티켓 오픈 대비

### 스케일업 자동화 (CronJob)

**왜 필요한가?**
- 100% Spot 환경에서 Karpenter 노드 프로비저닝에 30초-2분 소요
- 티켓 오픈 시 갑작스러운 트래픽 급증 → 이 시간 동안 서비스 지연
- 해결: 오픈 전에 미리 노드를 확보

> ⚠️ 아래 Kubernetes 매니페스트는 Terraform이 아닌 kubectl로 직접 적용해야 합니다.

#### 1. RBAC 설정 (최초 1회)

```yaml
# k8s/scaler-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: scaler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: scaler-role
rules:
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments", "deployments/scale"]
  verbs: ["get", "list", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: scaler-binding
subjects:
- kind: ServiceAccount
  name: scaler
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: scaler-role
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f k8s/scaler-rbac.yaml
```

#### 2. 스케일업/다운 CronJob

```yaml
# k8s/ticket-scaler.yaml
---
# 스케일업 (티켓 오픈 30분 전)
# 예: 매주 금요일 오후 7:30
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ticket-scaleup
  namespace: kube-system
spec:
  schedule: "30 19 * * 5"  # 수정 필요: 티켓 오픈 일정에 맞게
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scaler
          containers:
          - name: scaler
            image: bitnami/kubectl:1.29
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting scale up..."
              kubectl patch hpa backend-queue -n backend -p '{"spec":{"minReplicas":20}}' || true
              kubectl patch hpa backend-seat -n backend -p '{"spec":{"minReplicas":15}}' || true
              kubectl patch hpa backend-auth -n backend -p '{"spec":{"minReplicas":10}}' || true
              kubectl patch hpa backend-order -n backend -p '{"spec":{"minReplicas":10}}' || true
              kubectl patch hpa frontend -n frontend -p '{"spec":{"minReplicas":10}}' || true
              echo "Scale up completed. Waiting for nodes..."
              sleep 180  # 3분 대기 (노드 프로비저닝)
              kubectl get nodes
              kubectl get pods -A | grep -v Running | grep -v Completed || echo "All pods running"
          restartPolicy: OnFailure
---
# 스케일다운 (티켓 오픈 2시간 후)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ticket-scaledown
  namespace: kube-system
spec:
  schedule: "0 22 * * 5"  # 수정 필요: 티켓 오픈 2시간 후
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scaler
          containers:
          - name: scaler
            image: bitnami/kubectl:1.29
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting scale down..."
              kubectl patch hpa backend-queue -n backend -p '{"spec":{"minReplicas":2}}' || true
              kubectl patch hpa backend-seat -n backend -p '{"spec":{"minReplicas":2}}' || true
              kubectl patch hpa backend-auth -n backend -p '{"spec":{"minReplicas":2}}' || true
              kubectl patch hpa backend-order -n backend -p '{"spec":{"minReplicas":2}}' || true
              kubectl patch hpa frontend -n frontend -p '{"spec":{"minReplicas":2}}' || true
              echo "Scale down completed."
          restartPolicy: OnFailure
```

```bash
# CronJob 적용
kubectl apply -f k8s/ticket-scaler.yaml

# CronJob 확인
kubectl get cronjob -n kube-system

# 수동 테스트 (즉시 실행)
kubectl create job --from=cronjob/ticket-scaleup test-scaleup -n kube-system
kubectl logs -f job/test-scaleup -n kube-system
kubectl delete job test-scaleup -n kube-system
```

#### 3. 수동 스케일업 (CronJob 대신 직접 실행)

```bash
# 스케일업
kubectl patch hpa backend-queue -n backend -p '{"spec":{"minReplicas":20}}'
kubectl patch hpa backend-seat -n backend -p '{"spec":{"minReplicas":15}}'
kubectl patch hpa backend-auth -n backend -p '{"spec":{"minReplicas":10}}'
kubectl patch hpa backend-order -n backend -p '{"spec":{"minReplicas":10}}'
kubectl patch hpa frontend -n frontend -p '{"spec":{"minReplicas":10}}'

# 노드 프로비저닝 확인 (2-3분 대기)
kubectl get nodes -w

# 스케일다운
kubectl patch hpa backend-queue -n backend -p '{"spec":{"minReplicas":2}}'
kubectl patch hpa backend-seat -n backend -p '{"spec":{"minReplicas":2}}'
kubectl patch hpa backend-auth -n backend -p '{"spec":{"minReplicas":2}}'
kubectl patch hpa backend-order -n backend -p '{"spec":{"minReplicas":2}}'
kubectl patch hpa frontend -n frontend -p '{"spec":{"minReplicas":2}}'
```

### 체크리스트

#### T-24시간

- [ ] 모니터링 대시보드 확인
- [ ] 최근 배포 이슈 없는지 확인
- [ ] RDS/Redis 상태 확인
- [ ] CronJob 스케줄 확인 (`kubectl get cronjob -n kube-system`)

#### T-30분 (CronJob 자동 실행 또는 수동)

- [ ] 스케일업 완료 확인
- [ ] 노드 프로비저닝 완료 확인 (`kubectl get nodes`)
- [ ] 모든 Pod Running 상태 확인 (`kubectl get pods -A | grep -v Running`)
- [ ] AI 서비스 응답 테스트
- [ ] 대기열 서비스 테스트

#### 오픈 중

- [ ] Grafana 실시간 모니터링
- [ ] Slack 알림 채널 주시
- [ ] 문제 발생 시 즉시 대응

#### 오픈 후 2시간 (CronJob 자동 실행 또는 수동)

- [ ] 스케일다운 완료 확인
- [ ] 로그 분석
- [ ] 이슈 리뷰

---

## 유용한 명령어 모음

### EKS

```bash
# 리소스 사용량
kubectl top nodes
kubectl top pods -A

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp' -A

# Istio 프록시 상태
istioctl proxy-status
```

### AWS CLI

```bash
# 비용 확인 (이번 달)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "BlendedCost"

# ECR 이미지 목록
aws ecr list-images --repository-name goormgb-backend-auth

# Spot 가격 확인
aws ec2 describe-spot-price-history \
  --instance-types m5.large \
  --product-descriptions "Linux/UNIX" \
  --max-items 5
```
