BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS Settings:

    /* HomeWizard plug-in battery */

    DEFINE PUBLIC PROPERTY NumBatteries AS INTEGER NO-UNDO INITIAL 1
    GET.
    SET.

    /* kWh */
    DEFINE PUBLIC PROPERTY BatteryCapacity AS DECIMAL NO-UNDO INITIAL 2.489 /* 2688 Wh = 2.7 kWh, but 8% reserved so 2.489 */
    GET.
    SET.

    /* kW
     * For now assume this applies to both charging and discharging of battery.
     * We night need MaxChargePower/MaxDischargePower in the future...
     */
    DEFINE PUBLIC PROPERTY MaxPower AS DECIMAL NO-UNDO INITIAL 0.8
    GET.
    SET.

    /* Purchase price of 1 battery in € */
    DEFINE PUBLIC PROPERTY PurchasePrice AS DECIMAL NO-UNDO INITIAL 1395
    GET.
    SET.

    /* Ecopower */

    /* €/kWh */
    DEFINE PUBLIC PROPERTY InjectionTarif AS DECIMAL NO-UNDO INITIAL 0.020
    GET.
    SET.

    /* €/kWh */
    DEFINE PUBLIC PROPERTY ConsumptionTarif AS DECIMAL NO-UNDO INITIAL 0.37
    GET.
    SET.

    /* DC -> AC / AC -> DC RTE (Round Trip Efficiency) */
    DEFINE PUBLIC PROPERTY RoundTripEfficiency AS DECIMAL NO-UNDO INITIAL 0.80 /* "houdt rekening met tussen de 75% en 88% efficiëntie in echte omstandigheden"
        https://helpdesk.homewizard.com/nl/articles/9503450-de-plug-in-battery-alles-wat-je-moet-weten#h_7b78215db1 */
    GET.
    SET.

/*  Ecopower
    Periode         Prijs           Terugleververgoeding
    December 2024   0,1394 €/kWh    0,0750 €/kWh
    November 2024   0,1411 €/kWh    0,0750 €/kWh
    Oktober 2024    0,1259 €/kWh    0,0750 €/kWh
    September 2024  0,1193 €/kWh    0,0750 €/kWh
    Augustus 2024   0,1184 €/kWh    0,0750 €/kWh
    Juli 2024       0,1126 €/kWh    0,0750 €/kWh
    Juni 2024       0,1151 €/kWh    0,0750 €/kWh
    Mei 2024        0,1124 €/kWh    0,0750 €/kWh
    April 2024      0,1094 €/kWh    0,0750 €/kWh
    Maart 2024      0,1166 €/kWh    0,0750 €/kWh
    Februari 2024   0,1166 €/kWh    0,0750 €/kWh
    Januari 2024    0,1254 €/kWh    0,0750 €/kWh
*/

END CLASS.
