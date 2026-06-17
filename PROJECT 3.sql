/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 */
-- Часть 1. Исследовательский анализ данных

-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
	SELECT 
	COUNT(*) AS total_users, --общее кол-во пользователей
	SUM(payer) AS paying_users, --количество платящих пользователей
	AVG(payer) AS difference_users -- Вычисляет среднее значение в столбце платящих игроков
	FROM fantasy.users 

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
    r.race,
    SUM(u.payer) AS paying_users,
    COUNT(*) AS total_users,
    AVG(u.payer) AS difference_users
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY r.race;

-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount:
	SELECT 
    COUNT(*) AS total_purchases,  -- Общее количество покупок
    SUM(amount) AS total_cost,     -- Суммарная стоимость всех покупок
    MIN(amount) AS min_cost,       -- Минимальная стоимость покупки
    MAX(amount) AS max_cost,       -- Максимальная стоимость покупки
    AVG(amount) AS average_cost,    -- Среднее значение стоимости покупки
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_cost,  -- Медиана стоимости покупки
    STDDEV(amount) AS stddev_cost   -- Стандартное отклонение стоимости покупки
FROM 
    fantasy.events         
       

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
WITH zeropurchases AS (
    SELECT COUNT(*) AS zero_purchases 
    FROM fantasy.events 
    WHERE amount = 0
), totalpurchases AS (
    SELECT COUNT(*) AS total_purchases 
    FROM fantasy.events
)
SELECT
    zp.zero_purchases,
    tp.total_purchases,
    (CAST(zp.zero_purchases AS REAL) / tp.total_purchases) AS total_zero_amount
FROM zeropurchases AS zp, totalpurchases AS tp



-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
	WITH userpurchasesummary AS (
    SELECT
        u.id,
        CASE u.payer WHEN 1 THEN 'Платящий' ELSE 'Неплатящий' END AS payer_category,
        COUNT(CASE WHEN e.amount > 0 THEN 1 END) AS count_purchases,
        SUM(CASE WHEN e.amount > 0 THEN e.amount ELSE 0 END) AS total_spent
    FROM fantasy.users u
    INNER JOIN fantasy.events e ON u.id = e.id
    GROUP BY u.id, payer_category
)
SELECT
    payer_category,
    COUNT(*) AS total_users,
    AVG(count_purchases) AS avg_purchases_per_user,
    AVG(total_spent) AS avg_total_spent_per_user
FROM userpurchasesummary
GROUP BY payer_category;


--2.3:Второй вариант запроса
SELECT
    CASE WHEN u.payer = 1 THEN 'Платящий' ELSE 'Неплатящий' END AS payer_category,
    COUNT(DISTINCT u.id) AS total_users,
    (CAST(COUNT(CASE WHEN e.amount > 0 THEN e.id ELSE NULL END) AS REAL)) / COUNT(DISTINCT u.id) AS avg_purchases_per_user,
    (CAST(SUM(CASE WHEN e.amount > 0 THEN e.amount ELSE 0 END) AS REAL)) / COUNT(DISTINCT u.id) AS avg_total_spent_per_user
FROM fantasy.users AS u
INNER JOIN fantasy.events e ON u.id = e.id
GROUP BY payer_category;

-- 2.4: Популярные эпические предметы:
WITH itemsales AS (
    SELECT 
        item_code, 
        COUNT(*) AS total_sales, 
        COUNT(DISTINCT id) AS unique_buyers  
    FROM fantasy.events
    GROUP BY item_code
)
SELECT
    i.game_items,
    e.total_sales,
    (CAST(e.total_sales AS REAL) / (SELECT SUM(total_sales) FROM itemsales)) AS sales_share,
    (CAST(e.unique_buyers AS REAL) / (SELECT COUNT(DISTINCT id) FROM fantasy.events)) AS buyer_share
FROM fantasy.items AS i
JOIN itemsales AS e ON i.item_code = e.item_code
ORDER BY total_sales DESC;





-- Часть 2. Решение ad hoc-задач

-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH total_players AS (
    SELECT r.race_id,
           r.race,
           COUNT(u.id) AS total_registered
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users u ON r.race_id = u.race_id
    GROUP BY r.race_id, r.race
),
paying_players AS (
    SELECT r.race_id,
           COUNT(DISTINCT u.id) AS paying_users,
           COUNT(DISTINCT CASE WHEN u.payer = '1' THEN u.id END) AS epic_paying_users
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id 
    WHERE e.transaction_id IS NOT NULL 
    GROUP BY r.race_id
),
activity_stats AS (
    SELECT r.race_id,
           COUNT(e.transaction_id) AS total_purchases,
           SUM(e.amount) AS total_spent,
           AVG(e.amount) AS average_purchase_amount,
           CAST(COUNT(e.transaction_id) AS REAL) / NULLIF(COUNT(DISTINCT e.id), 0) AS avg_purchases_per_player,
           CAST(SUM(e.amount) AS REAL) / NULLIF(COUNT(DISTINCT e.id), 0) AS avg_spent_per_player
    FROM fantasy.race AS r
    LEFT JOIN fantasy.users AS u ON r.race_id = u.race_id
    LEFT JOIN fantasy.events AS e ON u.id = e.id
    GROUP BY r.race_id
)
SELECT tp.race,
       tp.total_registered,
       pp.paying_users,
       CAST(pp.epic_paying_users AS REAL) / NULLIF(pp.paying_users, 0) AS paying_percentage,
       CAST(SUM(tp.total_registered) AS REAL) * 100 / NULLIF(pp.paying_users, 0) AS paying_among_purchasing_percentage,
       act.total_purchases,
       act.total_spent,
       act.average_purchase_amount,
       act.avg_purchases_per_player,
       act.avg_spent_per_player
FROM total_players AS tp
LEFT JOIN paying_players pp ON tp.race_id = pp.race_id
LEFT JOIN activity_stats act ON tp.race_id = act.race_id
GROUP BY tp.race, tp.total_registered,pp.paying_users,paying_percentage, act.total_purchases,act.total_spent,act.average_purchase_amount,act.avg_purchases_per_player,act.avg_spent_per_player






-- Задача 2: Частота покупок
	WITH playerpurchases AS (
    SELECT
        e.id,
        e.date,
        e.amount
    FROM fantasy.events AS e
    WHERE e.amount > 0
), rankedpurchases AS (
    SELECT
        id,
        date,
        amount,
        LAG(date, 1, date) OVER (PARTITION BY id ORDER BY date) as purchase_date,
        (date::date- LAG(date::date, 1, date::date) OVER (PARTITION BY id ORDER BY date)) AS since_last_purchase
    FROM PlayerPurchases
), purchasesummary AS (
    SELECT
        id,
        COUNT(*) AS total_purchases,
        AVG(since_last_purchase) AS avg_days_between_purchases
    FROM rankedpurchases
    GROUP BY id
    HAVING COUNT(*) >= 25
), frequencygroups AS (
    SELECT
        id,
        total_purchases,
        avg_days_between_purchases,
        NTILE(3) OVER (ORDER BY avg_days_between_purchases DESC) AS frequency_group
    FROM purchasesummary
), usersummary AS (
    SELECT
        ps.id,
        u.payer
    FROM purchasesummary AS ps
    JOIN fantasy.users AS u ON ps.id = u.id
)
SELECT
    CASE
        WHEN fg.frequency_group = 1 THEN 'Высокая частота'
        WHEN fg.frequency_group = 2 THEN 'Средняя частота'
        ELSE 'Низкая частота'
    END AS frequency_category,
    COUNT(DISTINCT fg.id) AS total_players,
    COUNT(DISTINCT CASE WHEN us.payer = 1 THEN fg.id ELSE NULL END) AS paying_players,
    CAST(COUNT(DISTINCT CASE WHEN us.payer = 1 THEN fg.id ELSE NULL END) AS REAL) / COUNT(DISTINCT fg.id) AS paying_player_percentage,
    AVG(fg.total_purchases) AS avg_purchases_per_player,
    AVG(fg.avg_days_between_purchases) AS avg_days_between_purchases
FROM frequencygroups AS fg
JOIN usersummary AS us ON fg.id = us.id
GROUP BY
    frequency_category
ORDER BY
    frequency_category;



