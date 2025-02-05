USING Progress.Lang.Error FROM PROPATH.

BLOCK-LEVEL ON ERROR UNDO, THROW.

DEFINE VARIABLE FileReader AS FluviusFileReader NO-UNDO.
DEFINE VARIABLE Settings AS Settings NO-UNDO.

FileReader = NEW FluviusFileReader().
Settings = NEW Settings().
FileReader:ReadFile("Verbruikshistoriek_elektriciteit_xxxxxxxxxxxxxxxxxx_20240101_20250101_kwartiertotalen.csv":U).
Settings:NumBatteries = 1.
FileReader:ProcessData(Settings).
FileReader:CalculateTotals(Settings).
Settings:NumBatteries = 2.
FileReader:ProcessData(Settings).
FileReader:CalculateTotals(Settings).

/*FileReader:WriteJson().                 */
/*MESSAGE "Done, see c:/temp/fluvius.json"*/
/*    VIEW-AS ALERT-BOX.                  */

CATCH e AS Error:
    MESSAGE e:GetMessage(1)
        VIEW-AS ALERT-BOX ERROR.
END CATCH.
