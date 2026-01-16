/* Проект «Секреты Тёмнолесья»
 
/* Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
на покупку внутриигровой валюты «райские лепестки», а также оценить 
активность игроков при совершении внутриигровых покупок.
*/

/* =========================================================
   Часть 1. Исследовательский анализ данных
   ========================================================= */

/* ---------------------------------------------------------
   Задача 1. Исследование доли платящих игроков
   --------------------------------------------------------- */

/* 1.1. Доля платящих пользователей по всем данным */
SELECT 
    COUNT(id) AS total_user_count,           -- общее количество игроков в игре
    SUM(payer) AS pay_user_count,             -- количество платящих игроков
    ROUND(AVG(payer), 2) AS pay_user_share    -- доля платящих игроков от общего количества
FROM fantasy.users;


/* 1.2. Доля платящих пользователей в разрезе расы персонажа */
SELECT DISTINCT 
    r.race,
    SUM(u.payer) OVER (PARTITION BY r.race) AS pay_user_count,         -- количество платящих игроков для каждой расы
    COUNT(u.id) OVER (PARTITION BY r.race) AS total_user_count,        -- общее количество игроков для каждой расы
    ROUND(AVG(u.payer) OVER (PARTITION BY r.race), 2) AS pay_user_share -- доля платящих игроков по расам
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r USING (race_id)
ORDER BY 2 DESC;


/* ---------------------------------------------------------
   Задача 2. Исследование внутриигровых покупок
   --------------------------------------------------------- */

/* 2.1. Статистические показатели по полю amount */
SELECT 
    COUNT(transaction_id) AS total_user_count,            -- общее количество покупок
    SUM(amount) AS total_user_amount,                      -- суммарная стоимость всех покупок
    MIN(amount) AS min_amount,                             -- минимальная стоимость покупки
    MAX(amount) AS max_amount,                             -- максимальная стоимость покупки
    ROUND(AVG(amount)::numeric, 2) AS avg_amount,          -- средняя стоимость покупки
    PERCENTILE_DISC(0.5) 
        WITHIN GROUP (ORDER BY amount) AS mediana_amount,  -- медиана стоимости покупки
    ROUND(STDDEV(amount)::numeric, 2) AS stand_dev_amount  -- стандартное отклонение
FROM fantasy.events;


/* 2.2. Аномальные нулевые покупки */
SELECT 
    COUNT(transaction_id) AS zero_amount_purchases,        -- количество покупок с нулевой стоимостью
    ROUND(
        COUNT(transaction_id)::numeric /
        (SELECT COUNT(amount) FROM fantasy.events),
        4
    ) AS zero_amount_share                                  -- доля нулевых покупок от общего числа
FROM fantasy.events
WHERE amount = 0;


/* 2.3. Сравнительный анализ активности платящих и неплатящих игроков */
SELECT 
    CASE
        WHEN u.payer = 1 THEN 'Платящие игроки'
        ELSE 'Неплатящие игроки'
    END AS type_player,                                     -- категория игроков
    COUNT(DISTINCT u.id) AS total_count_users,              -- общее количество игроков
    ROUND(
        COUNT(e.transaction_id)::numeric /
        COUNT(DISTINCT u.id),
        2
    ) AS avg_purchases,                                     -- среднее количество покупок на игрока
    ROUND(
        SUM(e.amount)::numeric /
        COUNT(DISTINCT u.id),
        2
    ) AS avg_amount                                         -- средняя сумма покупок на игрока
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e 
       ON u.id = e.id
      AND e.amount > 0                                      -- исключаем нулевые покупки
GROUP BY u.payer
ORDER BY u.payer;


/* 2.4. Популярные эпические предметы */
WITH item_stats AS (
    SELECT 
        i.game_items,                       -- название эпического предмета
        COUNT(*) AS item_count,              -- общее количество покупок предмета
        COUNT(DISTINCT e.id) AS unique_buyers -- количество уникальных покупателей
    FROM fantasy.events AS e
    JOIN fantasy.users AS u USING (id)
    JOIN fantasy.items AS i USING (item_code)
    WHERE e.amount > 0                       -- исключаем нулевые покупки
    GROUP BY i.game_items
),
active_users AS (
    SELECT 
        COUNT(DISTINCT id) AS total_active_users -- количество активных игроков
    FROM fantasy.events
    WHERE amount > 0
)
SELECT 
    s.game_items,
    s.item_count,
    ROUND(
        s.item_count::numeric /
        SUM(s.item_count) OVER (),
        4
    ) AS item_share,                          -- доля продаж предмета от всех продаж
    ROUND(
        s.unique_buyers::numeric /
        (SELECT total_active_users FROM active_users),
        4
    ) AS user_share                           -- доля игроков, покупавших предмет
FROM item_stats AS s
ORDER BY user_share DESC;


/* =========================================================
   Часть 2. Решение ad hoc-задач
   ========================================================= */

/* ---------------------------------------------------------
   Задача 1. Зависимость активности игроков от расы персонажа
   --------------------------------------------------------- */

WITH base AS (                                   -- базовая таблица
    SELECT 
        u.id,
        u.payer,
        r.race,
        e.transaction_id,
        e.amount
    FROM fantasy.users AS u
    JOIN fantasy.race AS r USING (race_id)
    LEFT JOIN fantasy.events AS e USING (id)
),
counts AS (
    SELECT 
        race,                                   -- название расы персонажа
        COUNT(DISTINCT id) AS unique_players,   -- общее количество уникальных игроков
        COUNT(
            DISTINCT CASE
                WHEN amount > 0 THEN id
            END
        ) AS unique_buy_players,                -- игроки, совершившие хотя бы одну покупку
        COUNT(
            DISTINCT CASE
                WHEN amount > 0
                 AND payer = 1 THEN id
            END
        ) AS unique_pay_players,                -- платящие игроки, совершавшие покупки
        COUNT(
            CASE
                WHEN amount > 0 THEN transaction_id
            END
        ) AS total_purchases,                   -- общее количество покупок по расе
        SUM(amount) AS total_amount             -- сумма всех покупок по расе
    FROM base
    GROUP BY race
)
SELECT 
    race,
    unique_players,
    unique_buy_players,
    unique_pay_players,
    ROUND(
        unique_buy_players::numeric / unique_players,
        2
    ) AS buy_players_share,                     -- доля игроков с покупками
    ROUND(
        unique_pay_players::numeric / unique_buy_players,
        2
    ) AS pay_players_share,                     -- доля платящих среди покупающих
    ROUND(
        total_purchases::numeric / unique_buy_players,
        2
    ) AS avg_cnt_per_player,                    -- среднее число покупок на покупающего игрока
    ROUND(
        total_amount::numeric / total_purchases,
        2
    ) AS avg_amn_per_purchase,                  -- средняя стоимость одной покупки
    ROUND(
        total_amount::numeric / unique_buy_players,
        2
    ) AS avg_total_amn_per_player               -- средняя сумма покупок на игрока
FROM counts
ORDER BY avg_total_amn_per_player DESC;


/* ---------------------------------------------------------
   Задача 2. Частота покупок
   --------------------------------------------------------- */

WITH days AS (
    SELECT 
        e.id,
        e.transaction_id,
        e.amount,
        u.payer,
        e.date::date 
        - LAG(e.date::date) 
          OVER (PARTITION BY e.id ORDER BY e.date)
        AS days_between                          -- разница в днях между покупками
    FROM fantasy.events AS e
    JOIN fantasy.users AS u USING (id)
    WHERE e.amount > 0
),
base AS (
    SELECT 
        id,
        payer,
        COUNT(transaction_id) AS total_purchases,             -- всего покупок у игрока
        ROUND(
            AVG(days_between)::numeric,
            2
        ) AS avg_days_between_purchases                         -- средний интервал между покупками
    FROM days
    GROUP BY id, payer
),
rank_players AS (
    SELECT *,
        NTILE(3) OVER (
            ORDER BY avg_days_between_purchases
        ) AS group_rank                                        -- деление игроков на 3 группы по частоте
    FROM base
    WHERE total_purchases >= 25
)
SELECT 
    CASE
        WHEN group_rank = 1 THEN 'высокая частота'
        WHEN group_rank = 2 THEN 'умеренная частота'
        ELSE 'низкая частота'
    END AS group_rank,                                         -- название группы
    COUNT(id) AS total_players,                                -- общее количество игроков
    SUM(
        CASE
            WHEN payer = 1 THEN 1
            ELSE 0
        END
    ) AS pay_players,                                          -- количество платящих игроков
    ROUND(
        AVG(
            CASE
                WHEN payer = 1 THEN 1
                ELSE 0
            END
        )::numeric,
        2
    ) AS pay_players_share,                                    -- доля платящих игроков
    ROUND(
        SUM(total_purchases)::numeric / COUNT(id),
        2
    ) AS avg_purchases_per_player,                             -- среднее число покупок на игрока
    ROUND(
        SUM(avg_days_between_purchases)::numeric / COUNT(id),
        2
    ) AS avg_days_per_player                                   -- средний интервал между покупками
FROM rank_players
GROUP BY group_rank
ORDER BY group_rank;
