/**DEMAND*/
/*****Business question:ما المحافظات الأعلى استهلاكًا للكهرباء؟ ******/
SELECT
    L.Governorate,
    SUM(F.Electricity_Consumption_KWh) AS Total_Consumption
FROM DimLocation AS L
JOIN FactElectricity AS F
    ON L.Location_ID = F.Location_ID
GROUP BY L.Governorate
ORDER BY Total_Consumption DESC;
/**Business Area:demand**/
/**business question:إلى أي مدى ارتفاع درجة الحرارة بيزود استهلاك الكهرباء؟**/
SELECT
    F.Average_Temperature,
    AVG(F.Electricity_Consumption_KWh * 1.0) AS Avg_Consumption
FROM FactElectricity AS F
GROUP BY F.Average_Temperature
ORDER BY F.Average_Temperature;
/***تأثير وجود التكييف على متوسط استهلاك الأسرة**/
SELECT
    H.Has_AC,
    AVG(F.Electricity_Consumption_KWh * 1.0) AS Avg_Consumption
FROM DimHousehold AS H
JOIN FactElectricity AS F
    ON H.Household_ID = F.Household_ID
GROUP BY H.Has_AC;
/**Insight:Households with air conditioning consume significantly more electricity than households without AC,
making AC adoption an important demand driver**/

/**REVENUE*/
/**ما إجمالي الإيرادات المتوقعة من الفواتير شهريًا؟**/
SELECT
    D.Month_Start_Date,
    SUM(F.Current_Bill_Amount) AS Total_Revenue
FROM DimDate AS D
JOIN FactElectricity AS F
    ON D.Month_Start_Date = F.Month_Start_Date
GROUP BY D.Month_Start_Date
ORDER BY D.Month_Start_Date;

/**insight:Revenue increases during high-consumption months, especially in summer, 
indicating that seasonal demand has a direct impact on expected billing revenue.**/

/**Pricing**/
/***أي شرائح استهلاك تحقق أكبر جزء من الإيرادات؟**/
WITH ConsumptionData AS
(
    SELECT
        CASE
            WHEN Electricity_Consumption_KWh <= 200 THEN '0-200'
            WHEN Electricity_Consumption_KWh <= 500 THEN '201-500'
            WHEN Electricity_Consumption_KWh <= 1000 THEN '501-1000'
            ELSE '1000+'
        END AS Consumption_Band,
        Current_Bill_Amount
    FROM FactElectricity
)

SELECT
    Consumption_Band,
    SUM(Current_Bill_Amount) AS Revenue
FROM ConsumptionData
GROUP BY Consumption_Band
ORDER BY Revenue DESC;

/**Insight:The 1000+ consumption segment generates the largest share of revenue,
showing that high-consumption customers are particularly important to total revenue.**/
/**customers**/
/**هل حجم الأسرة مرتبط بالاستهلاك؟**/
SELECT
    H.Household_Size,
    AVG(F.Electricity_Consumption_KWh * 1.0) AS Avg_Consumption
FROM DimHousehold AS H
JOIN FactElectricity AS F
    ON H.Household_ID = F.Household_ID
GROUP BY H.Household_Size
ORDER BY H.Household_Size;
/**customers**/
/**نوع السكن وعدد الغرف وتأثيرهم على الاستهلاك**/
SELECT
    H.Housing_Type,
    H.Rooms_Count,
    AVG(F.Electricity_Consumption_KWh * 1.0) AS Avg_Consumption,
    COUNT(*) AS Records
FROM DimHousehold AS H
JOIN FactElectricity AS F
    ON H.Household_ID = F.Household_ID
GROUP BY
    H.Housing_Type,
    H.Rooms_Count
ORDER BY Avg_Consumption DESC;


/**Business Area:Pricing**/
/** أي فئات العملاء ستتأثر أكثر بزيادة الأسعار**/
SELECT
    H.Income_Category,
    AVG(F.Bill_Difference) AS Avg_Increase_Per_Household,
    SUM(F.Bill_Difference) AS Total_Increase
FROM DimHousehold AS H
JOIN FactElectricity AS F
    ON H.Household_ID = F.Household_ID
GROUP BY H.Income_Category
ORDER BY Avg_Increase_Per_Household DESC;

/**collection**/
/**نسبة العملاء الذين لا يدفعون في موعدهم**/
SELECT
    P.Payment_Status,
    COUNT(*) AS Records,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS Percentage
FROM DimPaymentStatus AS P
JOIN FactElectricity AS F
    ON P.Payment_Status = F.Payment_Status
GROUP BY P.Payment_Status;
/**business question:خصائص العملاء الأكثر عرضة للتأخر**/
SELECT
    H.Income_Category,
    H.Meter_Type,
    L.Area_Type,
    COUNT(*) AS Total_Records,
    SUM(
        CASE
            WHEN F.Payment_Status = N'متأخرة'
            THEN 1
            ELSE 0
        END
    ) AS Late_Records,
    ROUND(
        SUM(
            CASE
                WHEN F.Payment_Status = N'متأخرة'
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS Late_Rate
FROM FactElectricity AS F
JOIN DimHousehold AS H
    ON F.Household_ID = H.Household_ID
JOIN DimLocation AS L
    ON F.Location_ID = L.Location_ID
GROUP BY
    H.Income_Category,
    H.Meter_Type,
    L.Area_Type
ORDER BY Late_Rate DESC;

/****Reliability***/
/**Business quesion:
ما المحافظات أو المناطق التي تعاني أكبر عدد من انقطاعات الكهرباء؟**/
SELECT
    L.Governorate,
    L.Area_Type,
    SUM(F.Power_Outage_Count) AS Total_Outages,
    AVG(F.Power_Outage_Count * 1.0) AS Avg_Outages
FROM DimLocation AS L
JOIN FactElectricity AS F
    ON L.Location_ID = F.Location_ID
GROUP BY
    L.Governorate,
    L.Area_Type
ORDER BY Total_Outages DESC;
/***/
/**أي محولات مرتبطة بأعلى عدد من الانقطاعات؟**/
SELECT
    T.Transformer_Number,
    SUM(F.Power_Outage_Count) AS Total_Outages,
    AVG(F.Power_Outage_Count * 1.0) AS Avg_Outages
FROM DimTransformer AS T
JOIN FactElectricity AS F
    ON T.Transformer_Number = F.Transformer_Number
GROUP BY T.Transformer_Number
ORDER BY Total_Outages DESC;

/**Transformers**/
/**Business question:أي المحولات تخدم عملاء ذوي استهلاك مرتفع باستمرار؟**/
SELECT
    T.Transformer_Number,
    COUNT(DISTINCT F.Household_ID) AS Households,
    SUM(F.Electricity_Consumption_KWh) AS Total_Consumption,
    AVG(F.Electricity_Consumption_KWh * 1.0) AS Avg_Consumption
FROM DimTransformer AS T
JOIN FactElectricity AS F
    ON T.Transformer_Number = F.Transformer_Number
GROUP BY T.Transformer_Number
ORDER BY Avg_Consumption DESC;






