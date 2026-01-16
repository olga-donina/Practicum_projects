/* Проект: Подготовка данных об использовании тарифных планов абонентами компании «Мегасеть»
 
/* Задачи проекта: 
Заказчик - команда продукта компании «Мегасеть» — федерального оператора сотовой связи. 
Нужно получить информацию, как абоненты пользуются услугами компании с точки зрения двух тарифных планов:
- Выгрузить данные абонентов с информацией о ежемесячных объёмах услуг 
- Для каждого тарифного плана рассчитать среднее значение трат клиентов на услуги связи
- Среди действующих активных абонентов найти тех, кто пользуется услугами сверх тарифа, 
  и посчитать их средние расходы и среднее значение переплаты для каждого тарифа.
*/

/* =============================================================
   Часть 1. Первичное знакомство с данными и проверка на ошибки
   ============================================================= */

/* ---------------------------------------------------------
   Задача 1. Первичный обзор данных об абонентах
   --------------------------------------------------------- */

/* Просмотр первых 20 строк таблицы users */
SELECT *
FROM telecom.users
LIMIT 20;


/* ---------------------------------------------------------
   Задача 2. Проверка данных об абонентах на пропуски
   --------------------------------------------------------- */

/* Поиск строк с пропущенными значениями (кроме user_id) */
SELECT *
FROM telecom.users
WHERE age IS NULL
   OR churn_date IS NULL
   OR city IS NULL
   OR first_name IS NULL
   OR last_name IS NULL
   OR reg_date IS NULL
   OR tariff IS NULL
LIMIT 10;


/* ---------------------------------------------------------
   Задача 3. Определение доли активных абонентов
   --------------------------------------------------------- */

/* Расчёт доли абонентов без даты отказа от услуг */
SELECT 
    1 - COUNT(churn_date)::real / COUNT(*) AS active_users_share
FROM telecom.users;


/* ---------------------------------------------------------
   Задача 4. Проверка уникальности тарифного плана
   --------------------------------------------------------- */

/* Поиск активных абонентов с более чем одним тарифом */
SELECT 
    user_id,
    COUNT(DISTINCT tariff) AS tariff_count
FROM telecom.users
WHERE churn_date IS NULL
GROUP BY user_id
HAVING COUNT(DISTINCT tariff) > 1;


/* ---------------------------------------------------------
   Задача 5. Проверка пропусков в данных о звонках
   --------------------------------------------------------- */

/* Поиск пропусков в длительности звонков и дате вызова */
SELECT *
FROM telecom.calls
WHERE duration IS NULL
   OR call_date IS NULL;


/* ---------------------------------------------------------
   Задача 6. Поиск аномалий в длительности звонков
   --------------------------------------------------------- */

/* Минимальная и максимальная длительность разговоров */
SELECT 
    MIN(duration) AS min_duration,
    MAX(duration) AS max_duration
FROM telecom.calls;


/* ---------------------------------------------------------
   Задача 7. Анализ доли звонков нулевой длительности
   --------------------------------------------------------- */

/* Доля звонков с длительностью 0 минут */
SELECT
    COUNT(*) FILTER (WHERE duration = 0)::real / COUNT(*) AS zero_duration_calls_share
FROM telecom.calls;


/* ---------------------------------------------------------
   Задача 8. Проверка суммарной длительности звонков в день
   --------------------------------------------------------- */

/* Топ-10 абонентов по суммарной длительности звонков за день */
SELECT 
    user_id,
    call_date,
    SUM(duration) / 60.0 AS total_day_duration
FROM telecom.calls
GROUP BY user_id, call_date
ORDER BY total_day_duration DESC
LIMIT 10;



/* =========================================================
   Часть 2. Расчет статистики для каждого абонента
   ========================================================= */

/* ---------------------------------------------------------
   Задача 1. Длительность разговоров абонентов по месяцам
   --------------------------------------------------------- */

/* Описание:
Для каждого абонента вычисляем суммарную длительность всех звонков за месяц.
При этом длительность округляется вверх до целого числа (как это делает оператор для выставления счета).
Результат содержит:
user_id       - идентификатор абонента
dt_month      - месяц статистики (формат YYYY-MM-01)
month_duration- суммарная длительность звонков за месяц 
*/

/* Пример вывода:
| user_id | dt_month   | month_duration |
|---------|------------|----------------|
| 1366    | 2018-11-01 | 240            |
| 1366    | 2018-09-01 | 144            |
| 1378    | 2018-05-01 | 498            |
| 1186    | 2018-03-01 | 388            |
| 1104    | 2018-10-01 | 316            |
*/

-- Создаем обобщённое табличное выражение (CTE)
WITH monthly_duration AS (
    SELECT
        user_id,
        -- Обрезаем дату звонка до первого числа месяца
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        -- Суммируем длительность звонков и округляем вверх
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
)

-- Основной запрос для проверки: выводим первые 5 строк
SELECT *
FROM monthly_duration
LIMIT 5;


/* ---------------------------------------------------------
   Задача 2. Количество интернет-трафика в месяц
   --------------------------------------------------------- */

/* Описание:
Для каждого абонента вычисляем суммарное количество потраченного интернет-трафика за месяц.
Результат содержит:
user_id           - идентификатор абонента
dt_month          - месяц статистики (формат YYYY-MM-01)
month_mb_traffic  - суммарное количество мегабайтов, использованных в этом месяце
*/

/* Пример вывода:
| user_id | dt_month   | month_mb_traffic |
|---------|------------|-----------------|
| 1366    | 2018-11-01 | 8583.74         |
| 1366    | 2018-09-01 | 7545            |
| 1378    | 2018-05-01 | 14269.9         |
| 1186    | 2018-03-01 | 16783.9         |
| 1104    | 2018-10-01 | 18642.3         |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        -- Обрезаем дату звонка до первого числа месяца
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        -- Суммируем длительность звонков и округляем вверх
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        -- Обрезаем дату сессии до первого числа месяца
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        -- Суммируем мегабайты интернет-трафика
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet 
    GROUP BY user_id, dt_month
)

-- Основной запрос для проверки: выводим первые 5 строк
SELECT *
FROM monthly_internet
LIMIT 5;



/* ---------------------------------------------------------
   Задача 3. Количество сообщений в месяц
   --------------------------------------------------------- */

/* Описание:
Для каждого абонента вычисляем суммарное количество отправленных сообщений за месяц.
Результат содержит:
user_id    - идентификатор абонента
dt_month   - месяц статистики (формат YYYY-MM-01)
month_sms  - суммарное количество сообщений, отправленных в этом месяце
*/

/* Пример вывода:
| user_id | dt_month   | month_sms |
|---------|------------|-----------|
| 1012    | 2018-11-01 | 25        |
| 1366    | 2018-11-01 | 42        |
| 1366    | 2018-09-01 | 39        |
| 1378    | 2018-05-01 | 14        |
| 1471    | 2018-11-01 | 92        |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(id) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
)

-- Основной запрос для проверки: выводим первые 5 строк
SELECT *
FROM monthly_sms
LIMIT 5;



/* ---------------------------------------------------------
   Задача 4. Соединяем данные об абонентах и их месячную активность
   --------------------------------------------------------- */

/* Описание:
Объединяем ежемесячную активность абонентов по всем услугам: звонки, интернет, сообщения.
Для каждого абонента и месяца создаём уникальные комбинации user_id и dt_month,
чтобы не потерять активность абонентов, даже если они пользовались только одной из услуг.
Результат содержит:
user_id   - идентификатор абонента
dt_month  - месяц активности (формат YYYY-MM-01)
*/

/* Пример вывода:
| user_id | dt_month   |
|---------|------------|
| 1000    | 2018-05-01 |
| 1000    | 2018-06-01 |
| 1000    | 2018-07-01 |
| 1000    | 2018-08-01 |
| 1000    | 2018-09-01 |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),

-- Уникальные комбинации user_id и dt_month с учётом любой активности
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    WHERE month_duration > 0
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet
    WHERE month_mb_traffic > 0
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
    WHERE month_sms > 0
)

-- Основной запрос для проверки: выводим первые 5 строк
SELECT *
FROM user_activity_months
ORDER BY user_id, dt_month
LIMIT 5;



/* ---------------------------------------------------------
   Задача 5. Объединяем данные об абонентах в одну таблицу
   --------------------------------------------------------- */

/* Описание:
Объединяем ежемесячную активность абонентов по всем услугам (звонки, интернет, сообщения)
в одну таблицу. Для каждого абонента и месяца получаем:
- суммарную длительность звонков,
- суммарное количество потраченных мегабайтов интернет-трафика,
- суммарное количество отправленных сообщений.
Результат содержит:
user_id          - идентификатор абонента
dt_month         - месяц статистики (формат YYYY-MM-01)
month_duration   - суммарная длительность звонков
month_mb_traffic - суммарный интернет-трафик в мегабайтах
month_sms        - суммарное количество сообщений
*/

/* Пример вывода:
| user_id | dt_month   | month_duration | month_mb_traffic | month_sms |
|---------|------------|----------------|-----------------|-----------|
| 1000    | 2018-05-01 | 151            | 2253.49         | 22        |
| 1000    | 2018-06-01 | 159            | 23233.8         | 62        |
| 1000    | 2018-07-01 | 319            | 14003.6         | 75        |
| 1000    | 2018-08-01 | 390            | 14055.9         | 81        |
| 1000    | 2018-09-01 | 441            | 14568.9         | 57        |
| 1000    | 2018-10-01 | 329            | 14702.5         | 73        |
| 1000    | 2018-11-01 | 320            | 14756.5         | 58        |
| 1000    | 2018-12-01 | 313            | 9817.61         | 70        |
| 1001    | 2018-11-01 | 409            | 18429.3         | nan       |
| 1001    | 2018-12-01 | 392            | 14036.7         | nan       |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),

-- Формирование уникальной пары user_id и dt_month
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),

-- Объединяем все показатели активности в одну таблицу
users_stat AS (
    SELECT
        uam.user_id AS user_id,
        uam.dt_month AS dt_month,
        md.month_duration AS month_duration,
        mi.month_mb_traffic AS month_mb_traffic,
        ms.month_sms AS month_sms
    FROM user_activity_months AS uam
    LEFT JOIN monthly_duration AS md
        ON uam.user_id = md.user_id AND uam.dt_month = md.dt_month
    LEFT JOIN monthly_internet AS mi
        ON uam.user_id = mi.user_id AND uam.dt_month = mi.dt_month
    LEFT JOIN monthly_sms AS ms
        ON uam.user_id = ms.user_id AND uam.dt_month = ms.dt_month
)

-- Основной запрос для проверки: выводим первые 10 строк
SELECT *
FROM users_stat
ORDER BY user_id, dt_month
LIMIT 10;



/* ---------------------------------------------------------
   Задача 6. Траты абонентов вне тарифного лимита
   --------------------------------------------------------- */

/* Описание:
Для каждого абонента рассчитываем, сколько услуг было использовано сверх тарифного пакета.
Используем информацию о тарифах и посчитанные значения по звонкам, интернет-трафику и сообщениям.
Результат содержит:
user_id          - идентификатор абонента
dt_month         - месяц статистики (формат YYYY-MM-01)
tariff           - название тарифного плана абонента
month_duration   - суммарная длительность звонков
month_mb_traffic - суммарный интернет-трафик в мегабайтах
month_sms        - суммарное количество сообщений
duration_over    - превышение лимита минут звонков
gb_traffic_over  - превышение лимита интернет-трафика в гигабайтах
sms_over         - превышение лимита сообщений
*/

/* Пример вывода:
| user_id | dt_month   | tariff | month_duration | month_mb_traffic | month_sms | duration_over | gb_traffic_over | sms_over |
|---------|------------|--------|----------------|-----------------|-----------|---------------|----------------|----------|
| 1000    | 2018-05-01 | ultra  | 151            | 2253.49         | 22        | 0             | 0              | 0        |
| 1000    | 2018-06-01 | ultra  | 159            | 23233.8         | 62        | 0             | 0              | 0        |
| 1000    | 2018-07-01 | ultra  | 319            | 14003.6         | 75        | 0             | 0              | 0        |
| 1000    | 2018-08-01 | ultra  | 390            | 14055.9         | 81        | 0             | 0              | 0        |
| 1000    | 2018-09-01 | ultra  | 441            | 14568.9         | 57        | 0             | 0              | 0        |
| 1000    | 2018-10-01 | ultra  | 329            | 14702.5         | 73        | 0             | 0              | 0        |
| 1000    | 2018-11-01 | ultra  | 320            | 14756.5         | 58        | 0             | 0              | 0        |
| 1000    | 2018-12-01 | ultra  | 313            | 9817.61         | 70        | 0             | 0              | 0        |
| 1001    | 2018-11-01 | smart  | 409            | 18429.3         | nan       | 0             | 2.9974         | 0        |
| 1001    | 2018-12-01 | smart  | 392            | 14036.7         | nan       | 0             | 0              | 0        |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),

-- Формирование уникальной пары user_id и dt_month
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),

-- Объединяем все показатели активности в одну таблицу
users_stat AS (
    SELECT 
        uam.user_id,
        uam.dt_month,
        md.month_duration,
        mi.month_mb_traffic,
        mm.month_sms
    FROM user_activity_months AS uam
    LEFT JOIN monthly_duration AS md
        ON uam.user_id = md.user_id AND uam.dt_month = md.dt_month
    LEFT JOIN monthly_internet AS mi
        ON uam.user_id = mi.user_id AND uam.dt_month = mi.dt_month
    LEFT JOIN monthly_sms AS mm
        ON uam.user_id = mm.user_id AND uam.dt_month = mm.dt_month
),

-- Расчёт превышений по тарифным лимитам
user_over_limits AS (
    SELECT 
        u.user_id,
        us.dt_month,
        u.tariff,
        us.month_duration,
        us.month_mb_traffic,
        us.month_sms,
        CASE
            WHEN us.month_duration > t.minutes_included
                THEN us.month_duration - t.minutes_included
            ELSE 0
        END AS duration_over,
        CASE
            WHEN us.month_mb_traffic > t.mb_per_month_included
                THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024
            ELSE 0
        END AS gb_traffic_over,
        CASE
            WHEN us.month_sms > t.messages_included
                THEN us.month_sms - t.messages_included
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    JOIN telecom.users AS u
        USING (user_id)
    JOIN telecom.tariffs AS t
        ON u.tariff = t.tariff_name
)

-- Основной запрос для проверки: выводим первые 10 строк
SELECT *
FROM user_over_limits
ORDER BY user_id, dt_month
LIMIT 10;



/* =========================================================
   Часть 3. Расчеты для заказчика
   ========================================================= */

/* ---------------------------------------------------------
   Задача 1. Траты абонентов по месяцам
   --------------------------------------------------------- */

/* Описание:
Для каждого абонента вычисляем его ежемесячные траты с учетом тарифного плана.
Используем данные о фактическом использовании услуг и тарифные лимиты.
Результат содержит:
user_id          - идентификатор абонента
dt_month         - месяц статистики (формат YYYY-MM-01)
tariff           - название тарифного плана
month_duration   - суммарная длительность всех звонков
month_mb_traffic - суммарный интернет-трафик в мегабайтах
month_sms        - суммарное количество сообщений
rub_monthly_fee  - абонентская плата по тарифу
total_cost       - общие траты абонента в этом месяце (абонентская плата + перерасход по услугам)
*/

/* Пример вывода:
| user_id | dt_month   | tariff | month_duration | month_mb_traffic | month_sms | rub_monthly_fee | total_cost |
|---------|------------|--------|----------------|-----------------|-----------|----------------|------------|
| 1000    | 2018-05-01 | ultra  | 151            | 2253.49         | 22        | 1950           | 1950       |
| 1000    | 2018-06-01 | ultra  | 159            | 23233.8         | 62        | 1950           | 1950       |
| 1000    | 2018-07-01 | ultra  | 319            | 14003.6         | 75        | 1950           | 1950       |
| 1000    | 2018-08-01 | ultra  | 390            | 14055.9         | 81        | 1950           | 1950       |
| 1000    | 2018-09-01 | ultra  | 441            | 14568.9         | 57        | 1950           | 1950       |
| 1000    | 2018-10-01 | ultra  | 329            | 14702.5         | 73        | 1950           | 1950       |
| 1000    | 2018-11-01 | ultra  | 320            | 14756.5         | 58        | 1950           | 1950       |
| 1000    | 2018-12-01 | ultra  | 313            | 9817.61         | 70        | 1950           | 1950       |
| 1001    | 2018-11-01 | smart  | 409            | 18429.3         | nan       | 550            | 1149.48    |
| 1001    | 2018-12-01 | smart  | 392            | 14036.7         | nan       | 550            | 550        |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),

-- Формирование уникальной пары user_id и dt_month
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),

-- Объединяем все показатели активности в одну таблицу
users_stat AS (
    SELECT 
        uam.user_id,
        uam.dt_month,
        md.month_duration,
        mi.month_mb_traffic,
        mm.month_sms
    FROM user_activity_months AS uam
    LEFT JOIN monthly_duration AS md
        ON uam.user_id = md.user_id AND uam.dt_month = md.dt_month
    LEFT JOIN monthly_internet AS mi
        ON uam.user_id = mi.user_id AND uam.dt_month = mi.dt_month
    LEFT JOIN monthly_sms AS mm
        ON uam.user_id = mm.user_id AND uam.dt_month = mm.dt_month
),

-- Расчёт превышений тарифных лимитов
user_over_limits AS (
    SELECT 
        us.user_id,
        us.dt_month,
        u.tariff,
        us.month_duration,
        us.month_mb_traffic,
        us.month_sms,
        CASE 
            WHEN us.month_duration >= t.minutes_included THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included THEN (us.month_mb_traffic - t.mb_per_month_included) / 1024::real
            ELSE 0
        END AS gb_traffic_over,
        CASE 
            WHEN us.month_sms >= t.messages_included THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT user_id, tariff FROM telecom.users) AS u
        ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t
        ON u.tariff = t.tariff_name
),

-- Расчёт итоговой суммы траты абонента за месяц
users_costs AS (
    SELECT
        u.user_id,
        u.dt_month,
        u.tariff,
        u.month_duration,
        u.month_mb_traffic,
        u.month_sms,
        t.rub_monthly_fee,
        (t.rub_monthly_fee 
         + t.rub_per_minute * u.duration_over
         + t.rub_per_gb * u.gb_traffic_over
         + t.rub_per_message * u.sms_over) AS total_cost
    FROM user_over_limits AS u
    LEFT JOIN telecom.tariffs AS t
        ON u.tariff = t.tariff_name
)

-- Основной запрос для проверки: выводим первые 10 строк
SELECT *
FROM users_costs
ORDER BY user_id, dt_month
LIMIT 10;


/* ---------------------------------------------------------
   Задача 2. Средние траты активных абонентов
   --------------------------------------------------------- */

/* Описание:
Для каждого тарифного плана вычисляем:
- количество активных абонентов (абоненты, которые ещё не ушли с тарифов),
- средние ежемесячные траты на тариф с учётом перерасхода услуг.
Используем данные из CTE users_costs, рассчитанные в предыдущей задаче.
Результат содержит:
tariff         - название тарифного плана
total_users    - количество активных абонентов
avg_total_cost - средние ежемесячные траты абонентов по тарифу (округлены до 2 знаков)
*/

/* Пример вывода:
| tariff | total_users | avg_total_cost |
|--------|-------------|----------------|
| smart  | 328         | 1206.1         |
| ultra  | 134         | 2056.65        |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),

-- Формирование уникальной пары user_id и dt_month
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),

-- Объединяем все показатели активности в одну таблицу
users_stat AS (
    SELECT 
        uam.user_id,
        uam.dt_month,
        md.month_duration,
        mi.month_mb_traffic,
        mm.month_sms
    FROM user_activity_months AS uam
    LEFT JOIN monthly_duration AS md
        ON uam.user_id = md.user_id AND uam.dt_month = md.dt_month
    LEFT JOIN monthly_internet AS mi
        ON uam.user_id = mi.user_id AND uam.dt_month = mi.dt_month
    LEFT JOIN monthly_sms AS mm
        ON uam.user_id = mm.user_id AND uam.dt_month = mm.dt_month
),

-- Расчёт превышений тарифных лимитов
user_over_limits AS (
    SELECT 
        us.user_id,
        us.dt_month,
        u.tariff,
        us.month_duration,
        us.month_mb_traffic,
        us.month_sms,
        CASE 
            WHEN us.month_duration >= t.minutes_included THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included THEN (us.month_mb_traffic - t.mb_per_month_included)/1024::real
            ELSE 0
        END AS gb_traffic_over,
        CASE 
            WHEN us.month_sms >= t.messages_included THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT user_id, tariff FROM telecom.users) AS u
        ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t
        ON u.tariff = t.tariff_name
),

-- Траты абонента за каждый месяц
users_costs AS (
    SELECT 
        uol.user_id,
        uol.dt_month,
        uol.tariff,
        uol.month_duration,
        uol.month_mb_traffic,
        uol.month_sms,
        t.rub_monthly_fee, 
        t.rub_monthly_fee 
        + uol.duration_over * t.rub_per_minute
        + uol.gb_traffic_over * t.rub_per_gb
        + uol.sms_over * t.rub_per_message AS total_cost
    FROM user_over_limits AS uol
    LEFT JOIN telecom.tariffs AS t
        ON uol.tariff = t.tariff_name
)

-- Основной запрос: средние траты активных абонентов по тарифу
SELECT 
    uc.tariff,
    COUNT(DISTINCT uc.user_id) AS total_users,
    ROUND(AVG(uc.total_cost::numeric), 2) AS avg_total_cost
FROM users_costs AS uc
JOIN telecom.users AS u
    USING (user_id)
WHERE u.churn_date IS NULL
GROUP BY uc.tariff;


/* ---------------------------------------------------------
   Задача 3. Активные абоненты и их траты
   --------------------------------------------------------- */

/* Описание:
Для каждого тарифного плана вычисляем:
- количество уникальных активных абонентов, чьи ежемесячные траты превышают абонентскую плату,
- средние ежемесячные траты этих абонентов,
- среднюю переплату по тарифу (разница между фактическими тратами и абонентской платой).
Используем данные из CTE users_costs, рассчитанные в предыдущей задаче.
Результат содержит:
tariff         - название тарифного плана
total_users    - количество абонентов с перерасходом
avg_total_cost - средние ежемесячные траты абонента по тарифу
overcost       - средняя переплата по тарифу
Все значения округлены до двух знаков после запятой.
*/

/* Пример вывода:
| tariff | total_users | avg_total_cost | overcost |
|--------|-------------|----------------|----------|
| smart  | 318         | 1433.42        | 883.42   |
| ultra  | 40          | 2731.79        | 781.79   |
*/

-- Суммарная длительность звонков абонента в месяц
WITH monthly_duration AS (
    SELECT
        user_id,
        DATE_TRUNC('month', call_date::timestamp)::date AS dt_month,
        CEIL(SUM(duration)) AS month_duration
    FROM telecom.calls
    GROUP BY user_id, dt_month
),

-- Суммарное количество интернет-трафика абонента в месяц
monthly_internet AS (
    SELECT
        user_id,
        DATE_TRUNC('month', session_date::timestamp)::date AS dt_month,
        SUM(mb_used) AS month_mb_traffic
    FROM telecom.internet
    GROUP BY user_id, dt_month
),

-- Суммарное количество сообщений абонента в месяц
monthly_sms AS (
    SELECT
        user_id,
        DATE_TRUNC('month', message_date::timestamp)::date AS dt_month,
        COUNT(message_date) AS month_sms
    FROM telecom.messages
    GROUP BY user_id, dt_month
),

-- Формирование уникальной пары user_id и dt_month
user_activity_months AS (
    SELECT user_id, dt_month
    FROM monthly_duration
    UNION
    SELECT user_id, dt_month
    FROM monthly_internet
    UNION
    SELECT user_id, dt_month
    FROM monthly_sms
),

-- Объединяем все показатели активности в одну таблицу
users_stat AS (
    SELECT 
        uam.user_id,
        uam.dt_month,
        md.month_duration,
        mi.month_mb_traffic,
        mm.month_sms
    FROM user_activity_months AS uam
    LEFT JOIN monthly_duration AS md
        ON uam.user_id = md.user_id AND uam.dt_month = md.dt_month
    LEFT JOIN monthly_internet AS mi
        ON uam.user_id = mi.user_id AND uam.dt_month = mi.dt_month
    LEFT JOIN monthly_sms AS mm
        ON uam.user_id = mm.user_id AND uam.dt_month = mm.dt_month
),

-- Расчёт превышений тарифных лимитов
user_over_limits AS (
    SELECT 
        us.user_id,
        us.dt_month,
        u.tariff,
        us.month_duration,
        us.month_mb_traffic,
        us.month_sms,
        CASE 
            WHEN us.month_duration >= t.minutes_included THEN (us.month_duration - t.minutes_included)
            ELSE 0
        END AS duration_over,
        CASE 
            WHEN us.month_mb_traffic >= t.mb_per_month_included THEN (us.month_mb_traffic - t.mb_per_month_included)/1024::real
            ELSE 0
        END AS gb_traffic_over,
        CASE 
            WHEN us.month_sms >= t.messages_included THEN (us.month_sms - t.messages_included)
            ELSE 0
        END AS sms_over
    FROM users_stat AS us
    LEFT JOIN (SELECT user_id, tariff FROM telecom.users) AS u
        ON us.user_id = u.user_id
    LEFT JOIN telecom.tariffs AS t
        ON u.tariff = t.tariff_name
),

-- Траты абонента за каждый месяц
users_costs AS (
    SELECT 
        uol.user_id,
        uol.dt_month,
        uol.tariff,
        uol.month_duration,
        uol.month_mb_traffic,
        uol.month_sms,
        t.rub_monthly_fee, 
        t.rub_monthly_fee 
        + uol.duration_over * t.rub_per_minute
        + uol.gb_traffic_over * t.rub_per_gb
        + uol.sms_over * t.rub_per_message AS total_cost
    FROM user_over_limits AS uol
    LEFT JOIN telecom.tariffs AS t
        ON uol.tariff = t.tariff_name
)

-- Основной запрос: активные абоненты с перерасходом
SELECT 
    uc.tariff,
    COUNT(DISTINCT uc.user_id) AS total_users,
    ROUND(AVG(uc.total_cost::numeric), 2) AS avg_total_cost,
    ROUND(AVG((uc.total_cost - uc.rub_monthly_fee)::numeric), 2) AS overcost
FROM users_costs AS uc
LEFT JOIN telecom.users AS u
    USING (user_id)
WHERE uc.total_cost > uc.rub_monthly_fee
  AND u.churn_date IS NULL
GROUP BY uc.tariff;
