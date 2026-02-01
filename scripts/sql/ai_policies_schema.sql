-- sql/ai_policies_schema.sql
-- AI 정책 테이블 스키마 (매크로 탐지용)

--============================================================================
-- 정책 테이블
--============================================================================

-- 메인 정책 테이블
CREATE TABLE IF NOT EXISTS policies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    policy_type VARCHAR(50) NOT NULL,  -- 'macro_detection', 'risk_scoring', 'captcha'
    rules JSONB NOT NULL,              -- 판별 규칙 (JSON)
    risk_threshold DECIMAL(3,2) DEFAULT 0.7,
    is_active BOOLEAN DEFAULT true,
    priority INT DEFAULT 0,            -- 높을수록 먼저 적용
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 정책 버전 관리 (히스토리)
CREATE TABLE IF NOT EXISTS policy_versions (
    id SERIAL PRIMARY KEY,
    policy_id INT REFERENCES policies(id) ON DELETE CASCADE,
    version INT NOT NULL,
    rules JSONB NOT NULL,
    change_reason TEXT,
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(policy_id, version)
);

--============================================================================
-- 위험도 규칙
--============================================================================

-- 위험도 판별 규칙
CREATE TABLE IF NOT EXISTS risk_rules (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL,    -- 'velocity', 'pattern', 'behavioral', 'device'
    conditions JSONB NOT NULL,          -- 조건 (JSON)
    risk_score DECIMAL(3,2) NOT NULL,   -- 0.0 ~ 1.0
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 예시: 조건 JSON 구조
-- {
--   "type": "velocity",
--   "metric": "clicks_per_second",
--   "operator": "gt",
--   "value": 10,
--   "window_seconds": 5
-- }

--============================================================================
-- 매크로 패턴
--============================================================================

-- 알려진 매크로 패턴
CREATE TABLE IF NOT EXISTS macro_patterns (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    pattern_type VARCHAR(50) NOT NULL,  -- 'click_pattern', 'timing_pattern', 'navigation'
    pattern_data JSONB NOT NULL,        -- 패턴 데이터
    confidence DECIMAL(3,2) DEFAULT 0.8, -- 탐지 신뢰도
    false_positive_rate DECIMAL(5,4),   -- 오탐률
    is_active BOOLEAN DEFAULT true,
    detected_count INT DEFAULT 0,       -- 탐지 횟수
    last_detected_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 예시: 패턴 JSON 구조
-- {
--   "type": "click_interval",
--   "intervals": [100, 100, 100, 100],  -- 정확히 100ms 간격 클릭
--   "tolerance_ms": 5
-- }

--============================================================================
-- 분석 결과 (PostgreSQL에 영구 저장)
--============================================================================

-- 탐지 결과 로그
CREATE TABLE IF NOT EXISTS detection_results (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    detection_type VARCHAR(50) NOT NULL,  -- 'macro', 'bot', 'suspicious'
    risk_score DECIMAL(3,2) NOT NULL,
    matched_rules JSONB,                  -- 매칭된 규칙 ID 목록
    matched_patterns JSONB,               -- 매칭된 패턴 ID 목록
    action_taken VARCHAR(50),             -- 'allow', 'captcha', 'block'
    metadata JSONB,                       -- 추가 메타데이터
    created_at TIMESTAMP DEFAULT NOW()
);

-- VQA 검증 결과 (CAPTCHA 결과)
CREATE TABLE IF NOT EXISTS vqa_verification_results (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    quiz_id VARCHAR(100) NOT NULL,
    is_correct BOOLEAN NOT NULL,
    response_time_ms INT,
    attempt_count INT DEFAULT 1,
    verified_at TIMESTAMP DEFAULT NOW()
);

--============================================================================
-- 인덱스
--============================================================================

-- policies
CREATE INDEX IF NOT EXISTS idx_policies_type ON policies(policy_type);
CREATE INDEX IF NOT EXISTS idx_policies_active ON policies(is_active) WHERE is_active = true;

-- risk_rules
CREATE INDEX IF NOT EXISTS idx_risk_rules_type ON risk_rules(rule_type);
CREATE INDEX IF NOT EXISTS idx_risk_rules_active ON risk_rules(is_active) WHERE is_active = true;

-- macro_patterns
CREATE INDEX IF NOT EXISTS idx_macro_patterns_type ON macro_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_macro_patterns_active ON macro_patterns(is_active) WHERE is_active = true;

-- detection_results
CREATE INDEX IF NOT EXISTS idx_detection_results_session ON detection_results(session_id);
CREATE INDEX IF NOT EXISTS idx_detection_results_user ON detection_results(user_id);
CREATE INDEX IF NOT EXISTS idx_detection_results_created ON detection_results(created_at);
CREATE INDEX IF NOT EXISTS idx_detection_results_type ON detection_results(detection_type);

-- vqa_verification_results
CREATE INDEX IF NOT EXISTS idx_vqa_results_session ON vqa_verification_results(session_id);
CREATE INDEX IF NOT EXISTS idx_vqa_results_user ON vqa_verification_results(user_id);

--============================================================================
-- 트리거: updated_at 자동 갱신
--============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_policies_updated_at ON policies;
CREATE TRIGGER update_policies_updated_at
    BEFORE UPDATE ON policies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_risk_rules_updated_at ON risk_rules;
CREATE TRIGGER update_risk_rules_updated_at
    BEFORE UPDATE ON risk_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_macro_patterns_updated_at ON macro_patterns;
CREATE TRIGGER update_macro_patterns_updated_at
    BEFORE UPDATE ON macro_patterns
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

--============================================================================
-- 초기 데이터 (예시)
--============================================================================

-- 기본 정책
INSERT INTO policies (name, description, policy_type, rules, risk_threshold, priority)
VALUES
    ('default_macro_detection', '기본 매크로 탐지 정책', 'macro_detection',
     '{"enabled": true, "sensitivity": "medium", "actions": ["log", "captcha"]}',
     0.7, 100),
    ('high_security_mode', '티켓 오픈 시 고보안 모드', 'macro_detection',
     '{"enabled": true, "sensitivity": "high", "actions": ["captcha", "block"]}',
     0.5, 200)
ON CONFLICT (name) DO NOTHING;

-- 기본 위험도 규칙
INSERT INTO risk_rules (name, description, rule_type, conditions, risk_score)
VALUES
    ('fast_clicks', '비정상적으로 빠른 클릭', 'velocity',
     '{"metric": "clicks_per_second", "operator": "gt", "value": 10, "window_seconds": 5}',
     0.8),
    ('regular_intervals', '일정한 클릭 간격 (봇 의심)', 'pattern',
     '{"metric": "click_interval_std", "operator": "lt", "value": 10, "min_clicks": 5}',
     0.9),
    ('impossible_speed', '인간 불가능한 반응 속도', 'behavioral',
     '{"metric": "reaction_time_ms", "operator": "lt", "value": 50}',
     1.0)
ON CONFLICT (name) DO NOTHING;

-- 기본 매크로 패턴
INSERT INTO macro_patterns (name, description, pattern_type, pattern_data, confidence)
VALUES
    ('perfect_timing', '완벽한 타이밍 패턴', 'timing_pattern',
     '{"interval_ms": 100, "tolerance_ms": 5, "min_occurrences": 5}',
     0.95),
    ('linear_mouse', '직선 마우스 이동', 'navigation',
     '{"path_type": "linear", "deviation_threshold": 0.01}',
     0.85)
ON CONFLICT (name) DO NOTHING;
