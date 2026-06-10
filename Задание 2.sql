-- Задание 2
USE User_Actions;

-- Шаг 2: Анализ временных рамок исходных данных
SELECT MIN(action_date) FROM User_Logs;
SELECT MAX(action_date) FROM User_Logs;


-- Шаг 3: Подготовка физической структуры БД Sector
ALTER DATABASE User_Actions ADD FILEGROUP User_Actions_frag;
GO

ALTER DATABASE User_Actions ADD FILE(
	NAME = 'User_Actions_frag_2023',
	FILENAME = 'D:\SQL\User_Actions_frag_2025.ndf') TO FILEGROUP User_Actions_frag;
GO


-- Шаг 4: Создание функции секционирования
CREATE PARTITION FUNCTION pf_User_Actions_year(date)
AS RANGE RIGHT FOR VALUES ('2025-02-01', '2025-03-01', '2025-04-01', 
    '2025-05-01', '2025-06-01', '2025-07-01', 
    '2025-08-01', '2025-09-01', '2025-10-01', 
    '2025-11-01', '2025-12-01')
GO


-- Шаг 5: Создание схемы секционирования
CREATE PARTITION SCHEME ps_User_Actions_frag
AS PARTITION pf_User_Actions_year TO (
    User_Actions_frag, 
    User_Actions_frag,
	User_Actions_frag, 
    User_Actions_frag,
	User_Actions_frag, 
    User_Actions_frag,
	User_Actions_frag, 
    User_Actions_frag,
	User_Actions_frag, 
    User_Actions_frag, 
	User_Actions_frag,
    User_Actions_frag
);
GO


-- Шаг 6: Создание секционированной таблицы
CREATE TABLE User_Logs_frag(
	id UNIQUEIDENTIFIER DEFAULT NEWID(),
	username TEXT NOT NULL,       
	user_action TEXT NOT NULL,
	action_date DATE NOT NULL,
	action_time TIME NOT NULL,
	action_result TEXT NOT NULL,

	CONSTRAINT pk_logs PRIMARY KEY CLUSTERED (id, action_date)
) ON ps_User_Actions_frag(action_date);
GO


-- Шаг 7: Проверка пустой таблицы
SELECT COUNT(*) FROM User_Logs_frag;


-- Шаг 8: Миграция данных
INSERT INTO User_Logs_frag (username, user_action, action_date, action_time, action_result) 
	SELECT username, user_action, action_date, action_time, action_result FROM User_Logs;


-- Шаг 9: Проверка после вставки
SELECT COUNT(*) FROM User_Logs_frag;


-- Шаг 10: Контрольное чтение
SELECT * FROM User_Logs;      
SELECT * FROM User_Logs_frag; 

SELECT * FROM User_Logs_frag
WHERE $partition.pf_User_Actions_year(action_date) = 11;