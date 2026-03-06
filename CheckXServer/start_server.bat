@echo off
TITLE CheckX Server
COLOR 0A

:: Info-Ausgabe
ECHO ======================================================
ECHO   CHECKX SERVER - SYSTEM START
ECHO ======================================================
ECHO.

:: 1. Abhängigkeiten prüfen und installieren
ECHO [INFO] Pruefe Python-Bibliotheken (requirements.txt)...
pip install -r requirements.txt
IF %ERRORLEVEL% NEQ 0 (
    COLOR 0C
    ECHO [FEHLER] Konnte Bibliotheken nicht installieren!
    PAUSE
    EXIT
)
ECHO [OK] Bibliotheken sind aktuell.
ECHO.

:: 2. In Server-Verzeichnis wechseln
cd server

:: Info-Ausgabe
ECHO ======================================================
ECHO   CHECKX SERVER WIRD GESTARTET
ECHO   API: http://127.0.0.1:8000
ECHO   Doku: http://127.0.0.1:8000/docs
ECHO ======================================================
ECHO.

:: Startet den Server mit Auto-Reload (ideal für Entwicklung)
uvicorn main:app --reload --host 127.0.0.1 --port 8000

:: Falls der Server abstürzt, Fenster offen lassen
COLOR 0C
ECHO.
ECHO [ACHTUNG] Server wurde unerwartet beendet.
PAUSE