#!/bin/bash

# Проверяем существование файла конфигурации
if [ ! -f "/opt/.env" ]; then
    echo "Файл конфигурации не найден!"
    exit 1
fi

# Подключаем файл с настройками
source /opt/.env

# Получаем список физических дисков
disks=$(lsblk -n -l | awk '{print $1}' | grep -E 'sd|hd|nvme' | grep -v 'p[0-9]')

# Инициализируем массивы для хранения ошибок
warnings=()
errors=()

# Проверяем каждый диск
echo "Проверка состояния SMART:"
echo "------------------------"
for disk in $disks; do
    smartctl_output=$(smartctl -a /dev/$disk 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Не удалось получить информацию для диска /dev/$disk"
        continue
    fi
    
    # Общий статус
    status=$(echo "$smartctl_output" | grep "SMART overall-health self-assessment test result:" | awk '{print $NF}')
    
    # Параметры для проверки
    media_errors=$(echo "$smartctl_output" | grep "Media and Data Integrity Errors" | awk '{print $NF}')
    percentage_used=$(echo "$smartctl_output" | grep "Percentage Used" | awk '{print $NF}' | sed 's/%//')
    
    echo "Диск: /dev/$disk - Статус: $status"
    echo "Детали: Ошибок носителя: $media_errors, Процент использования: $percentage_used%"
    
    # Проверка состояния
    if [ "$media_errors" -gt 0 ]; then
        status="WARNING"
    elif [ "$percentage_used" -ge 80 ]; then
        status="WARNING"
    fi
    
    if [ "$status" == "PASSED" ]; then
        continue
    elif [ "$status" == "WARNING" ]; then
        warnings+=("$disk: $status (Ошибок носителя: $media_errors, Процент использования: $percentage_used%)")
    elif [ "$status" == "FAILED" ]; then
        errors+=("$disk: $status (Ошибок носителя: $media_errors, Процент использования: $percentage_used%)")
    fi
done
echo ""

# Формируем сообщение
message="Мониторинг SMART дисков на хосте $(hostname):\n"

if [ ${#warnings[@]} -gt 0 ]; then
    message+="\nWarnings:\n"
    for warning in "${warnings[@]}"; do
        message+="* $warning\n"
    done
fi

if [ ${#errors[@]} -gt 0 ]; then
    message+="\nErrors:\n"
    for error in "${errors[@]}"; do
        message+="* $error\n"
    done
fi

# Отправляем уведомление при наличии проблем
if [ ${#warnings[@]} -gt 0 ] || [ ${#errors[@]} -gt 0 ]; then
    if [ -n "$TELEGRAM_TOPIC_ID" ]; then
        # Отправка в топик
        curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "message_thread_id=$TELEGRAM_TOPIC_ID" \
            -d "text=$(echo -e "$message" | sed 's/\*/\\\*/g')" \
            -d "parse_mode=Markdown"
    else
        # Обычная отправка в чат
        curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "text=$(echo -e "$message" | sed 's/\*/\\\*/g')" \
            -d "parse_mode=Markdown"
    fi
fi
