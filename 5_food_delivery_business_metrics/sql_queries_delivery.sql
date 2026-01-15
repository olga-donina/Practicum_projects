/* Проект: Анализ ключевых бизнес-метрик сервиса доставки еды «Всё.из.кафе»

/* 
Задача 1. Расчёт DAU (Daily Active Users)
Описание:
Подсчёт ежедневного количества активных зарегистрированных клиентов,
совершивших заказ, в городе Саранск за май–июнь 2021 года.
*/

SELECT
    ae.log_date                          AS log_date,   -- дата события
    COUNT(DISTINCT ae.user_id)           AS dau        -- количество активных пользователей
FROM analytics_events AS ae
JOIN cities AS c
    ON ae.city_id = c.city_id
WHERE c.city_name = 'Саранск'            -- фильтр по городу
  AND ae.event = 'order'                 -- критерий активности: размещение заказа
  AND ae.log_date BETWEEN '2021-05-01' 
                      AND '2021-06-30'   -- период анализа
GROUP BY ae.log_date
ORDER BY ae.log_date;

/*
Задача 2. Расчёт Conversion Rate (CR)
Описание:
Расчёт ежедневной конверсии зарегистрированных пользователей,
посетивших приложение, в активных клиентов (совершивших заказ).
*/

SELECT
    ae.log_date AS log_date,   -- дата события
    ROUND(
        (COUNT(DISTINCT user_id) FILTER (WHERE ae.event = 'order'))
        / COUNT(DISTINCT user_id)::numeric,
        2
    ) AS CR                    -- значение конверсии
FROM analytics_events AS ae
JOIN cities AS c
    ON ae.city_id = c.city_id
WHERE c.city_name = 'Саранск'  -- фильтр по городу
  AND ae.log_date BETWEEN '2021-05-01'
                      AND '2021-06-30'  -- период анализа
GROUP BY ae.log_date
ORDER BY ae.log_date;

/*
Задача 3. Расчёт среднего чека
Описание:
Средний чек = сумма комиссии со всех заказов / количество заказов
*/

WITH orders AS (
    SELECT
        ae.log_date,
        ae.order_id,
        ae.revenue * ae.commission AS commission_revenue
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE ae.revenue IS NOT NULL               -- только заказы с выручкой
      AND ae.log_date BETWEEN '2021-05-01'
                          AND '2021-06-30'     -- период анализа
      AND c.city_name = 'Саранск'              -- фильтр по городу
)

SELECT
    DATE_TRUNC('month', log_date)::date        AS "Месяц",
    COUNT(DISTINCT order_id)                   AS "Количество заказов",
    ROUND(SUM(commission_revenue)::numeric, 2) AS "Сумма комиссии",
    ROUND(
        SUM(commission_revenue)::numeric
        / COUNT(DISTINCT order_id),
        2
    )                                          AS "Средний чек"
FROM orders
GROUP BY DATE_TRUNC('month', log_date)::date
ORDER BY DATE_TRUNC('month', log_date)::date;

/*
Задача 4. Расчёт LTV ресторанов
Описание:
Определение трёх ресторанных сетей из города Саранск
с наибольшим LTV за период с мая по июнь 2021 года.

LTV ресторана = суммарная комиссия сервиса,
полученная со всех заказов ресторана за период.
*/

WITH orders AS (
    SELECT
        ae.rest_id,
        ae.city_id,
        ae.revenue * ae.commission AS commission_revenue
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE ae.revenue IS NOT NULL               -- учитываем только заказы с выручкой
      AND ae.log_date BETWEEN '2021-05-01'
                          AND '2021-06-30'     -- период анализа
      AND c.city_name = 'Саранск'              -- фильтр по городу
)

SELECT
    o.rest_id                                 AS rest_id,
    p.chain                                   AS "Название сети",
    p.type                                    AS "Тип кухни",
    ROUND(SUM(o.commission_revenue)::numeric, 2) AS LTV
FROM orders AS o
LEFT JOIN partners AS p
    ON o.rest_id = p.rest_id
   AND o.city_id = p.city_id
GROUP BY
    o.rest_id,
    p.chain,
    p.type
ORDER BY LTV DESC
LIMIT 3;

/*
Задача 5. LTV ресторанов — самые популярные блюда
Описание:
Определение пяти самых популярных блюд двух ресторанов с наибольшим LTV
в городе Саранск за май–июнь 2021 года.

LTV блюда = суммарная комиссия сервиса, полученная с заказов блюда.
*/

WITH orders AS (
    SELECT
        ae.rest_id,
        ae.city_id,
        ae.object_id,                          -- уникальный идентификатор блюда
        ae.revenue * ae.commission AS commission_revenue
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE ae.revenue IS NOT NULL               -- учитываем только заказы с выручкой
      AND ae.log_date BETWEEN '2021-05-01'
                          AND '2021-06-30'
      AND c.city_name = 'Саранск'             -- фильтр по городу
),

-- Находим два ресторана с наибольшим LTV за период
top_ltv_restaurants AS (
    SELECT
        o.rest_id,
        p.chain,
        p.type,
        ROUND(SUM(o.commission_revenue)::numeric, 2) AS LTV
    FROM orders AS o
    JOIN partners AS p
        ON o.rest_id = p.rest_id
       AND o.city_id = p.city_id
    GROUP BY o.rest_id, p.chain, p.type
    ORDER BY LTV DESC
    LIMIT 2
)

-- Рассчитываем LTV по блюдам двух лидирующих ресторанов
SELECT
    tr.chain                                   AS "Название сети",
    d.name                                     AS "Название блюда",
    d.spicy                                    AS spicy,
    d.fish                                     AS fish,
    d.meat                                     AS meat,
    ROUND(SUM(o.commission_revenue)::numeric, 2) AS LTV
FROM top_ltv_restaurants AS tr
JOIN dishes AS d
    ON tr.rest_id = d.rest_id                   -- связываем блюда с ресторанами
JOIN orders AS o
    ON o.object_id = d.object_id
   AND o.rest_id = d.rest_id                    -- связываем заказы с блюдами
GROUP BY tr.chain, d.name, d.spicy, d.fish, d.meat
ORDER BY LTV DESC
LIMIT 5;                                       -- выбираем пять самых популярных блюд

/*
Задача 6. Расчёт Retention Rate
Описание:
Определение недельного Retention Rate для новых пользователей в Саранске
за май–июнь 2021 года.

Retention Rate = доля пользователей, вернувшихся в приложение
в конкретный день после первой активности (first_date),
относительно общего числа новых пользователей.
*/

-- Шаг 1: Выбираем новых пользователей за период
WITH new_users AS (
    SELECT DISTINCT
        first_date,       -- дата первого посещения
        user_id
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'  -- ограничиваем неделю для корректного расчёта
      AND c.city_name = 'Саранск'
),

-- Шаг 2: Выбираем все активные сессии пользователей за период
active_users AS (
    SELECT DISTINCT
        log_date,
        user_id
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND c.city_name = 'Саранск'
),

-- Шаг 3: Рассчитываем количество дней с момента установки для каждой активности
daily_retention AS (
    SELECT
        n.user_id,
        n.first_date,
        a.log_date::date - n.first_date::date AS day_since_install
    FROM new_users AS n
    JOIN active_users AS a
        ON n.user_id = a.user_id
    WHERE a.log_date >= n.first_date
)

-- Шаг 4: Рассчитываем Retention Rate по дням первой недели
SELECT
    dr.day_since_install,
    COUNT(DISTINCT dr.user_id) AS retained_users,
    ROUND(
        COUNT(DISTINCT dr.user_id)::numeric
        / (SELECT COUNT(DISTINCT user_id) FROM new_users),
        2
    ) AS retention_rate
FROM daily_retention AS dr
WHERE dr.day_since_install < 8   -- только первые 7 дней
GROUP BY dr.day_since_install
ORDER BY dr.day_since_install;

/*
Задача 7. Сравнение Retention Rate по месяцам
Описание:
Сравнение недельного Retention Rate для когорт пользователей,
разделённых по месяцу первого посещения продукта в Саранске.

Метрика:
- Retention Rate = доля пользователей, вернувшихся в приложение
  в конкретный день после первой активности, относительно числа
  пользователей, установивших приложение в день регистрации.
*/

-- Шаг 1: Выбираем новых пользователей за период
WITH new_users AS (
    SELECT DISTINCT
        first_date,       -- дата первого посещения
        user_id
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE first_date BETWEEN '2021-05-01' AND '2021-06-24'  -- ограничение для корректного расчёта недельного Retention
      AND c.city_name = 'Саранск'
),

-- Шаг 2: Выбираем все активные сессии пользователей за период
active_users AS (
    SELECT DISTINCT
        log_date,
        user_id
    FROM analytics_events AS ae
    JOIN cities AS c
        ON ae.city_id = c.city_id
    WHERE log_date BETWEEN '2021-05-01' AND '2021-06-30'
      AND c.city_name = 'Саранск'
),

-- Шаг 3: Рассчитываем день жизни пользователя (day_since_install)
daily_retention AS (
    SELECT
        n.user_id,
        n.first_date,
        a.log_date::date - n.first_date::date AS day_since_install
    FROM new_users AS n
    JOIN active_users AS a
        ON n.user_id = a.user_id
    WHERE a.log_date >= n.first_date
)

-- Шаг 4: Расчёт Retention Rate по когорте месяца регистрации
SELECT
    CAST(DATE_TRUNC('month', first_date) AS date) AS "Месяц",  -- месяц первой активности (когорта)
    day_since_install,
    COUNT(DISTINCT user_id) AS retained_users,
    ROUND(
        (COUNT(DISTINCT user_id)::numeric
         / MAX(COUNT(DISTINCT user_id)) OVER (
             PARTITION BY DATE_TRUNC('month', first_date) 
             ORDER BY day_since_install
         )
        ),
        2
    ) AS retention_rate
FROM daily_retention
WHERE day_since_install < 8    -- учитываем только первые 7 дней
GROUP BY "Месяц", day_since_install
ORDER BY "Месяц", day_since_install;



