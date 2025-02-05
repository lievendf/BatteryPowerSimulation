USING Progress.Lang.AppError FROM PROPATH.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS FluviusFileReader:

    { Dataset.i }

    DEFINE PRIVATE VARIABLE Id AS INTEGER NO-UNDO.

    /* Example file format:
Van (datum);Van (tijdstip);Tot (datum);Tot (tijdstip);EAN-code;Meter;Metertype;Register;Volume;Eenheid;Validatiestatus;Omschrijving
05-01-2024;06:15:00;05-01-2024;06:30:00;="xxxxxxxxxxxxxxxxxx";yyyyyyyyyyyyyy;Digitale meter;Afname Dag;0,026;kWh;Uitgelezen;
05-01-2024;06:15:00;05-01-2024;06:30:00;="xxxxxxxxxxxxxxxxxx";yyyyyyyyyyyyyy;Digitale meter;Injectie Dag;0,000;kWh;Uitgelezen;
05-01-2024;06:30:00;05-01-2024;06:45:00;="xxxxxxxxxxxxxxxxxx";yyyyyyyyyyyyyy;Digitale meter;Afname Dag;0,022;kWh;Uitgelezen;
05-01-2024;06:30:00;05-01-2024;06:45:00;="xxxxxxxxxxxxxxxxxx";yyyyyyyyyyyyyy;Digitale meter;Injectie Dag;0,000;kWh;Uitgelezen;
     */

    METHOD PUBLIC VOID ReadFile(FileName AS CHARACTER):

        DEFINE VARIABLE FirstLine AS LOGICAL NO-UNDO INITIAL TRUE.
        DEFINE VARIABLE FromDate AS CHARACTER NO-UNDO.
        DEFINE VARIABLE FromTime AS CHARACTER NO-UNDO.
        DEFINE VARIABLE ToDate AS CHARACTER NO-UNDO.
        DEFINE VARIABLE ToTime AS CHARACTER NO-UNDO.
        DEFINE VARIABLE Type AS CHARACTER NO-UNDO.
        DEFINE VARIABLE Amount AS CHARACTER NO-UNDO.

        DEFINE BUFFER b_PowerRegistration FOR PowerRegistration.

        /* --------------------------------------------------------------------- */

        ASSIGN SESSION:DATE-FORMAT = "dmy":U. /* Fluvius file contains dates as dmy */

        IF SESSION:NUMERIC-DECIMAL-POINT <> ",":U /* Fluvius file uses comma as decimal point */
        THEN UNDO, THROW NEW AppError(
            "Fluvius input file is in European format (date as dmy, comma as decimal separator).":U + "~n":U +
            "Please add -E startup parameter.":U, ?).

        ResetAll().

        INPUT FROM VALUE(FileName).

        REPEAT: /* Repeat automatically stops when the last line is imported... */

            IF FirstLine /* Skip header */
            THEN DO:
                IMPORT UNFORMATTED ^.
                FirstLine = FALSE.
                NEXT.
            END.

            IMPORT DELIMITER ";":U FromDate FromTime ToDate ToTime ^ ^ ^ Type Amount.

            CREATE b_PowerRegistration.
            ASSIGN
                Id += 1
                b_PowerRegistration.Id = Id
                b_PowerRegistration.FromTime = DATETIME(SUBSTITUTE("&1 &2":U, FromDate, FromTime))
                b_PowerRegistration.ToTime = DATETIME(SUBSTITUTE("&1 &2":U, ToDate, ToTime))
                b_PowerRegistration.Type = IF Type BEGINS "Afname":U THEN 1 ELSE /* Injectie */ 2
                b_PowerRegistration.Amount = DECIMAL(Amount).
        END.

    END METHOD.

    /*****************************************************************************/

    /**
     * Purpose:
     * Notes: The RTE (Round Trip Efficiency) is applied 1/2 to the charging and 1/2 to the discharging of the battery.
     *        This differs slightly from applying the complete RTE to e.g. the charging phase only...
     *
     * @param Settings : Settings
     */
    METHOD PUBLIC VOID ProcessData(Settings AS Settings):

        DEFINE VARIABLE OneHour AS INTEGER NO-UNDO INITIAL 3600. /* Seconds */
        DEFINE VARIABLE Resolution AS INTEGER NO-UNDO. /* Seconds */
        DEFINE VARIABLE MaxPower AS DECIMAL NO-UNDO. /* In kWh per "resolution". E.g. 0.8kW max injection means 0.2kW per quarter hour */
        DEFINE VARIABLE Amount AS DECIMAL NO-UNDO.
        DEFINE VARIABLE CorrectedAmount AS DECIMAL NO-UNDO.
        DEFINE VARIABLE CurrentBatteryLevel AS DECIMAL NO-UNDO.
        DEFINE VARIABLE BatteryTotalCapacity AS DECIMAL NO-UNDO.
        DEFINE VARIABLE BatteryAvailableCapacity AS DECIMAL NO-UNDO.
        DEFINE VARIABLE SingleTripEfficiency AS DECIMAL NO-UNDO.

        DEFINE BUFFER b_PowerRegistration FOR PowerRegistration.

        /* --------------------------------------------------------------------- */

        ResetSimulatedAmount().

        ASSIGN
            BatteryTotalCapacity = Settings:NumBatteries * Settings:BatteryCapacity
            SingleTripEfficiency = Settings:RoundTripEfficiency + ((1 - Settings:RoundTripEfficiency) / 2).

        FOR EACH b_PowerRegistration BY b_PowerRegistration.Id:

            IF b_PowerRegistration.Amount = 0
            THEN NEXT.

            ASSIGN
                Resolution = (b_PowerRegistration.ToTime - b_PowerRegistration.FromTime) / 1000 /* Milliseconds -> Seconds */
                MaxPower = Settings:NumBatteries * Settings:MaxPower * (Resolution / OneHour) /* It's unlikely that the resolution changes between two PowerRegistrations, but this should handle that nonetheless */
                Amount = MINIMUM(b_PowerRegistration.Amount, MaxPower). /* We can't (dis)charge more than this amount in the battery per resolution */

            /* Injection */
            IF b_PowerRegistration.Type = RegistrationType:Injection:GetValue() /* Try to store as much of the Injection amount as possible in the battery */
            THEN DO:
                ASSIGN
                    BatteryAvailableCapacity = BatteryTotalCapacity - CurrentBatteryLevel
                    Amount = MINIMUM(Amount, BatteryAvailableCapacity)
                    CorrectedAmount = Amount * /*Settings:RoundTripEfficiency*/ SingleTripEfficiency
                    CurrentBatteryLevel = CurrentBatteryLevel + CorrectedAmount.
            END.
            /* Consumption */
            ELSE DO:
                Amount = MINIMUM(Amount, CurrentBatteryLevel).
                CorrectedAmount = MINIMUM(Amount / /*Settings:RoundTripEfficiency*/ SingleTripEfficiency, CurrentBatteryLevel).
                CurrentBatteryLevel = CurrentBatteryLevel - CorrectedAmount.
            END.
            b_PowerRegistration.SimulatedAmount = b_PowerRegistration.Amount - Amount.

        END.

    END METHOD.

    /*****************************************************************************/

    METHOD PUBLIC VOID WriteJson():

        TEMP-TABLE PowerRegistration:WRITE-JSON("FILE":U, "c:\temp\fluvius.json":U, TRUE /* Formatted */).

    END METHOD.

    /*****************************************************************************/

    METHOD PUBLIC VOID CalculateTotals(Settings AS Settings):

        DEFINE VARIABLE TotalConsumption AS DECIMAL NO-UNDO.
        DEFINE VARIABLE TotalInjection AS DECIMAL NO-UNDO.
        DEFINE VARIABLE TotalSimulatedConsumption AS DECIMAL NO-UNDO.
        DEFINE VARIABLE TotalSimulatedInjection AS DECIMAL NO-UNDO.
        DEFINE VARIABLE DiffConsumption AS DECIMAL NO-UNDO.
        DEFINE VARIABLE DiffInjection AS DECIMAL NO-UNDO.
        DEFINE VARIABLE ConsumptionProfit AS DECIMAL NO-UNDO.
        DEFINE VARIABLE InjectionLoss AS DECIMAL NO-UNDO.
        DEFINE VARIABLE PurchasePrice AS DECIMAL NO-UNDO.
        DEFINE VARIABLE TotalSavings AS DECIMAL NO-UNDO.

        DEFINE BUFFER b_PowerRegistration FOR PowerRegistration.

        /* --------------------------------------------------------------------- */

        FOR EACH b_PowerRegistration:

            /* Injection */
            IF b_PowerRegistration.Type = RegistrationType:Injection:GetValue()
            THEN ASSIGN
                    TotalInjection += b_PowerRegistration.Amount
                    TotalSimulatedInjection += b_PowerRegistration.SimulatedAmount.
            /* Consumption */
            ELSE ASSIGN
                    TotalConsumption += b_PowerRegistration.Amount
                    TotalSimulatedConsumption += b_PowerRegistration.SimulatedAmount.
        END.

        ASSIGN
            TotalInjection = ROUND(TotalInjection, 2)
            TotalSimulatedInjection = ROUND(TotalSimulatedInjection, 2)
            TotalConsumption = ROUND(TotalConsumption, 2)
            TotalSimulatedConsumption = ROUND(TotalSimulatedConsumption, 2)
            DiffConsumption = TotalConsumption - TotalSimulatedConsumption
            DiffInjection = TotalInjection - TotalSimulatedInjection
            ConsumptionProfit = ROUND(DiffConsumption * Settings:ConsumptionTarif, 2)
            InjectionLoss = ROUND(DiffInjection * Settings:InjectionTarif, 2)
            PurchasePrice = Settings:NumBatteries * Settings:PurchasePrice
            TotalSavings = ConsumptionProfit - InjectionLoss.

        MESSAGE SUBSTITUTE("NumBatteries: &1", Settings:NumBatteries) SKIP
                SUBSTITUTE("TotalCapacity: &1 kWh", Settings:NumBatteries * Settings:BatteryCapacity) SKIP
                SUBSTITUTE("Battery purchase: &1 €", PurchasePrice) SKIP
                SUBSTITUTE("RoundTripEfficiency: &1 %", Settings:RoundTripEfficiency * 100) SKIP(1)

                SUBSTITUTE("TotalConsumption: &1 kWh", TotalConsumption) SKIP
                SUBSTITUTE("TotalSimulatedConsumption: &1 kWh", TotalSimulatedConsumption) SKIP
                SUBSTITUTE("DifferenceConsumption: &1 kWh less consumption", DiffConsumption) SKIP
                SUBSTITUTE("ConsumptionTarif: &1 €/kWh", STRING(Settings:ConsumptionTarif, "9.99")) SKIP
                SUBSTITUTE("ConsumptionProfit: &1 €", ConsumptionProfit) SKIP(1)

                SUBSTITUTE("TotalInjection: &1 kWh", TotalInjection) SKIP
                SUBSTITUTE("TotalSimulatedInjection: &1 kWh", TotalSimulatedInjection) SKIP
                SUBSTITUTE("DifferenceInjection: &1 kWh less injection", DiffInjection) SKIP
                SUBSTITUTE("InjectionTarif: &1 €/kWh", STRING(Settings:InjectionTarif, "9.999")) SKIP
                SUBSTITUTE("InjectionLoss: &1 €", InjectionLoss) SKIP(1)

                SUBSTITUTE("TotalSavingsOneYear: &1", TotalSavings) SKIP
                SUBSTITUTE("PaybackPeriod: &1 years", ROUND(PurchasePrice / TotalSavings, 2))

            VIEW-AS ALERT-BOX.

    END METHOD.

    /*****************************************************************************/

    METHOD PRIVATE VOID ResetAll():

        Id = 0.
        EMPTY TEMP-TABLE PowerRegistration.

    END METHOD.

    /*****************************************************************************/

    METHOD PRIVATE VOID ResetSimulatedAmount():

        DEFINE BUFFER b_PowerRegistration FOR PowerRegistration.

        /* --------------------------------------------------------------------- */

        FOR EACH b_PowerRegistration:
            ASSIGN b_PowerRegistration.SimulatedAmount = 0.
        END.

    END METHOD.

END CLASS.
