@echo off
setlocal
cd /d "%~dp0"
echo Verification de Docker Desktop...
docker info >nul 2>&1
if errorlevel 1 (
  echo Ouvrez Docker Desktop et attendez que son moteur soit demarre, puis relancez ce fichier.
  pause
  exit /b 1
)
echo Installation et demarrage de First Bricks. La premiere fois peut prendre plusieurs minutes.
docker compose up --build -d
if errorlevel 1 (
  echo Le demarrage a echoue. Copiez le message ci-dessus pour obtenir de l'aide.
  pause
  exit /b 1
)
echo Attente de l'application...
powershell -NoProfile -Command "$ready=$false; for($i=0;$i -lt 60;$i++){try{$r=Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:4000/health' -TimeoutSec 2; if($r.StatusCode -eq 200){$ready=$true; break}}catch{}; Start-Sleep -Seconds 1}; if(-not $ready){exit 1}"
if errorlevel 1 (
  echo L'application n'a pas repondu. Voici les derniers messages :
  docker compose logs --tail 30 app
  pause
  exit /b 1
)
echo Identifiant : admin
echo Mot de passe : local-first-bricks-2026
start "" "http://localhost:4000"
pause
