/* Проект : Анализ данных для агентства недвижимости
/* =========================================================
   Часть 2. Ad hoc задачи
   ========================================================= */

/* ---------------------------------------------------------
   Фильтрация данных от аномальных значений (выбросов)
   --------------------------------------------------------- */
WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


/* ---------------------------------------------------------
   Задача 1: Время активности объявлений
   Анализ сегментов недвижимости по длительности активности,
   характеристикам квартир и регионам
   --------------------------------------------------------- */
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
base AS (
    SELECT 
        f.*, 
        a.days_exposition, 
        CASE
            WHEN c.city='Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,
        CASE
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'до 1 месяца'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'до 3 месяцев'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'до 6 месяцев'
            WHEN a.days_exposition > 180 THEN 'от 6 месяцев'
        END AS segment,
        a.last_price::numeric/f.total_area AS price_per_m2
    FROM real_estate.flats AS f
    JOIN real_estate.advertisement AS a USING(id)
    LEFT JOIN real_estate.type AS t USING(type_id)
    LEFT JOIN real_estate.city AS c USING(city_id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND t.type='город'
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
        AND a.days_exposition IS NOT NULL
)
SELECT 
    region,
    segment,
    COUNT(id) AS count_ads,
    ROUND(COUNT(id)::numeric / SUM(COUNT(id)) OVER (PARTITION BY region), 2) AS share_in_region,
    ROUND(AVG(price_per_m2)::numeric) AS avg_price_per_m2,
    ROUND(AVG(total_area)::numeric, 1) AS avg_total_area,
    ROUND(AVG(living_area)::numeric, 1) AS avg_living_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors_total,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS median_parks,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS median_ponds,
    ROUND(SUM(CASE WHEN rooms = 0 THEN 1 ELSE 0 END)::numeric / COUNT(id), 3) AS share_studio,
    ROUND(AVG(CASE WHEN rooms = 0 THEN total_area ELSE NULL END)::numeric, 1) AS avg_studio_area,
    ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
    ROUND(AVG(airports_nearest)::numeric/1000.0, 1) AS avg_distance_to_airport_km,
    ROUND(SUM(CASE WHEN is_apartment=1 THEN 1 ELSE 0 END)::numeric / COUNT(id), 3) AS share_apartment,
    ROUND(SUM(CASE WHEN open_plan=1 THEN 1 ELSE 0 END)::numeric / COUNT(id), 3) AS share_open_plan
FROM base
GROUP BY 1,2
ORDER BY 1 DESC, 2;


/* ---------------------------------------------------------
   Задача 2: Сезонность объявлений
   Анализ активности публикаций и снятий объявлений по месяцам
   --------------------------------------------------------- */
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
base AS (
    SELECT 
        a.id,
        a.first_day_exposition,
        a.first_day_exposition + a.days_exposition * INTERVAL '1 day' AS last_day_exposition,
        f.total_area,
        a.last_price / f.total_area AS price_per_m2
    FROM real_estate.flats AS f
    JOIN real_estate.advertisement AS a USING(id)  
    LEFT JOIN real_estate.type AS t USING(type_id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND t.type='город' 
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
        AND EXTRACT(YEAR FROM (a.first_day_exposition + a.days_exposition * INTERVAL '1 day')) BETWEEN 2015 AND 2018
),
base_public AS (
    SELECT 
        EXTRACT(month FROM first_day_exposition) AS month_pub,
        TO_CHAR(first_day_exposition, 'TMMonth') AS month_name,
        COUNT(id) AS ads_published,
        DENSE_RANK() OVER (ORDER BY COUNT(id) DESC) AS rank_pub,
        ROUND(AVG(price_per_m2)::numeric) AS avg_price_per_m2_pub,
        ROUND(AVG(total_area)::numeric, 1) AS avg_area_pub
    FROM base
    GROUP BY 1,2
),
base_delete AS (
    SELECT 
        EXTRACT(month FROM last_day_exposition) AS month_del,
        COUNT(id) AS ads_del,
        DENSE_RANK() OVER (ORDER BY COUNT(id) DESC) AS rank_del,
        ROUND(AVG(price_per_m2)::numeric) AS avg_price_per_m2_del,
        ROUND(AVG(total_area)::numeric, 1) AS avg_area_del
    FROM base
    GROUP BY 1
)
SELECT
    p.month_pub AS month_number,
    p.month_name,
    p.ads_published, 
    p.rank_pub,		
    d.ads_del,
    d.rank_del,
    p.avg_price_per_m2_pub,
    p.avg_area_pub,
    d.avg_price_per_m2_del,
    d.avg_area_del
FROM base_public AS p
FULL JOIN base_delete AS d ON p.month_pub=d.month_del	
ORDER BY 3 DESC;


/* ---------------------------------------------------------
   Задача 3: Анализ рынка недвижимости Ленобласти
   Выделение активных населённых пунктов и характеристик
   --------------------------------------------------------- */
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
base AS (
    SELECT
        f.*, 
        c.city,
        a.days_exposition, 
        a.last_price::numeric/f.total_area AS price_per_m2
    FROM real_estate.flats AS f
    JOIN real_estate.advertisement AS a USING(id)
    LEFT JOIN real_estate.city AS c USING(city_id) 
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
        AND c.city != 'Санкт-Петербург'
        AND ((EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
              OR EXTRACT(YEAR FROM (a.first_day_exposition + a.days_exposition * INTERVAL '1 day')) BETWEEN 2015 AND 2018))
),
gr_by_city AS (
    SELECT 
        city,
        COUNT(id) AS count_ads,
        COUNT(days_exposition) AS count_ads_del,
        ROUND(COUNT(days_exposition)::NUMERIC / COUNT(id), 2) AS share_ads_del,
        ROUND(AVG(price_per_m2)::numeric) AS avg_price_per_m2,
        ROUND(AVG(days_exposition)::NUMERIC/30.4,2) AS avg_time_del,
        ROUND(AVG(total_area)::numeric, 2) AS avg_total_area,
        ROUND(AVG(living_area)::numeric, 2) AS avg_living_area,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors_total,
        COALESCE(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY parks_around3000),0) AS median_parks,
        COALESCE(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ponds_around3000),0) AS median_ponds,
        COALESCE(ROUND(SUM(CASE WHEN rooms = 0 THEN 1 ELSE 0 END)::numeric / COUNT(id), 3),0) AS share_studio,
        COALESCE(ROUND(AVG(CASE WHEN rooms = 0 THEN total_area ELSE NULL END)::numeric, 1),0) AS avg_studio_area,
        ROUND(AVG(ceiling_height)::numeric, 2) AS avg_ceiling_height,
        COALESCE(ROUND(SUM(CASE WHEN is_apartment=1 THEN 1 ELSE 0 END)::numeric / COUNT(id), 3),0) AS share_apartment,
        COALESCE(ROUND(SUM(CASE WHEN open_plan=1 THEN 1 ELSE 0 END)::numeric / COUNT(id), 3),0) AS share_open_plan
    FROM base
    GROUP BY 1
),
ranked AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY avg_time_del) AS sale_rank
    FROM gr_by_city
)
SELECT *
FROM ranked
WHERE count_ads > 69  -- только города с 70+ объявлениями для статистической устойчивости
ORDER BY count_ads DESC;

