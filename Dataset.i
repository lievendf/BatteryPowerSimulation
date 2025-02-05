
DEFINE PRIVATE TEMP-TABLE PowerRegistration NO-UNDO
    FIELD Id AS INTEGER /* Auto increment */
    FIELD FromTime AS DATETIME
    FIELD ToTime AS DATETIME
    FIELD Type AS INTEGER /* Consumption = 1, Injection = 2 */
    FIELD Amount AS DECIMAL /* kWh */
    FIELD SimulatedAmount AS DECIMAL
    INDEX Id IS PRIMARY UNIQUE Id
    INDEX FromTime_Type FromTime Type
    INDEX Type_FromTime Type FromTime.
