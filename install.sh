#!/bin/bash

# Проверяем существование директории и создаем её, если нет
if ! [ -d "/opt" ]; then
    sudo mkdir -p /opt
fi

# Функция для проверки и скачивания файла
download_if_different() {
    local local_file=$1
    local remote_url=$2
    local temp_file=$(mktemp)
    
    # Скачиваем удаленный файл во временный файл
    wget -O "$temp_file" "$remote_url" 2>&1 >/dev/null
    
    # Проверяем, существует ли локальный файл
    if [ -f "$local_file" ]; then
        # Сравниваем файлы
        if ! cmp -s "$local_file" "$temp_file"; then
            echo "Локальный файл отличается от удаленного, производим обновление..."
            sudo mv "$temp_file" "$local_file"
            sudo chmod +x "$local_file"
        else
            echo "Файл не изменился, обновление не требуется."
            rm "$temp_file"
        fi
    else
        # Если локального файла нет - просто перемещаем скачанный
        echo "Скачивание файла..."
        sudo mv "$temp_file" "$local_file"
        sudo chmod +x "$local_file"
    fi
}

# Скачиваем и проверяем smart_check.sh
echo "Проверка и скачивание smart_check.sh..."
download_if_different "/opt/smart_check.sh" "https://raw.githubusercontent.com/ptath/pve-sh-scripts/main/smart_check.sh"

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
