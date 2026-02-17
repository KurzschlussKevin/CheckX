@echo off
TITLE CheckX Server
COLOR 0A

:: Gehe in das Server-Verzeichnis
cd server

:: Info-Ausgabe
ECHO ======================================================
ECHO   CHECKX SERVER WIRD GESTARTET
ECHO   API: http://127.0.0.1:8000
ECHO   Doku: http://127.0.0.1:8000/docs
ECHO ======================================================
ECHO.

:: Server starten (mit Auto-Reload für Entwicklung)
uvicorn main:app --reload --host 127.0.0.1 --port 8000

:: Falls der Server abstürzt, Fenster offen lassen
ECHO.
ECHO Server wurde beendet.
PAUSE