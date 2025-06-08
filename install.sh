#!/bin/bash

echo "Установка или обновление скриптов..."

# Проверяем существование директории и создаем её, если нет
if [ ! -d "/opt" ]; then
    sudo mkdir -p /opt
fi

# Скачиваем скрипт с отображением только ошибок
echo "Скачивание скрипта..."
wget -O /opt/smart_check.sh https://raw.githubusercontent.com/ptath/pve-sh-scripts/main/smart_check.sh 2>&1 >/dev/null

# Делаем скрипт исполняемым
sudo chmod +x /opt/smart_check.sh

# Обрабатываем файл конфигурации
if [ -f "/opt/.env" ]; then
    echo "Файл конфигурации.env уже существует, не заменяем его."
else
    # Скачиваем файл конфигурации с отображением только ошибок
    echo "Скачивание файла конфигурации..."
    wget -O /opt/.env https://raw.githubusercontent.com/ptath/pve-sh-scripts/main/.env 2>&1 >/dev/null
    echo "!! ВАЖНО: Пожалуйста, отредактируйте файл /opt/.env и настройте параметры для вашего Telegram-бота !!"
fi

# Проверяем наличие задания в crontab
if crontab -l | grep -q '/opt/smart_check.sh'; then
    echo "Задание уже существует в crontab, не добавляем дубликат."
else
    echo "Добавление задания в crontab..."
    (crontab -l; echo "0 10 * * * /opt/smart_check.sh") | crontab -
fi

# Проверяем, что задание добавилось
echo "Текущее расписание в crontab:"
crontab -l

echo "Установка завершена. Скрипт будет выполняться ежедневно в 10:00."
echo "Не забудьте настроить файл /opt/.env перед первым запуском!"
