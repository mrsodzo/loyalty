# План реализации: Rewards Platform

**Версия:** 1.0  
**Дата:** 2026-02-24  
**Статус:** Черновик для рассмотрения

---

## A. Фазы разработки (Phases)

### A.1 Обзор фаз

| Phase | Название | Описание | Продолжительность |
|-------|----------|----------|-------------------|
| 0 | Foundation | Инфраструктура, CI/CD, базовые настройки | 4 недели |
| 1 | Core Services | Ingestion, Eligibility, Calculation | 8 недель |
| 2 | Risk/Fraud & Fulfillment | Risk/Fraud сервис + Fulfillment | 6 недель |
| 3 | Explainability & Audit | Explainability Agent, Audit Agent, Ops Assistant | 4 недели |
| 4 | Optional Services | Personalization, Sponsor Relationship, Policy | 4 недели (опционально) |
| 5 | Channels | Subscriber App, Sponsor App, Admin Portal | 6 недель |
| 6 | Integration & Testing | Интеграция с внешними системами, E2E тесты | 4 недели |
| 7 | Production Readiness | Performance tests, Security hardening, Go-live | 3 недели |

### A.2 Детальное описание фаз

#### Phase 0: Foundation (Недели 1-4)

- Настройка Kubernetes кластера
- Конфигурация CI/CD pipeline (GitLab CI / GitHub Actions)
- Настройка PostgreSQL, Redis, Kafka
- Настройка мониторинга (Prometheus, Grafana, Loki, Jaeger)
- Настройка центрального логирования
- Конфигурация окружений (dev, staging, prod)
- Создание базовых Docker образов
- Настройка API Gateway (Kong / Spring Cloud Gateway)
- Настройка Vault для secrets management
- Настройка сетевых политик в K8s

#### Phase 1: Core Services (Недели 5-12)

- **Ingestion Service:** Нормализация событий, дедупликация, обогащение
- **Eligibility Service:** Rule engine, сегментация, проверка условий
- **Rewards Calculation:** Начисления, списания, промо-кампании
- Базовая интеграция с Kafka
- Redis кэширование для правил

#### Phase 2: Risk/Fraud & Fulfillment (Недели 13-18)

- **Risk/Fraud Service:** Риск-скоринг, anomaly detection, rate limits
- **Fulfillment Service:** Интеграция с провайдерами, идемпотентность
- Circuit breaker паттерн
- Retry логика с exponential backoff

#### Phase 3: Explainability, Audit & Admin Assistant (Недели 19-22)

- **Explainability Agent:** Генерация объяснений решений
- **Audit Agent:** Полный аудит-трейл всех действий
- **Ops/Admin Assistant:** AI-помощник для операторов

#### Phase 4: Optional Services (Недели 23-26)

- **Personalization Service:** Next best action
- **Sponsor Relationship Service:** Граф связей спонсор-подписчик
- **Policy Service:** Централизованные политики compliance

#### Phase 5: Channels (Недели 27-32)

- **Subscriber App:** Мобильное приложение для абонентов
- **Sponsor/Parent App:** Приложение для спонсоров
- **Admin Portal:** Веб-портал для администраторов

#### Phase 6: Integration & Testing (Недели 33-36)

- Интеграция с BSS/OSS
- Интеграция с EdTech VAS
- E2E тестирование всех сценариев
- Contract тесты между сервисами

#### Phase 7: Production Readiness (Недели 37-39)

- Performance & Load testing
- Security hardening
- Chaos engineering
- Blue-green / Canary deployment
- Go-live

---

## B. Детальный план по сервисам (Service Breakdown)

### B.1 Обязательные сервисы (7 штук)

#### B.1.1 Ingestion Service

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| Библиотеки | Spring Kafka, Jackson, Validation |
| База данных | PostgreSQL (events), Redis (dedup cache) |
| Message Broker | Apache Kafka |

**Ключевые компоненты:**
- Event normalizer — нормализация входящих событий
- Deduplication engine — дедупликация через Bloom filter + Redis
- Event enricher — обогащение метаданными
- Schema validator — валидация по JSON Schema

**API Endpoints:**
```
POST /api/v1/events — Одиночное событие
POST /api/v1/events/batch — Пакетный приём
GET  /api/v1/events/{eventId}/status — Статус обработки
GET  /api/v1/health — Health check
```

**Data Models:**
```sql
-- events table
CREATE TABLE events (
    event_id UUID PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    metadata JSONB,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);

-- processed_events (dedup)
CREATE TABLE processed_events (
    event_id UUID PRIMARY KEY,
    dedup_key VARCHAR(255),
    processed_at TIMESTAMP DEFAULT NOW()
);
```

**Зависимости:**
- Kafka (outbound events)
- Redis (deduplication cache)
- PostgreSQL (events storage)

**План разработки:**
1. Настройка проекта и базовой конфигурации
2. Реализация модели событий и JSON Schema
3. Реализация нормализатора событий
4. Реализация дедупликации (Bloom filter + Redis)
5. Реализация REST API endpoints
6. Интеграция с Kafka producer
7. Unit тесты
8. Integration тесты

**Оценка сложности:** 13 story points (3-4 недели)

---

#### B.1.2 Eligibility Service

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| Библиотеки | Spring Data JPA, QueryDSL, Redis |
| База данных | PostgreSQL (rules, segments) |
| Кэш | Redis |

**Ключевые компоненты:**
- Rule engine — движок правил
- Segment resolver — определение сегментов пользователя
- Eligibility calculator — расчёт права на награду

**API Endpoints:**
```
POST /api/v1/eligibility/check — Проверка права на награду
GET  /api/v1/eligibility/rules — Список правил
POST /api/v1/eligibility/rules — Создание правила
PUT  /api/v1/eligibility/rules/{id} — Обновление правила
DELETE /api/v1/eligibility/rules/{id} — Удаление правила
GET  /api/v1/eligibility/segments — Список сегментов
```

**Data Models:**
```sql
-- loyalty_rules table
CREATE TABLE loyalty_rules (
    rule_id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    conditions JSONB NOT NULL,
    reward_type VARCHAR(50) NOT NULL,
    reward_value JSONB NOT NULL,
    priority INT DEFAULT 0,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP
);

-- segments table
CREATE TABLE segments (
    segment_id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    criteria JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- user_segments (mapping)
CREATE TABLE user_segments (
    user_id UUID NOT NULL,
    segment_id UUID NOT NULL,
    assigned_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, segment_id)
);
```

**Зависимости:**
- Kafka (потребление нормализованных событий)
- Redis (кэширование правил)
- PostgreSQL (хранение правил)

**План разработки:**
1. Настройка проекта и зависимостей
2. Реализация модели данных правил
3. Реализация Rule engine (conditions evaluation)
4. Реализация Segment resolver
5. REST API для управления правилами
6. Eligibility check endpoint
7. Redis кэширование правил
8. Unit тесты
9. Integration тесты

**Оценка сложности:** 21 story point (4-5 недель)

---

#### B.1.3 Risk/Fraud Service

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| Библиотеки | Spring ML (если используем), RuleEngine |
| База данных | PostgreSQL (risk profiles, alerts) |
| AI | LLM integration (external) |

**Ключевые компоненты:**
- Risk scorer — ML-based скоринг
- Anomaly detector — обнаружение аномалий
- Rate limiter — проверка лимитов
- Step-up verifier — дополнительная верификация

**API Endpoints:**
```
POST /api/v1/risk/score — Риск-скоринг транзакции
POST /api/v1/risk/verify — Проверка верификации
GET  /api/v1/risk/alerts — Список алертов
POST /api/v1/risk/decision — Получить решение (allow/deny/step-up)
```

**Data Models:**
```sql
-- risk_profiles table
CREATE TABLE risk_profiles (
    user_id UUID PRIMARY KEY,
    risk_score DECIMAL(5,2) DEFAULT 0,
    last_check TIMESTAMP,
    flags JSONB,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- risk_alerts table
CREATE TABLE risk_alerts (
    alert_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    details JSONB,
    resolved BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- velocity_checks table
CREATE TABLE velocity_checks (
    check_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    check_type VARCHAR(50) NOT NULL,
    count INT DEFAULT 0,
    window_start TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Зависимости:**
- Kafka
- PostgreSQL
- AI Gateway (для LLM-основанного скоринга)
- Redis (rate limiting)

**План разработки:**
1. Настройка проекта
2. Реализация risk profiles БД
3. Реализация базового rule-based скоринга
4. Реализация velocity/rate limiting
5. Интеграция с AI Gateway (Risk Subagent)
6. Step-up verification логика
7. REST API endpoints
8. Alert management
9. Unit и integration тесты

**Оценка сложности:** 34 story points (6-7 недель)

---

#### B.1.4 Rewards Calculation Service

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| Библиотеки | Spring Data JPA, Redis |
| База данных | PostgreSQL (rewards, transactions) |
| Кэш | Redis (балансы) |

**Ключевые компоненты:**
- Reward calculator — расчёт наград
- Promo engine — применение промо-акций
- Balance manager — управление балансами
- Transaction ledger — журнал транзакций

**API Endpoints:**
```
POST /api/v1/rewards/calculate — Расчёт награды
POST /api/v1/rewards/apply — Применение награды
GET  /api/v1/rewards/balance/{userId} — Получить баланс
POST /api/v1/rewards/reverse — Отмена награды
GET  /api/v1/rewards/history/{userId} — История наград
```

**Data Models:**
```sql
-- rewards table
CREATE TABLE rewards (
    reward_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    event_id UUID,
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'VIRTUAL_RUB',
    status VARCHAR(20) DEFAULT 'PENDING',
    ttl TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    applied_at TIMESTAMP
);

-- accounts (Rewards Bank Account)
CREATE TABLE accounts (
    account_id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(15,2) DEFAULT 0,
    currency VARCHAR(10) DEFAULT 'VIRTUAL_RUB',
    kyc_level VARCHAR(20) DEFAULT 'BASIC',
    daily_payout_limit DECIMAL(15,2) DEFAULT 1000,
    monthly_payout_limit DECIMAL(15,2) DEFAULT 5000,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP
);

-- transactions (Ledger)
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY,
    account_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    reference_id UUID,
    reference_type VARCHAR(50),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- promo_campaigns table
CREATE TABLE promo_campaigns (
    campaign_id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    conditions JSONB NOT NULL,
    reward_modifier JSONB NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Зависимости:**
- Kafka
- PostgreSQL
- Redis (балансы)
- Eligibility Service
- Risk/Fraud Service

**План разработки:**
1. Настройка проекта
2. Реализация Account модели
3. Реализация Reward модели
4. Реализация Transaction ledger
5. Balance manager (credit/debit)
6. Promo engine
7. REST API endpoints
8. Redis синхронизация балансов
9. Unit и integration тесты

**Оценка сложности:** 34 story points (6-7 недель)

---

#### B.1.5 Fulfillment Service

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| Библиотеки | Spring WebFlux (resilient), Resilience4j |
| База данных | PostgreSQL (fulfillment requests) |
| External | Reward Providers API |

**Ключевые компоненты:**
- Provider connector — коннектор к провайдерам
- Idempotency manager — обеспечение идемпотентности
- Retry handler — обработка повторных попыток
- Webhook handler — обработка callback от провайдеров

**API Endpoints:**
```
POST /api/v1/fulfillment/create — Создание запроса на выдачу
POST /api/v1/fulfillment/redeem — Использование награды
POST /api/v1/fulfillment/cancel — Отмена
GET  /api/v1/fulfillment/status/{requestId} — Статус
POST /api/v1/fulfillment/webhook — Webhook от провайдера
```

**Data Models:**
```sql
-- fulfillment_requests table
CREATE TABLE fulfillment_requests (
    request_id UUID PRIMARY KEY,
    reward_id UUID NOT NULL,
    user_id UUID NOT NULL,
    provider_id VARCHAR(100) NOT NULL,
    provider_reference VARCHAR(255),
    status VARCHAR(20) DEFAULT 'PENDING',
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2),
    destination JSONB,
    response JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP,
    fulfilled_at TIMESTAMP
);

-- provider_configs table
CREATE TABLE provider_configs (
    provider_id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    api_endpoint VARCHAR(500) NOT NULL,
    auth_config JSONB NOT NULL,
    timeout_connect INT DEFAULT 5000,
    timeout_read INT DEFAULT 30000,
    rate_limit INT DEFAULT 100,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- fulfillment_idempotency table
CREATE TABLE fulfillment_idempotency (
    idempotency_key VARCHAR(255) PRIMARY KEY,
    request_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Зависимости:**
- Kafka
- PostgreSQL
- External Reward Providers
- Rewards Calculation Service

**План разработки:**
1. Настройка проекта
2. Реализация Provider connector
3. Реализация Idempotency manager
4. Circuit breaker integration
5. Retry logic (exponential backoff)
6. Webhook handler
7. REST API endpoints
8. Unit и integration тесты

**Оценка сложности:** 21 story point (4-5 недель)

---

#### B.1.6 Explainability & Audit Agent

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| AI | LLM integration |
| База данных | PostgreSQL (audit logs, explanations) |

**Ключевые компоненты:**
- Decision explainer — генерация объяснений
- Audit logger — журналирование действий
- Query interface — интерфейс запросов к аудиту

**API Endpoints:**
```
GET  /api/v1/explain/decision/{decisionId} — Объяснение решения
GET  /api/v1/audit/logs — Список аудит логов
POST /api/v1/audit/query — Запрос к аудиту
GET  /api/v1/audit/export — Экспорт логов
```

**Data Models:**
```sql
-- audit_logs table
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    actor_id UUID,
    actor_role VARCHAR(50),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    correlation_id UUID,
    metadata JSONB
);

-- decisions table
CREATE TABLE decisions (
    decision_id UUID PRIMARY KEY,
    decision_type VARCHAR(50) NOT NULL,
    user_id UUID NOT NULL,
    context JSONB NOT NULL,
    result JSONB NOT NULL,
    explanation JSONB,
    risk_factors JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- explanations table
CREATE TABLE explanations (
    explanation_id UUID PRIMARY KEY,
    decision_id UUID NOT NULL,
    level VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Зависимости:**
- Все сервисы (для получения контекста)
- PostgreSQL

**План разработки:**
1. Настройка проекта
2. Реализация Audit logger
3. Реализация Decision storage
4. Интеграция с Explainability Agent (LLM)
5. Query interface для аудита
6. REST API endpoints
7. Unit тесты

**Оценка сложности:** 21 story point (4-5 недель)

---

#### B.1.7 Ops/Admin Assistant Agent

| Параметр | Значение |
|----------|----------|
| Язык | Java 17 / Kotlin |
| Фреймворк | Spring Boot 3.x |
| AI | LLM integration |
| База данных | PostgreSQL |

**Ключевые компоненты:**
- Query assistant — помощь с запросами
- Alert triage — сортировка алертов
- Data summarizer — суммаризация данных

**API Endpoints:**
```
POST /api/v1/assistant/query — Запрос к ассистенту
GET  /api/v1/assistant/recommendations — Рекомендации
GET  /api/v1/assistant/alerts — Сортировка алертов
```

**План разработки:**
1. Настройка проекта
2. Интеграция с LLM
3. Guardrails implementation
4. Query assistant
5. REST API endpoints

**Оценка сложности:** 13 story points (3-4 недели)

---

### B.2 Сводка по сервисам

| Сервис | Язык | Фреймворк | Story Points | Зависимости |
|--------|------|----------|--------------|------------|
| Ingestion | Java 17/Kotlin | Spring Boot | 13 | Kafka, Redis, PostgreSQL |
| Eligibility | Java 17/Kotlin | Spring Boot | 21 | Kafka, Redis, PostgreSQL |
| Risk/Fraud | Java 17/Kotlin | Spring Boot | 34 | Kafka, PostgreSQL, AI Gateway |
| Rewards Calculation | Java 17/Kotlin | Spring Boot | 34 | Kafka, PostgreSQL, Redis |
| Fulfillment | Java 17/Kotlin | Spring Boot | 21 | Kafka, PostgreSQL, External APIs |
| Explainability & Audit | Java 17/Kotlin | Spring Boot | 21 | PostgreSQL, AI Gateway |
| Ops Assistant | Java 17/Kotlin | Spring Boot | 13 | PostgreSQL, AI Gateway |

**Total Core Services:** 157 story points (~32 недели)

---

## C. План интеграций (Integration Plan)

### C.1 Reward Providers

#### C.1.1 Шаблон интеграции

```
┌─────────────────────────────────────────────────────────────┐
│              REWARD PROVIDER INTEGRATION                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ Fulfillment │───▶│   Circuit   │───▶│   Provider   │  │
│  │   Service    │    │   Breaker   │    │   Client     │  │
│  └─────────────┘    └─────────────┘    └──────┬──────┘  │
│                                                │           │
│                                                ▼           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Retry     │◀───│   Provider  │◀───│   HTTP      │  │
│  │   Logic     │    │   Response  │    │   Call      │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### C.1.2 API интерфейс провайдера

```yaml
openapi: 3.0.0
info:
  title: Reward Provider API
  version: 1.0.0

paths:
  /create:
    post:
      operationId: createReward
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                userId:
                  type: string
                rewardType:
                  type: string
                  enum: [POINTS, VOUCHER, CASHBACK]
                amount:
                  type: number
                metadata:
                  type: object
      responses:
        '200':
          description: Reward created
          content:
            application/json:
              schema:
                type: object
                properties:
                  rewardId:
                    type: string
                  status:
                    type: string

  /redeem:
    post:
      operationId: redeemReward
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                rewardId:
                  type: string
                destination:
                  type: object
      responses:
        '200':
          description: Reward redeemed

  /status:
    get:
      operationId: getStatus
      parameters:
        - name: rewardId
          in: query
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Status retrieved
```

#### C.1.3 Моки для разработки

```java
// MockRewardProviderClient.java
@Component
public class MockRewardProviderClient implements RewardProviderClient {
    
    @Override
    public CreateRewardResponse createReward(CreateRewardRequest request) {
        // Локальная симуляция для dev/staging
        return CreateRewardResponse.builder()
            .rewardId(UUID.randomUUID().toString())
            .status("SUCCESS")
            .build();
    }
    
    @Override
    public RedeemRewardResponse redeemReward(RedeemRewardRequest request) {
        return RedeemRewardResponse.builder()
            .status("SUCCESS")
            .build();
    }
}
```

---

### C.2 Payment Gateway

#### C.2.1 Интеграция

```
┌─────────────────────────────────────────────────────────────┐
│            PAYMENT GATEWAY INTEGRATION                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  Rewards    │───▶│  Payment    │───▶│  External   │  │
│  │  Service    │    │  Gateway    │    │  Bank       │  │
│  └─────────────┘    │   Client    │    │             │  │
│                     └──────┬──────┘    └──────┬──────┘  │
│                            │                   │          │
│                            ▼                   ▼          │
│                     ┌─────────────┐    ┌─────────────┐  │
│                     │   3DS/SCA   │    │  Webhook    │  │
│                     │  Handler    │    │  Callback   │  │
│                     └─────────────┘    └─────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### C.2.2 Тестовый режим

| Режим | Описание | Использование |
|-------|----------|---------------|
| Mock | Локальная симуляция | Development |
| Sandbox | Тестовый API шлюза | Integration testing |
| Production | Реальный шлюз | Production |

---

### C.3 Kafka Topics и схемы событий

#### C.3.1 Topics

| Topic | Partitions | Retention | Описание |
|-------|------------|-----------|----------|
| `rewards.events.raw` | 12 | 7 days | Сырые события |
| `rewards.events.normalized` | 12 | 14 days | Нормализованные события |
| `rewards.eligibility` | 12 | 14 days | События на проверку eligibility |
| `rewards.risk` | 12 | 14 days | События на проверку рисков |
| `rewards.calculated` | 12 | 30 days | Рассчитанные награды |
| `rewards.fulfillment` | 12 | 30 days | Fulfillment запросы |
| `rewards.webhooks` | 6 | 7 days | Webhook события |
| `rewards.audit` | 3 | 90 days | Аудит логи |

#### C.3.2 Event Schemas (Avro)

```avro
// NormalizedEvent
{
  "type": "record",
  "name": "NormalizedEvent",
  "fields": [
    {"name": "event_id", "type": "string"},
    {"name": "event_name", "type": "string"},
    {"name": "source_system", "type": "string"},
    {"name": "timestamp", "type": {"type": "long", "logicalType": "timestamp-millis"}},
    {"name": "user_id", "type": "string"},
    {"name": "payload", "type": {"type": "map", "values": "string"}},
    {"name": "correlation_id", "type": "string"}
  ]
}

// RewardCalculated
{
  "type": "record",
  "name": "RewardCalculated",
  "fields": [
    {"name": "reward_id", "type": "string"},
    {"name": "user_id", "type": "string"},
    {"name": "event_id", "type": "string"},
    {"name": "type", "type": "string"},
    {"name": "amount", "type": {"type": "decimal", "precision": 15, "scale": 2}},
    {"name": "status", "type": "string"}
  ]
}
```

---

### C.4 Контракты API между сервисами

#### C.4.1 Ingestion → Eligibility

```json
// Kafka message: rewards.eligibility
{
  "event_id": "uuid",
  "event_name": "subscription.activated",
  "user_id": "uuid",
  "payload": {},
  "correlation_id": "uuid",
  "timestamp": "2026-02-24T10:00:00Z"
}
```

#### C.4.2 Eligibility → Risk/Fraud

```json
// Kafka message: rewards.risk
{
  "eligibility_request_id": "uuid",
  "user_id": "uuid",
  "event_id": "uuid",
  "matched_rules": ["rule_1", "rule_2"],
  "calculated_reward": {
    "type": "POINTS",
    "amount": 100
  },
  "correlation_id": "uuid"
}
```

#### C.4.3 Risk/Fraud → Rewards Calculation

```json
// Kafka message: rewards.calculated
{
  "request_id": "uuid",
  "user_id": "uuid",
  "event_id": "uuid",
  "decision": "ALLOW",
  "risk_score": 15.5,
  "reward": {
    "type": "POINTS",
    "amount": 100
  },
  "correlation_id": "uuid"
}
```

---

## D. План данных (Data Strategy)

### D.1 Схемы баз данных (PostgreSQL)

#### D.1.1 Общая архитектура БД

```
┌─────────────────────────────────────────────────────────────┐
│              DATABASE ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │  Ingestion  │  │ Eligibility │  │    Risk     │      │
│  │   Service   │  │   Service   │  │  Fraud Svc  │      │
│  │   Database   │  │   Database  │  │  Database   │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│        │                │                 │                 │
│        └────────────────┼─────────────────┘                 │
│                         │                                    │
│                    ┌────▼────┐                               │
│                    │ Shared  │                               │
│                    │ Tables  │                               │
│                    └────┬────┘                               │
│                         │                                    │
│        ┌────────────────┼─────────────────┐                 │
│        │                │                 │                 │
│  ┌────▼────┐     ┌────▼────┐     ┌────▼────┐              │
│  │ Rewards  │     │Fulfillment│    │  Audit  │              │
│  │ Service  │     │  Service  │    │  Agent  │              │
│  │ Database │     │  Database │    │ Database│              │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### D.1.2 Shared tables

```sql
-- accounts (Rewards Bank Account)
CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'VIRTUAL_RUB',
    kyc_level VARCHAR(20) NOT NULL DEFAULT 'BASIC',
    daily_payout_limit DECIMAL(15,2) NOT NULL DEFAULT 1000,
    monthly_payout_limit DECIMAL(15,2) NOT NULL DEFAULT 5000,
    daily_payout_used DECIMAL(15,2) NOT NULL DEFAULT 0,
    monthly_payout_used DECIMAL(15,2) NOT NULL DEFAULT 0,
    last_reset_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_accounts_user_id ON accounts(user_id);

-- transactions (Ledger)
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(account_id),
    type VARCHAR(20) NOT NULL CHECK (type IN ('CREDIT', 'DEBIT', 'REVERSE', 'PAYOUT', 'REFUND')),
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    reference_id UUID,
    reference_type VARCHAR(50),
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
CREATE INDEX idx_transactions_reference ON transactions(reference_id, reference_type);
```

#### D.1.3 Service-specific схемы

| Сервис | Схема | Основные таблицы |
|--------|-------|------------------|
| Ingestion | `ingestion` | events, processed_events |
| Eligibility | `eligibility` | loyalty_rules, segments, user_segments |
| Risk/Fraud | `risk` | risk_profiles, risk_alerts, velocity_checks |
| Rewards | `rewards` | rewards, promo_campaigns |
| Fulfillment | `fulfillment` | fulfillment_requests, provider_configs, fulfillment_idempotency |
| Audit | `audit` | audit_logs, decisions, explanations |

---

### D.2 Миграции (Flyway)

#### D.2.1 Структура миграций

```
src/main/resources/db/migration/
├── V1__Initial_schema.sql
├── V2__Create_ingestion_schema.sql
├── V3__Create_eligibility_schema.sql
├── V4__Create_risk_schema.sql
├── V5__Create_rewards_schema.sql
├── V6__Create_fulfillment_schema.sql
├── V7__Create_audit_schema.sql
└── V8__Seed_data.sql
```

#### D.2.2 Пример миграции

```sql
-- V1__Initial_schema.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Shared tables
CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    currency VARCHAR(10) NOT NULL DEFAULT 'VIRTUAL_RUB',
    kyc_level VARCHAR(20) NOT NULL DEFAULT 'BASIC',
    daily_payout_limit DECIMAL(15,2) NOT NULL DEFAULT 1000,
    monthly_payout_limit DECIMAL(15,2) NOT NULL DEFAULT 5000,
    daily_payout_used DECIMAL(15,2) NOT NULL DEFAULT 0,
    monthly_payout_used DECIMAL(15,2) NOT NULL DEFAULT 0,
    last_reset_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(account_id),
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    reference_id UUID,
    reference_type VARCHAR(50),
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
```

---

### D.3 Seed Data

#### D.3.1 Правила лояльности (MVP)

```sql
-- Loyalty Rules
INSERT INTO eligibility.loyalty_rules (rule_id, name, event_type, conditions, reward_type, reward_value, priority, active)
VALUES 
    (gen_random_uuid(), 'New Subscriber Bonus', 'subscription.activated', 
     '{"operator": "AND", "conditions": []}', 
     'POINTS', '{"fixed": 100}', 100, true),
    
    (gen_random_uuid(), 'Recharge Cashback', 'subscription.recharged',
     '{"operator": "AND", "conditions": [{"field": "amount", "operator": "gte", "value": 100}]}',
     'CASHBACK', '{"percentage": 5, "max": 500}', 50, true),
    
    (gen_random_uuid(), 'Package Purchase Bonus', 'package.purchased',
     '{"operator": "AND", "conditions": []}',
     'POINTS', '{"fixed": 50}', 50, true),
    
    (gen_random_uuid(), 'Learning Activity Reward', 'learning.activity.completed',
     '{"operator": "AND", "conditions": []}',
     'POINTS', '{"fixed": 10}', 30, true);
```

#### D.3.2 Сегменты

```sql
-- Segments
INSERT INTO eligibility.segments (segment_id, name, criteria)
VALUES 
    (gen_random_uuid(), 'Premium Users', '{"operator": "AND", "conditions": [{"field": "plan", "operator": "eq", "value": "premium"}]}'),
    (gen_random_uuid(), 'Moscow Region', '{"operator": "AND", "conditions": [{"field": "region", "operator": "eq", "value": "moscow"}]}'),
    (gen_random_uuid(), 'iOS Users', '{"operator": "AND", "conditions": [{"field": "device", "operator": "eq", "value": "ios"}]}');
```

#### D.3.3 Промо-кампании

```sql
-- Promo Campaigns
INSERT INTO rewards.promo_campaigns (campaign_id, name, type, conditions, reward_modifier, start_date, end_date, active)
VALUES 
    (gen_random_uuid(), 'Double Points February', 'MULTIPLIER',
     '{"operator": "AND", "conditions": []}',
     '{"multiplier": 2}',
     '2026-02-01 00:00:00', '2026-02-28 23:59:59', true);
```

---

### D.4 Стратегия кэширования (Redis)

#### D.4.1 Cache Keys

| Key Pattern | TTL | Описание |
|-------------|-----|----------|
| `rules:event:{event_type}` | 5 min | Кэш правил для типа события |
| `segments:user:{user_id}` | 1 hour | Сегменты пользователя |
| `balance:{user_id}` | 1 min | Баланс пользователя |
| `dedup:{dedup_key}` | 24 hours | Ключи дедупликации |
| `provider:status:{provider_id}` | 5 min | Статус провайдера |

#### D.4.2 Redis Data Structures

```
balance:{user_id} → String (balance amount)
rules:event:{event_type} → JSON (serialized rules)
user:{user_id}:segments → Set (segment IDs)
velocity:{user_id}:{check_type} → Hash (counts by window)
```

---

### D.5 Event Sourcing и аудит

#### D.5.1 Event Sourcing подход

- Все транзакции сохраняются в ledger как immutable events
- Баланс вычисляется как aggregate из транзакций
- Полный аудит-трейл каждого изменения

#### D.5.2 Audit Events

```json
{
  "audit_id": "uuid",
  "timestamp": "2026-02-24T10:00:00Z",
  "service": "rewards-calculation",
  "action": "REWARD_APPLIED",
  "actor": "system",
  "actor_id": "uuid",
  "resource_type": "reward",
  "resource_id": "uuid",
  "payload": {},
  "correlation_id": "uuid"
}
```

---

## E. План тестирования (Testing Strategy)

### E.1 Unit Tests

| Целевое покрытие | Минимум |
|------------------|---------|
| Core business logic | 80% |
| Utility functions | 90% |
| API controllers | 70% |
| Data models | 80% |

#### E.1.1 Тестовые фреймворки

- JUnit 5
- Mockito
- AssertJ
- Spring Boot Test

#### E.1.2 Пример теста

```java
@ExtendWith(MockitoExtension.class)
class RewardsCalculationServiceTest {
    
    @Mock
    private AccountRepository accountRepository;
    
    @Mock
    private TransactionRepository transactionRepository;
    
    @InjectMocks
    private RewardsCalculationService service;
    
    @Test
    void shouldCalculatePointsForActivation() {
        // Given
        String userId = UUID.randomUUID().toString();
        Event event = createEvent("subscription.activated");
        
        // When
        Reward reward = service.calculateReward(userId, event);
        
        // Then
        assertEquals(100, reward.getAmount());
        assertEquals(RewardType.POINTS, reward.getType());
    }
}
```

---

### E.2 Integration Tests

| Компонент | Тип тестов |
|-----------|------------|
| Database | Repository tests с Testcontainers |
| Kafka | Embedded Kafka tests |
| Redis | Embedded Redis / Testcontainers |
| External APIs | WireMock stubs |

#### E.2.1 Testcontainers конфигурация

```yaml
# docker-compose-test.yml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: rewards_test
    ports:
      - "5432:5432"
  
  kafka:
    image: confluentinc/cp-kafka:7.5.0
    environment:
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
    ports:
      - "9092:9092"
```

---

### E.3 Contract Tests (Pact/Spring Cloud Contract)

#### E.3.1 Provider contracts

```java
@Pact(consumer = "ingestion-service", provider = "eligibility-service")
V4Pact validateEligibility(PactDslWithProvider builder) {
    return builder
        .given("eligibility check is available")
        .uponReceiving("a request for eligibility check")
            .path("/api/v1/eligibility/check")
            .method("POST")
            .body(newJsonBody(body -> {
                body.stringType("userId");
                body.stringType("eventType");
            }).build())
        .willRespondWith()
            .status(200)
            .body(newJsonBody(body -> {
                body.booleanType("eligible");
                body.minArrayLike("matchedRules", 1, stringType());
            }).build())
        .toPact(V4Pact.class);
}
```

---

### E.4 E2E Tests

#### E.4.1 Основные сценарии

| Сценарий | Описание | Приоритет |
|----------|----------|-----------|
| Event → Reward | End-to-end обработка события | P0 |
| Reward Redemption | Использование награды | P0 |
| Sponsor Verification | Верификация спонсора | P1 |
| Dispute Flow | Оспаривание решения | P1 |
| Payout Flow | Выплата через шлюз | P2 |

#### E.4.2 E2E Test Framework

```java
@SpringBootTest
@AutoConfigureWireMock(port = 0)
class RewardsE2ETest {
    
    @Test
    void shouldProcessEventToReward() {
        // Given -外部 система отправляет событие
        Event event = createTestEvent("subscription.activated");
        
        // When - Отправляем в Ingestion API
        Response response = given()
            .contentType(ContentType.JSON)
            .body(event)
            .when()
            .post("/api/v1/events");
        
        // Then - Проверяем результат
        response.then()
            .statusCode(202)
            .body("status", equalTo("ACCEPTED"));
        
        // And - Проверяем начисление баллов
        await().atMost(5, TimeUnit.SECONDS)
            .until(() -> getBalance(userId) > 0);
    }
}
```

---

### E.5 Performance/Load Tests

#### E.5.1 Инструменты

- JMeter / Gatling
- k6

#### E.5.2 Целевые метрики

| Метрика | Target | SLA |
|---------|--------|-----|
| API p95 latency | < 100ms | 99% |
| API p99 latency | < 200ms | 99% |
| Event → Reward E2E | < 200ms | 95% |
| Throughput | 1000 req/s | Стабильно |
| Error rate | < 0.1% | 99.9% |

#### E.5.3 Load Profile

```
Scenario: Normal Load
- 1000 concurrent users
- 5000 events/hour average
- 50000 events/hour peak

Scenario: Stress Test
- 2000 concurrent users
- 10000 events/hour average
- 100000 events/hour peak (30 min)
```

---

### E.6 Security Tests

#### E.6.1 SAST/DAST

| Инструмент | Тип | Использование |
|------------|-----|--------------|
| SonarQube | SAST | Inline analysis |
| Snyk | SAST | Dependency scanning |
| OWASP ZAP | DAST | API security testing |
| Burp Suite | DAST | Manual testing |

#### E.6.2 Тестовые сценарии

- SQL Injection
- XSS
- CSRF
- Authentication bypass
- Authorization bypass
- PII leakage

---

## F. План развертывания (Deployment Plan)

### F.1 Kubernetes манифесты

#### F.1.1 Deployment пример

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingestion-service
  labels:
    app: ingestion-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ingestion-service
  template:
    metadata:
      labels:
        app: ingestion-service
    spec:
      containers:
        - name: ingestion-service
          image: registry.rewards-platform.com/ingestion-service:v1.0.0
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: "prod"
            - name: KAFKA_BOOTSTRAP_SERVERS
              valueFrom:
                configMapKeyRef:
                  name: kafka-config
                  key: bootstrap-servers
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          livenessProbe:
            httpGet:
              path: /api/v1/health/liveness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/v1/health/readiness
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
```

#### F.1.2 Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingestion-service
spec:
  selector:
    app: ingestion-service
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

#### F.1.3 Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewards-ingress
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
spec:
  rules:
    - host: api.rewards-platform.com
      http:
        paths:
          - path: /api/v1/events
            pathType: Prefix
            backend:
              service:
                name: ingestion-service
                port:
                  number: 80
```

#### F.1.4 ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingestion-config
data:
  kafka.bootstrap-servers: "kafka-0:9092,kafka-1:9092,kafka-2:9092"
  redis.host: "redis-cluster"
  redis.port: "6379"
  postgres.host: "postgres-primary"
  postgres.port: "5432"
```

#### F.1.5 Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ingestion-secrets
type: Opaque
stringData:
  postgres-username: "ingestion_user"
  postgres-password: "changeme"
  kafka-security-protocol: "SASL_SSL"
```

---

### F.2 Helm Charts

#### F.2.1 Структура

```
helm/
└── rewards-platform/
    ├── Chart.yaml
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-staging.yaml
    ├── values-prod.yaml
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── ingress.yaml
        ├── configmap.yaml
        └── secrets.yaml
```

#### F.2.2 values.yaml

```yaml
replicaCount: 3

image:
  repository: registry.rewards-platform.com
  pullPolicy: IfNotPresent
  tag: "v1.0.0"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

---

### F.3 Environment-specific конфигурации

| Параметр | Dev | Staging | Prod |
|----------|-----|---------|------|
| Replicas | 1 | 2 | 3-10 |
| Resources | 512Mi/500m | 1Gi/1000m | 1Gi/1000m |
| Autoscaling | Disabled | Enabled | Enabled |
| TLS | Self-signed | Valid | Valid |
| Backup | None | Daily | Every 4h |

---

### F.4 Database Migrations в CI/CD

```yaml
# .gitlab-ci.yml (пример)
deploy:
  stage: deploy
  script:
    - kubectl set image deployment/$SERVICE $SERVICE=$IMAGE
    - kubectl exec -it postgres-0 -- psql -U admin -c "SELECT version();"
    - kubectl exec -it $SERVICE-pod -- java -jar app.jar --spring.flyway.migrate=true
  only:
    - main
```

---

### F.5 Blue-Green / Canary Deployments

#### F.5.1 Canary Strategy

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ingestion-service
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 30
        - pause: {duration: 10m}
        - setWeight: 50
        - pause: {duration: 10m}
        - setWeight: 100
      canaryMetadata:
        labels:
          role: canary
      stableMetadata:
        labels:
          role: stable
```

---

### F.6 Rollback Strategy

| Scenario | Action |
|----------|--------|
| Pod crash | K8s автоматически перезапускает |
| Deployment failed | kubectl rollout undo |
| Database migration failed | Flyway rollback + deployment rollback |
| Service unhealthy | Service mesh перенаправляет на healthy pods |

---

## G. План мониторинга и Observability

### G.1 Метрики (Prometheus)

#### G.1.1 Метрики по сервисам

| Сервис | Метрики |
|--------|---------|
| Ingestion | events_received, events_processed, events_failed, dedup_cache_hits |
| Eligibility | eligibility_checks, eligible_count, rules_matched |
| Risk/Fraud | risk_scores, alerts_generated, velocity_violations |
| Rewards | balance_changes, rewards_issued, transactions_total |
| Fulfillment | fulfillment_requests, provider_latency, provider_errors |
| General | request_latency, error_rate, cpu_usage, memory_usage |

#### G.1.2 Примеры метрик

```java
// Custom metrics
Counter.builder("rewards.issued.total")
    .description("Total rewards issued")
    .tag("type", rewardType)
    .register(meterRegistry);

Timer.builder("api.latency")
    .description("API latency")
    .tag("endpoint", endpoint)
    .register(meterRegistry);
```

---

### G.2 Логи (Loki)

#### G.2.1 Структура логов

```json
{
  "timestamp": "2026-02-24T10:00:00.000Z",
  "level": "INFO",
  "service": "ingestion-service",
  "trace_id": "abc123",
  "span_id": "def456",
  "user_id": "user-123",
  "message": "Event processed successfully",
  "event_id": "event-123",
  "event_type": "subscription.activated"
}
```

#### G.2.2 Логируемые поля

- timestamp — ISO 8601
- level — DEBUG/INFO/WARN/ERROR
- service — имя сервиса
- trace_id — для трейсинга
- span_id — для трейсинга
- user_id — для аудита
- message — текст сообщения
- context — дополнительные данные

---

### G.3 Трейсинг (Jaeger)

#### G.3.1 Key Spans

| Span | Описание | Теги |
|------|----------|------|
| ingestion.process | Обработка события | event_type, source |
| eligibility.check | Проверка eligibility | user_id, event_type |
| risk.score | Риск-скоринг | user_id, score |
| rewards.calculate | Расчёт награды | reward_type, amount |
| fulfillment.create | Создание fulfillment | provider_id, reward_id |

#### G.3.2 Trace Context

```
ingestion.process
├── validation.check
├── deduplication.lookup
├── enrichment.fetch
└── kafka.publish
    └── eligibility.check
        ├── rules.matching
        ├── segment.resolution
        └── decision.making
            └── risk.score
                ├── profile.lookup
                ├── velocity.check
                └── ml.scoring
                    └── rewards.calculate
                        ├── balance.update
                        └── transaction.write
                            └── fulfillment.create
                                └── provider.api.call
```

---

### G.4 Health Checks

#### G.3.1 Liveness Probe

```java
@RestController
public class HealthController {
    
    @GetMapping("/api/v1/health/liveness")
    public ResponseEntity<String> liveness() {
        return ResponseEntity.ok("OK");
    }
}
```

#### G.3.2 Readiness Probe

```java
@GetMapping("/api/v1/health/readiness")
public ResponseEntity<HealthStatus> readiness() {
    HealthStatus status = HealthStatus.builder()
        .database(checkDatabase())
        .kafka(checkKafka())
        .redis(checkRedis())
        .build();
    
    return status.isHealthy() 
        ? ResponseEntity.ok(status)
        : ResponseEntity.status(503).body(status);
}
```

---

### G.5 Alert Rules (Prometheus AlertManager)

#### G.5.1 P0 (Critical)

| Alert | Condition | Action |
|-------|-----------|--------|
| ServiceDown | up == 0 for 2m | Page on-call |
| HighErrorRate | error_rate > 1% for 5m | Page on-call |
| DatabaseDown | pg_up Page on-call |
| Kafka == 0 |Down | kafka_broker_up == 0 | Page on-call |

#### G.5.2 P1 (High)

| Alert | Condition | Action |
|-------|-----------|--------|
| HighLatency | p99_latency > 500ms for 10m | Page team lead |
| QueueGrowing | kafka_consumer_lag > 10000 | Notify team |
| HighMemory | memory > 90% for 10m | Notify team |

#### G.5.3 P2 (Medium)

| Alert | Condition | Action |
|-------|-----------|--------|
| DeprecatedAPI | api_deprecated_count > 0 | Ticket |
| ConfigDrift | config_version_mismatch | Ticket |

---

### G.6 Dashboards (Grafana)

#### G.6.1 Основные панели

| Dashboard | Описание |
|-----------|----------|
| Service Overview | Обзор всех сервисов |
| API Performance | Latency, throughput, errors |
| Kafka Monitoring | Consumer lag, topic sizes |
| Database Performance | Query times, connections |
| Business Metrics | Rewards issued, users active |

#### G.6.2 Пример Grafana Panel

```json
{
  "title": "Event Processing Rate",
  "type": "graph",
  "targets": [
    {
      "expr": "rate(events_processed_total[5m])",
      "legendFormat": "{{service}}"
    }
  ],
  "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8}
}
```

---

## H. План безопасности (Security Plan)

### H.1 OAuth 2.0 / OIDC настройка

#### H.1.1 Конфигурация провайдеров

| Канал | Протокол | Flow |
|-------|----------|------|
| Subscriber App | OAuth 2.0 + PKCE | Authorization Code |
| Sponsor App | OAuth 2.0 + PKCE | Authorization Code |
| Admin Portal | OIDC + SAML | Redirect |

#### H.1.2 Token конфигурация

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.rewards-platform.com
          jwk-set-uri: https://auth.rewards-platform.com/.well-known/jwks.json
```

---

### H.2 RBAC / ABAC политики

#### H.2.1 Роли и разрешения

| Роль | Permissions |
|------|-------------|
| subscriber | read:own_balance, read:own_rewards, dispute |
| sponsor | read:sponsored, verify:relationship |
| support | read:all, override:decisions |
| admin | full:access |
| finance | read:financials, reports |
| risk | read:risk_data, manage:rules |

#### H.2.2 ABAC пример

```java
@PreAuthorize("hasRole('ADMIN') OR " +
    "(hasRole('SUPPORT') AND #userId == principal.userId)")
public ResponseEntity<UserData> getUserData(String userId) {
    // ...
}
```

---

### H.3 Шифрование данных

| Данные | At Rest | In Transit |
|--------|---------|------------|
| PII | AES-256 | TLS 1.3 |
| Financial | AES-256 | TLS 1.3 + mTLS |
| Credentials | Hash (bcrypt) | TLS 1.3 |
| Logs | AES-256 | TLS 1.3 |

#### H.3.1 PostgreSQL encryption

```sql
-- TDE (Transparent Data Encryption)
-- На уровне БД (зависит от провайдера)
CREATE TABLE accounts (
    -- данные автоматически шифруются
);
```

---

### H.4 Secret Management

#### H.4.1 Vault интеграция

```java
@Value("${vault.secret.path}")
private String secretPath;

@Bean
public VaultTemplate vaultTemplate(VaultOperations vaultOperations) {
    return new VaultTemplate(vaultOperations);
}
```

#### H.4.2 K8s Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: changeme
```

---

### H.5 Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingestion-network-policy
spec:
  podSelector:
    matchLabels:
      app: ingestion-service
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: kafka
      ports:
        - protocol: TCP
          port: 9092
```

---

### H.6 Compliance Checklists

#### H.6.1 GDPR

| Требование | Реализация |
|------------|------------|
| Right to erasure | DELETE /api/v1/users/{id} с cascade |
| Data portability | Export в JSON/CSV |
| Consent management | Consent service |
| Data minimization | PII tokenization |

#### H.6.2 PCI-DSS

| Требование | Реализация |
|------------|------------|
| No card storage | Tokenization only |
| Encryption | TLS 1.3 + mTLS |
| Access control | RBAC + audit |
| Logging | Full audit trail |

---

## I. Дорожная карта (Roadmap)

### I.1 Timeline

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                           REWARDS PLATFORM TIMELINE                                 │
├────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  Phase 0: Foundation          [■■■■■■] Wk 1-4                                     │
│  Phase 1: Core Services       [████████████████] Wk 5-12                         │
│  Phase 2: Risk/Fraud          [████████████] Wk 13-18                            │
│  Phase 3: Explainability      [████████] Wk 19-22                                 │
│  Phase 4: Optional Services   [████████] Wk 23-26 (опционально)                 │
│  Phase 5: Channels            [████████████] Wk 27-32                            │
│  Phase 6: Integration         [████████] Wk 33-36                                │
│  Phase 7: Production          [██████] Wk 37-39                                   │
│                                                                                    │
│  TOTAL: ~39 weeks (9-10 months)                                                   │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘
```

### I.2 Milestones

| Milestone | Неделя | Критерий |
|-----------|--------|-----------|
| M1: Dev Environment Ready | 4 | Все сервисы запущены локально |
| M2: Core Pipeline | 12 | Event → Reward работает |
| M3: Full MVP | 22 | Все 7 сервисов работают |
| M4: Integration Ready | 36 | E2E тесты проходят |
| M5: Production Ready | 39 | Go-live |

---

### I.3 Зависимости между фазами

```
Phase 0 ─────┬──▶ Phase 1 ───▶ Phase 2 ───▶ Phase 3 ──▶ Phase 6 ──▶ Phase 7
             │                          │
             │                          └────▶ Phase 4 (optional)
             │
             └──────▶ Phase 5 (parallel)

Phase 5 depends on: Phase 1, 2, 3 (channels need backend APIs)
Phase 6 depends on: Phase 1, 2, 3, 5 (full integration)
Phase 7 depends on: Phase 6 (ready for production)
```

---

### I.4 Критические пути

| # | Критический путь | Impact |
|---|------------------|--------|
| 1 | Phase 0 → 1 → 2 → 6 → 7 | Event → Reward E2E |
| 2 | Phase 1: Eligibility | Блокирует расчёт наград |
| 3 | Phase 2: Risk/Fraud | Блокирует безопасность |
| 4 | Kafka setup (Phase 0) | Блокирует все фазы |

---

### I.5 Риски и митигации

| Риск | Вероятность | Impact | Митигация |
|------|-------------|--------|-----------|
| Задержка интеграции с провайдерами | High | High | Mock сервисы для разработки |
| Сложность ML моделей для Risk | Medium | High | Начать с rule-based, итеративно |
| Задержка AI/Subagent интеграции | Medium | Medium | Baseline LLM integration с простыми промптами |
| Командный capacity | High | High | Фазы могут перекрываться |
| Security compliance | Medium | High | Security review на каждой фазе |

---

## J. Команда и ресурсы (Team & Resources)

### J.1 Роли и Responsibilities

| Роль | Количество | Responsibilities |
|------|------------|------------------|
| Tech Lead / Architect | 1 | Архитектура, технические решения |
| Senior Backend Dev | 3 | Core services разработка |
| Backend Developer | 4 | Feature development |
| Frontend Developer | 3 | Channels (Apps, Portal) |
| DevOps Engineer | 2 | Infrastructure, CI/CD |
| QA Engineer | 2 | Testing, QA |
| Security Engineer | 1 | Security, compliance |
| Product Manager | 1 | Product backlog |
| Data Engineer | 1 | Data models, migrations |

### J.2 Headcount

| Позиция | Headcount |
|---------|------------|
| Engineering | 13 |
| QA | 2 |
| Security | 1 |
| Product | 1 |
| **Total** | **17** |

---

### J.3 Необходимые навыки

| Навык | Уровень | Приоритет |
|-------|---------|-----------|
| Java/Kotlin | Expert | Critical |
| Spring Boot | Expert | Critical |
| PostgreSQL | Advanced | Critical |
| Kafka | Advanced | High |
| Redis | Intermediate | High |
| Kubernetes | Intermediate | High |
| Docker | Intermediate | High |
| OAuth 2.0/OIDC | Intermediate | High |
| Prometheus/Grafana | Intermediate | Medium |
| AI/LLM integration | Basic | Medium |

---

### J.4 Инструменты и лицензии

| Инструмент | Тип | Лицензия |
|------------|-----|----------|
| IDE (IntelliJ) | Development | Commercial |
| GitLab/GitHub | VCS | Commercial |
| Jira | Project Management | Commercial |
| Confluence | Documentation | Commercial |
| SonarQube | Code Quality | Commercial |
| PagerDuty | Alerting | Commercial |
| Datadog/New Relic | APM | Commercial |
| Figma | Design | Commercial |

---

## Приложения

### Приложение 1: Глоссарий терминов

| Термин | Определение |
|--------|-------------|
| BSS/OSS | Business Support Systems / Operations Support Systems |
| EdTech VAS | Educational Technology Value-Added Services |
| KYC | Know Your Customer — проверка клиента |
| PII | Personally Identifiable Information — персональные данные |
| RPO | Recovery Point Objective — допустимая потеря данных |
| RTO | Recovery Time Objective — время восстановления |
| SLO | Service Level Objective — целевой уровень сервиса |
| TTL | Time To Live — срок жизни данных |

### Приложение 2: Контактная информация

| Роль | Email |
|------|-------|
| Tech Lead | tech-lead@rewards-platform.com |
| Product Manager | pm@rewards-platform.com |
| DevOps Lead | devops@rewards-platform.com |
| Security | security@rewards-platform.com |

---

**Документ подготовлен:** Architecture Team  
**Дата:** 2026-02-24  
**Версия:** 1.0
