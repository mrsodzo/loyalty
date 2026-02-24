# MVP Implementation Plan: Rewards Platform

**Версия:** 1.0  
**Дата:** 2026-02-24  
**Статус:** Черновик для демонстрации

---

## 1. MVP Scope Definition

### 1.1 Что входит в MVP (Must-Have)

| Компонент | Описание | Приоритет |
|-----------|----------|-----------|
| **4 Core Services** | Ingestion, Eligibility, Calculation, Fulfillment | P0 |
| **Event → Reward E2E** | Полный поток от события до награды | P0 |
| **Single PostgreSQL** | Одна база данных для всех сервисов | P0 |
| **HTTP API** | Синхронная обработка (без Kafka) | P0 |
| **Subscriber App** | Просмотр баланса и истории | P0 |
| **Admin Portal** | Мониторинг и ручные override | P1 |
| **Mock Reward Provider** | Симуляция внешнего провайдера | P0 |
| **4 Event Types** | Активация, пополнение, покупка пакета, учебная активность | P0 |
| **3 Loyalty Rules** | Бонус за активацию, кешбэк, бонус за пакет | P0 |

### 1.2 Что НЕ входит (Out of Scope)

| Компонент | Причина | Phase 2 |
|-----------|---------|---------|
| Risk/Fraud Service | Упрощение для MVP | +4 недели |
| Explainability Agent | Требует LLM интеграции | +3 недели |
| Audit Agent | Базовый аудит встроен в сервисы | +2 недели |
| Sponsor/Parent App | Второй канал | +4 недели |
| Payment Gateway | Отложить до реальных выплат | +4 недели |
| Kafka Event Bus | HTTP API достаточно для MVP | — |
| Redis кэш | Оптимизация после работающего MVP | +1 неделя |
| AI/Subagents | Сложная интеграция | +6 недель |
| KYC/Limits | Базовый функционал без фин. ограничений | +2 недели |

### 1.3 Критерии успеха (Success Metrics)

| Метрика | Целевое значение | Измерение |
|---------|-------------------|-----------|
| E2E Latency | < 500ms | От события до ответа API |
| Uptime | > 99% | Время работы сервисов |
| Event Processing | 100% без потерь | Обработанные события |
| Demo Scenarios | 4/4 работают | Все E2E сценарии |
| Frontend Load | < 3 сек | Время загрузки страниц |

---

## 2. Упрощенная архитектура MVP

### 2.1 Диаграмма компонентов

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MVP ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌─────────────┐         ┌─────────────┐         ┌─────────────┐   │
│   │   External  │         │    API      │         │   Frontend   │   │
│   │   Systems   │────────▶│   Gateway   │◀────────│   (React)    │   │
│   │  (BSS/EdTech)│         │  (Spring)  │         │              │   │
│   └─────────────┘         └──────┬──────┘         └─────────────┘   │
│                                   │                                        │
│   ┌────────────────────────────────┼────────────────────────────────┐   │
│   │                    CORE SERVICES (Monolith Lite)                │   │
│   │                                                                 │   │
│   │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │   │
│   │   │  Ingestion  │───▶│ Eligibility │───▶│ Calculation │     │   │
│   │   │   Service   │    │   Service   │    │   Service   │     │   │
│   │   └─────────────┘    └─────────────┘    └──────┬──────┘     │   │
│   │                                                  │              │   │
│   │                                                  ▼              │   │
│   │                                         ┌─────────────┐          │   │
│   │                                         │Fulfillment │          │   │
│   │                                         │   Service   │          │   │
│   │                                         └──────┬──────┘          │   │
│   │                                                │                 │   │
│   └────────────────────────────────────────────────┼─────────────────┘   │
│                                                  │                        │
│                                                  ▼                        │
│   ┌────────────────────────────────────────────────────────────────┐   │
│   │                     DATA LAYER                                 │   │
│   │  ┌─────────────┐                           ┌─────────────┐   │   │
│   │  │ PostgreSQL  │◀─────────────────────────│Mock Reward  │   │   │
│   │  │   Primary   │                           │  Provider   │   │   │
│   │  └─────────────┘                           └─────────────┘   │   │
│   └────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Упрощенный Data Flow

```
Event In → Ingestion → Eligibility → Calculation → Fulfillment → Response
                 │             │             │              │
                 ▼             ▼             ▼              ▼
            PostgreSQL    PostgreSQL    PostgreSQL     PostgreSQL
```

### 2.3 Технологии MVP

| Компонент | Production | MVP (упрощено) | Обоснование |
|-----------|------------|----------------|-------------|
| Message Broker | Apache Kafka | **HTTP/Rest** | Достаточно для 1000 events/day |
| Database | PostgreSQL (отдельные схемы) | **Single PostgreSQL** | Упрощение инфраструктуры |
| Cache | Redis Cluster | **In-memory / None** | Пока нет высокой нагрузки |
| Container | Kubernetes | **Docker Compose** | Локальная разработка |
| API Gateway | Kong | **Spring Cloud Gateway** | Встроенный |

---

## 3. Сервисы MVP

### 3.1 Ingestion Service

| Характеристика | Значение |
|----------------|----------|
| Назначение | Нормализация событий, базовая валидация |
| Технология | Java 17 + Spring Boot |
| Зависимости | PostgreSQL |

**API Endpoints:**

| Method | Endpoint | Описание |
|--------|----------|----------|
| POST | `/api/v1/events` | Принять событие |
| GET | `/api/v1/events/{eventId}/status` | Статус события |
| GET | `/api/v1/health` | Health check |

**Data Model:**

```sql
CREATE TABLE events (
    event_id UUID PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    user_id UUID,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);
```

**Оценка сложности:** 3 дня

---

### 3.2 Eligibility Service

| Характеристика | Значение |
|----------------|----------|
| Назначение | Проверка права на награду, простые правила |
| Технология | Java 17 + Spring Boot |
| Зависимости | PostgreSQL |

**API Endpoints:**

| Method | Endpoint | Описание |
|--------|----------|----------|
| POST | `/api/v1/eligibility/check` | Проверить право на награду |
| GET | `/api/v1/eligibility/rules` | Список правил |
| POST | `/api/v1/eligibility/rules` | Создать правило |

**Data Model:**

```sql
CREATE TABLE loyalty_rules (
    rule_id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    conditions JSONB NOT NULL,  -- {"field": "amount", "operator": "gte", "value": 100}
    reward_type VARCHAR(50) NOT NULL,  -- POINTS, CASHBACK
    reward_value JSONB NOT NULL,  -- {"fixed": 100} или {"percentage": 5, "max": 500}
    active BOOLEAN DEFAULT true,
    priority INT DEFAULT 0
);
```

**Seed Data (MVP):**

```sql
INSERT INTO loyalty_rules VALUES
    (gen_random_uuid(), 'New Subscriber Bonus', 'subscription.activated', 
     '{}', 'POINTS', '{"fixed": 100}', true, 100),
    
    (gen_random_uuid(), 'Recharge Cashback', 'subscription.recharged',
     '{"field": "amount", "operator": "gte", "value": 100}',
     'CASHBACK', '{"percentage": 5, "max": 500}', true, 50),
    
    (gen_random_uuid(), 'Package Bonus', 'package.purchased',
     '{}', 'POINTS', '{"fixed": 50}', true, 50);
```

**Оценка сложности:** 4 дня

---

### 3.3 Rewards Calculation Service

| Характеристика | Значение |
|----------------|----------|
| Назначение | Расчет начислений, управление балансом |
| Технология | Java 17 + Spring Boot |
| Зависимости | PostgreSQL |

**API Endpoints:**

| Method | Endpoint | Описание |
|--------|----------|----------|
| POST | `/api/v1/rewards/calculate` | Рассчитать награду |
| GET | `/api/v1/rewards/balance/{userId}` | Получить баланс |
| GET | `/api/v1/rewards/history/{userId}` | История наград |

**Data Model:**

```sql
-- Accounts (Rewards Bank Account)
CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(15,2) DEFAULT 0,
    currency VARCHAR(10) DEFAULT 'VIRTUAL_RUB',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Rewards
CREATE TABLE rewards (
    reward_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    event_id UUID,
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Transactions (Ledger)
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY,
    account_id UUID NOT NULL REFERENCES accounts(account_id),
    type VARCHAR(20) NOT NULL,  -- CREDIT, DEBIT
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    reference_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);
```

**Оценка сложности:** 5 дней

---

### 3.4 Fulfillment Service

| Характеристика | Значение |
|----------------|----------|
| Назначение | Выдача наград через mock провайдера |
| Технология | Java 17 + Spring Boot |
| Зависимости | PostgreSQL, Mock Provider |

**API Endpoints:**

| Method | Endpoint | Описание |
|--------|----------|----------|
| POST | `/api/v1/fulfillment/create` | Создать запрос на выдачу |
| GET | `/api/v1/fulfillment/status/{requestId}` | Статус запроса |
| POST | `/api/v1/fulfillment/mock/create` | Mock API для симуляции |

**Mock Provider Implementation:**

```java
@Service
public class MockRewardProviderClient {
    
    public CreateRewardResponse createReward(CreateRewardRequest request) {
        // Симуляция успешного создания награды
        return CreateRewardResponse.builder()
            .rewardId(UUID.randomUUID().toString())
            .status("SUCCESS")
            .build();
    }
}
```

**Data Model:**

```sql
CREATE TABLE fulfillment_requests (
    request_id UUID PRIMARY KEY,
    reward_id UUID NOT NULL,
    user_id UUID NOT NULL,
    provider_id VARCHAR(100) DEFAULT 'MOCK_PROVIDER',
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW(),
    fulfilled_at TIMESTAMP
);
```

**Оценка сложности:** 3 дня

---

## 4. Интеграции MVP

### 4.1 Event Ingestion

| Параметр | Значение |
|----------|----------|
| Протокол | HTTP REST API |
| Формат | JSON |
| Аутентификация | API Key (простая) |

**Пример запроса:**

```bash
curl -X POST http://localhost:8080/api/v1/events \
  -H "Content-Type: application/json" \
  -H "X-API-Key: mvp-secret-key" \
  -d '{
    "event_name": "subscription.activated",
    "source_system": "BSS",
    "timestamp": "2026-02-24T10:00:00Z",
    "payload": {
      "msisdn": "+79001234567",
      "plan_id": "premium",
      "region": "moscow"
    }
  }'
```

### 4.2 Mock Reward Provider

| Параметр | Значение |
|----------|----------|
| Тип | Встроенный mock сервис |
| Задержка | 100ms (симуляция) |
| Отказоустойчивость | Нет (MVP) |

### 4.3 Database Schema

```sql
-- Single database для MVP
CREATE DATABASE rewards_mvp;

-- Все таблицы в одной схеме
CREATE SCHEMA IF NOT EXISTS mvp;

-- Events
CREATE TABLE mvp.events (...);

-- Rules  
CREATE TABLE mvp.loyalty_rules (...);

-- Rewards
CREATE TABLE mvp.accounts (...);
CREATE TABLE mvp.rewards (...);
CREATE TABLE mvp.transactions (...);

-- Fulfillment
CREATE TABLE mvp.fulfillment_requests (...);
```

---

## 5. Фронтенд MVP

### 5.1 Subscriber App (React)

| Компонент | Описание |
|-----------|----------|
| Технология | React + Vite |
| Стили | CSS Modules / Tailwind |
| Состояние | React Context |

**Страницы:**

| Страница | Маршрут | Описание |
|----------|---------|----------|
| Login | `/login` | Простой вход по MSISDN |
| Dashboard | `/` | Баланс и последние награды |
| History | `/history` | История начислений/списаний |

**API Интеграция:**

```javascript
// Balance display
const fetchBalance = async (userId) => {
  const response = await fetch(`/api/v1/rewards/balance/${userId}`);
  return response.json();
};

// Event history
const fetchHistory = async (userId) => {
  const response = await fetch(`/api/v1/rewards/history/${userId}`);
  return response.json();
};
```

**Оценка сложности:** 5 дней

### 5.2 Admin Portal (React)

| Страница | Маршрут | Описание |
|----------|---------|----------|
| Dashboard | `/admin` | Общая статистика |
| Events | `/admin/events` | Список событий |
| Override | `/admin/override` | Ручное изменение баланса |

**Оценка сложности:** 3 дня

---

## 6. План разработки MVP

### 6.1 Недели 1-2: Foundation

| День | Задача | Ответственный |
|------|--------|---------------|
| 1-2 | Настройка проекта, Docker Compose | Backend |
| 3-4 | PostgreSQL схемы, миграции | Backend |
| 5-7 | Ingestion Service (базовый) | Backend |
| 8-10 | Eligibility Service | Backend |

**Deliverable:** 2 сервиса работают, события принимаются

### 6.2 Недели 3-4: Core Services

| День | Задача | Ответственный |
|------|--------|---------------|
| 11-15 | Rewards Calculation Service | Backend |
| 16-20 | Fulfillment Service + Mock Provider | Backend |
| 17-20 | E2E интеграция (Event → Reward) | Backend |

**Deliverable:** E2E pipeline работает end-to-end

### 6.3 Недели 5-6: Frontend + Integration

| День | Задача | Ответственный |
|------|--------|---------------|
| 21-25 | Subscriber App (базовый UI) | Frontend |
| 26-28 | Admin Portal (мониторинг) | Frontend |
| 29-35 | Integration testing | QA |
| 36-42 | Демо-подготовка, документация | Team |

**Deliverable:** Работающий MVP с UI

### 6.4 Неделя 7: Demo & Deploy

| День | Задача |
|------|--------|
| 43-45 | Bug fixes, polish |
| 46-47 | Demo rehearsal |
| 48 | Live demo |

**Итого:** ~7 недель (48 рабочих дней)

---

## 7. Демо-сценарии

### 7.1 Сценарий 1: Активация подписки

```
1. BSS отправляет событие subscription.activated
2. Ingestion принимает и валидирует
3. Eligibility проверяет правило "New Subscriber Bonus"
4. Calculation начисляет 100 баллов
5. Fulfillment создает mock награду
6. User видит +100 в Subscriber App
```

**API Test:**
```bash
curl -X POST http://localhost:8080/api/v1/events \
  -d '{"event_name": "subscription.activated", "source_system": "BSS", "payload": {"msisdn": "+79001234567"}}'
```

**Expected:** Balance = 100

---

### 7.2 Сценарий 2: Пополнение баланса (кешбэк)

```
1. BSS отправляет событие subscription.recharged с amount: 1000
2. Eligibility проверяет правило "Recharge Cashback"
3. Calculation начисляет 5% = 50 баллов (кешбэк)
4. User видит +50 в балансе
```

**Expected:** Balance = 150

---

### 7.3 Сценарий 3: Просмотр баланса в приложении

```
1. User открывает Subscriber App
2. Загружается Dashboard
3. Отображается текущий баланс
4. Загружается история последних транзакций
```

**Expected:** UI показывает баланс и историю

---

### 7.4 Сценарий 4: Админ мониторинг

```
1. Admin открывает Admin Portal
2. Видит dashboard с метриками:
   - Событий обработано
   - Наград выдано
   - Ошибок
3. Может посмотреть список событий
4. Может выполнить ручной override баланса
```

---

## 8. Инфраструктура MVP

### 8.1 Локальная разработка

```yaml
# docker-compose.yml
services:
  api-gateway:
    image: spring-gateway
    ports:
      - "8080:8080"
  
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: rewards_mvp
    ports:
      - "5432:5432"
  
  frontend:
    image: react-app
    ports:
      - "3000:3000"
```

### 8.2 Staging (один сервер)

| Компонент | Конфигурация |
|-----------|--------------|
| Server | 4 CPU, 8 GB RAM |
| Docker | Docker Compose |
| PostgreSQL | 15 |
| Backend | 1 container |
| Frontend | 1 container |

### 8.3 Мониторинг (простой)

| Инструмент | Назначение |
|------------|------------|
| Health Checks | Spring Actuator |
| Logs | stdout → file |
| Metrics | Spring Boot Actuator |

**Endpoints:**
- `GET /actuator/health` - Health
- `GET /actuator/metrics` - Metrics

---

## 9. Риски MVP

### 9.1 Что может сломаться

| Риск | Вероятность | Impact | Митигация |
|------|-------------|--------|-----------|
| Сложность E2E интеграции | High | High | Раннее тестирование |
| Data consistency | Medium | High | Транзакции в PostgreSQL |
| Frontend-backend integration | Medium | Medium | Mock API на frontend |
| Scope creep | High | Medium | Жесткий фокус на MVP |

### 9.2 Technical Debt

| Долг | Решение в Phase 2 |
|------|-------------------|
| HTTP вместо async | Добавить Kafka |
| No caching | Добавить Redis |
| Monolith | Разделить на сервисы |
| No monitoring | Добавить Prometheus/Grafana |
| Hardcoded rules | Внешняя конфигурация |

---

## 10. Transition Plan

### 10.1 Из MVP к полной версии

```
MVP (7 weeks) → Phase 1 (8 weeks) → Phase 2 (6 weeks) → Production
```

### 10.2 Что переписать/рефакторить

| Компонент | MVP | Production |
|-----------|-----|------------|
| Ingestion | REST API | Kafka Consumer |
| Data | Single DB | Schema per service |
| Caching | None | Redis |
| Monitoring | Basic | Full observability |

### 10.3 Приоритеты для Phase 2

| Priority | Компонент | Недели |
|----------|-----------|--------|
| 1 | Risk/Fraud Service | 6 |
| 2 | Kafka Event Bus | 4 |
| 3 | Redis Caching | 2 |
| 4 | Audit Agent | 3 |
| 5 | Explainability Agent | 4 |
| 6 | Payment Gateway | 4 |

---

## Приложение A: Quick Start

### Запуск MVP

```bash
# 1. Clone и настройка
cd rewards-platform

# 2. Docker Compose
docker-compose up -d

# 3. Backend (Java)
cd backend
./mvnw spring-boot:run

# 4. Frontend
cd frontend
npm install
npm run dev

# 5. Тест
curl -X POST http://localhost:8080/api/v1/events \
  -H "Content-Type: application/json" \
  -d '{"event_name": "subscription.activated", "source_system": "BSS", "payload": {"msisdn": "+79001234567"}}'

# 6. Проверка баланса
curl http://localhost:8080/api/v1/rewards/balance/{userId}
```

---

**Документ подготовлен:** Architecture Team  
**Дата:** 2026-02-24  
**Версия:** 1.0
