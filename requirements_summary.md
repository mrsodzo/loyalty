# Requirements Summary: Rewards Platform

## Document Information
- **Source File**: `task.docx`
- **Extraction Date**: 2026-02-24
- **Purpose**: Architecture development for Rewards Platform

---

## 1. Context and Objectives

### 1.1 Product Overview
**Rewards Platform** — платформа лояльности для обработки событий из внешних систем и выдачи наград пользователям.

### 1.2 Channels
| Channel | Description |
|---------|-------------|
| **Subscriber App** | Мобильное приложение для конечных пользователей (абонентов) |
| **Sponsor/Parent App** | Приложение для спонсоров/родителей |
| **Admin Portal** | Портал для операторов и администраторов |

### 1.3 Event Sources
- **BSS/OSS** — системы биллинга и операционной поддержки
- **EdTech VAS** — образовательные сервисы с добавленной стоимостью

### 1.4 Reward Delivery
- 3rd-party reward providers
- Payment Gateway

---

## 2. Business Scenarios

### 2.1 Event → Reward (Category 1) — Обязательный
**End-to-end поток:**
1. Событие (активация, пополнение, учебная активность, покупка пакета) попадает в ingestion
2. Сервисы рассчитывают eligibility
3. Начисление баллов/кешбэк/ваучер
4. Fulfillment отдаёт награду через внешнего провайдера
5. Пользователь видит результат в приложении

### 2.2 Sponsor Verification + Sponsored Rewards
**Поток:**
1. Спонсор/родитель подтверждает связь с подписчиком
2. Субагенты оценивают риск/мошенничество
3. Решение: `allow` / `deny` / `step-up verification`
4. При успехе — активируется "спонсируемая" логика наград

### 2.3 Dispute / Explainability
**Поток:**
1. Пользователь оспаривает отказ/начисление
2. Система показывает объяснение ("почему так") в рамках политики
3. Оператор в Admin Portal может выполнить override с аудитом

### 2.4 Rewards Bank Account Concept — Расширение
**Требования:**
- "Балансовый" продукт (кошелёк наград)
- Лимиты
- KYC-лайт/скоринг
- Предотвращение злоупотреблений
- Выплаты через payment gateway
- Частичная отмена/реверс

---

## 3. Required Services

### 3.1 Core Services (Обязательные)

| Service | Responsibilities |
|---------|------------------|
| **Ingestion** | Нормализация событий, дедупликация, обогащение |
| **Eligibility** | Правила, сегментация, вычисление права на награду |
| **Risk/Fraud** | Риск-скоринг, аномалии, rate limits, step-up |
| **Rewards Calculation** | Начисления/списания, промо-кампании |
| **Fulfillment** | Взаимодействие с внешними провайдерами наград, идемпотентность |
| **Explainability & Audit Agent** | Формирование объяснений + аудит-трейл |
| **Ops/Admin Assistant Agent** | Помощник оператору (с жёсткими границами прав) |

### 3.2 Optional Services (Bonus)

| Service | Responsibilities |
|---------|------------------|
| **Personalization** | Next best action, предложения |
| **Sponsor Relationship** | Граф связей "спонсор—подписчик", доверие |
| **Policy** | Централизованные политики и запреты (compliance) |

---

## 4. RFI Requirements

### 4.1 Channels and User Roles

#### 4.1.1 Channels
- Subscriber App
- Sponsor/Parent App
- Admin Portal

#### 4.1.2 Roles and Permissions
**Роли:**
- `subscriber` — абонент
- `sponsor` — спонсор
- `admin` — администратор
- `support` — поддержка
- `finance` — финансы
- `risk` — риск-менеджмент

**Требование:** Все действия пользователей должны быть журналированы (audit logging)

---

### 4.2 Data Sources and Events (BSS/OSS, EdTech VAS)

#### 4.2.1 Event Catalog
**Обязательная таблица для каждого event type:**

| Field | Description |
|-------|-------------|
| `event_name` | Наименование события |
| `source_system` | Источник события |
| `schema` | Поля и типы данных |
| `deduplication_keys` | Уникальные ключи (msisdn, client_id) |
| `expected_frequency` | Средняя/пиковая частота: 1000 / 100 000 |

#### 4.2.2 Data Quality and Consistency
- Возможны дубли событий
- Late events: до 2 часов
- Источник истины по статусу абонента/продукта — BSS/OSS

---

### 4.3 Loyalty Rules and Program Categories

#### 4.3.1 MVP
**Триггеры:**
- Активация
- Пополнение
- Покупка пакета
- Учебное действие

**Параметры:**
- Формулы начислений
- Лимиты
- TTL баллов

**Сегментация:**
- Продукт
- Тарифный план
- Регион
- Устройство

#### 4.3.2 Rewards Bank Account / Семейные сценарии
| Parameter | Value |
|-----------|-------|
| Валюта/единицы | Виртуальные рубли |
| Правила округления | Рубль, округление вверх |
| Отрицательный баланс | Не допустим |
| Баланс | Бессрочный |

#### 4.3.3 Explainability
- Можно показывать пользователю "почему отказано/начислено"
- Оператору доступны риск-факторы, сигналы антифрода
- Требования к локализации (языки) не предъявляются

---

### 4.4 Integrations: Reward Providers and Payment Gateway

#### 4.4.1 Reward Providers
| Requirement | Details |
|-------------|---------|
| **API** | `create` / `redeem` / `cancel` / `status` |
| **Идемпотентность** | Поддержка idempotency keys |
| **Rate limits** | Timeouts, SLA |
| **Отмены** | Поддержка отмен/частичных отмен |
| **Webhook'и** | Подпись, повторная доставка |

#### 4.4.2 Payment Gateway
| Requirement | Details |
|-------------|---------|
| **Методы** | `payout` / `refund` / `partial refund` |
| **Аутентификация** | 3DS / SCA (если применимо), лимиты |
| **Webhook flow** | Требования к подтверждению |
| **Риски** | Чарджбек, возвраты, dispute process |

---

### 4.5 AI/Subagents: Policies, Models, Data

#### 4.5.1 Allowed Models and Environments
- Разрешено использовать внешние LLM
- Логи промптов должны быть сохранены

#### 4.5.2 Guardrails
- **PII Protection:** Модели нельзя отправлять паспортные данные
- **Prompt Injection Protection:** Защита от prompt injection (особенно из user content)

---

### 4.6 Operations, Monitoring, Support

| Requirement | Details |
|-------------|---------|
| **On-call режим** | P0/P1 критерии |
| **Runbooks** | Провайдер недоступен, очередь растёт, БД read-only |
| **Алерты** | Должны срабатывать на передачу запрещённой информации |

---

### 4.7 NFR/SLO and DR (Обязательно)

#### 4.7.1 NFR (Non-Functional Requirements)

| Metric | Target |
|--------|--------|
| **API Availability** | Доступность API |
| **Latency p95/p99** | Percentile latency |
| **E2E Latency** | Event → Reward: 100 мс → 200 мс |
| **Consistency (ledger)** | ≤ 1% потерянных наград для клиента за период времени |

#### 4.7.2 DR (Disaster Recovery)

| Parameter | Target |
|-----------|--------|
| **RPO (Recovery Point Objective)** | 4 часа |
| **RTO (Recovery Time Objective)** | 1 час |

---

## 5. Summary for Architecture Design

### Key Architecture Drivers
1. **Event-driven architecture** — обработка событий из внешних систем
2. **Multi-tenant channels** — три различных канала с разными ролями
3. **Integration-heavy** — внешние провайдеры наград и платёжный шлюз
4. **AI/ML components** — субагенты с guardrails
5. **Compliance & Audit** — журналирование всех действий, explainability
6. **High availability** — строгие SLO по latency и доступности
7. **Financial operations** — Rewards Bank Account с балансами

### Critical Quality Attributes
- **Performance**: E2E latency 100-200ms
- **Reliability**: <1% lost rewards
- **Security**: PII protection, prompt injection defense
- **Auditability**: Full audit trail for all user actions
- **Scalability**: 1000 avg / 100 000 peak events

### Integration Points
- BSS/OSS (event source, source of truth)
- EdTech VAS (event source)
- Reward Providers (create/redeem/cancel/status)
- Payment Gateway (payout/refund)

---

*This summary was automatically extracted from task.docx for architecture development purposes.*
