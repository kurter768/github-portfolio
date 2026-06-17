/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
*/

-- Пример фильтрации данных от аномальных значений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
 WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.05) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
prepared_data AS (
  SELECT
    f.total_area,
    f.rooms,
    f.ceiling_height,
    f.living_area,
    f.kitchen_area,
    f.balcony,
    a.days_exposition,
    a.last_price,
    CASE
      WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
      ELSE 'Ленинградская область'
    END AS region,
    CASE
      WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'Месяц'
      WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'Квартал'
      WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'Пол года'
      ELSE 'Более полугода'
    END AS exposition_period,
    (a.last_price::numeric / f.total_area::numeric) AS price_per_sq_m
  FROM
    real_estate.flats AS f
  JOIN
    real_estate.advertisement a ON f.id = a.id
  JOIN
    real_estate.city AS c ON f.city_id = c.city_id
  JOIN
    real_estate.type AS t ON f.type_id = t.type_id
  WHERE a.days_exposition > 0 
    AND a.days_exposition < 365 
    AND a.last_price > 1000000
    AND t.type = 'город'  
)
SELECT
  region,
  exposition_period,
  COUNT(*) AS ad_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS ad_share,
  AVG(price_per_sq_m) AS avg_price_per_sq_m,
  AVG(total_area) AS avg_total_area,
  AVG(rooms) AS avg_rooms,
  AVG(ceiling_height) AS avg_ceiling_height
FROM
  prepared_data
GROUP BY
  region,
  exposition_period
ORDER BY
  region,
  exposition_period








 
 






-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.05) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_flats AS (
    SELECT id
    FROM real_estate.flats
    JOIN limits l ON 
        total_area < l.total_area_limit
        AND rooms < l.rooms_limit
        AND balcony < l.balcony_limit
        AND ceiling_height < l.ceiling_height_limit_h
        AND ceiling_height > l.ceiling_height_limit_l
),
advertisement_with_sale_date AS (
    SELECT
        a.*,
        f.total_area,
        f.rooms,
        c.city,
        t.type as city_type,
        first_day_exposition + (days_exposition::text || ' days')::interval AS sale_date
    FROM
        real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE f.id IN (SELECT id FROM filtered_flats)  
      AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 
      AND t.type = 'город'
),
monthly_publication_activity AS (
    SELECT
        EXTRACT(MONTH FROM first_day_exposition) AS publication_month,
        COUNT(*) AS publication_count,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS publication_rank
    FROM
        advertisement_with_sale_date
    GROUP BY
        publication_month
),
monthly_sale_activity AS (
    SELECT
        EXTRACT(MONTH FROM sale_date) AS sale_month,
        COUNT(*) AS sale_count,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS sale_rank
    FROM
        advertisement_with_sale_date
    GROUP BY
        sale_month
),
monthly_price_area AS (
  SELECT
    EXTRACT(MONTH FROM first_day_exposition) AS month,
    AVG(total_area) AS avg_area,
    AVG((last_price::numeric / total_area::numeric)) AS avg_price_per_sqm
  FROM advertisement_with_sale_date
  GROUP BY month
)
SELECT
  pm.publication_month,
  pm.publication_count,
  pm.publication_rank,
  sm.sale_month,
  sm.sale_count,
  sm.sale_rank,
  mpa.avg_area,
  mpa.avg_price_per_sqm
FROM monthly_publication_activity AS pm
JOIN monthly_sale_activity AS sm ON pm.publication_month = sm.sale_month
JOIN monthly_price_area AS mpa ON pm.publication_month = mpa.month
ORDER BY pm.publication_rank









-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.
    WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_flats AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
),
city_counts AS (
    SELECT
        c.city,
        COUNT(*) AS ad_count
    FROM
        real_estate.flats AS f
    JOIN
        real_estate.advertisement AS a ON f.id = a.id
    JOIN
        real_estate.city AS c ON f.city_id = c.city_id
    WHERE
        c.city <> 'Санкт-Петербург'
        AND f.id IN (SELECT id FROM filtered_flats) 
    GROUP BY
        c.city
    HAVING
        COUNT(*) >= 50
),
city_data AS (
    SELECT
        c.city,
        COUNT(*) AS total_ads,
        SUM(CASE WHEN a.days_exposition > 0 THEN 1 ELSE 0 END) AS sold_ads,
        AVG(f.total_area) AS avg_area,
        AVG((a.last_price::numeric / f.total_area::numeric)) AS avg_price_per_sqm,
        AVG(a.days_exposition) AS avg_exposition_days
    FROM
        real_estate.flats AS f
    JOIN
        real_estate.advertisement AS a ON f.id = a.id
    JOIN
        real_estate.city AS c ON f.city_id = c.city_id
    JOIN
        city_counts cc ON c.city = cc.city
    WHERE
        c.city <> 'Санкт-Петербург'
        AND f.id IN (SELECT id FROM filtered_flats)
    GROUP BY
        c.city
)
SELECT
    city,
    total_ads,
    sold_ads * 100.0 / total_ads AS sold_ads_share,
    avg_area,
    avg_price_per_sqm,
    avg_exposition_days
FROM
    city_data
ORDER BY
    total_ads DESC







