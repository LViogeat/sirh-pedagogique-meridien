FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY socle ./socle

EXPOSE 8000

# Au démarrage : création des tables, préparation des schémas de groupe et
# chargement du jeu de démonstration si la base est vide. Rien à lancer à la main.
CMD ["uvicorn", "socle.main:app", "--host", "0.0.0.0", "--port", "8000"]
