# This script creates a user manager for automatic N-keys generation 

# If you need create this file in bash:
# nano /root/wireguard-manager.sh

# After creation, don't forget save it:
# Ctrl+O, Enter, Ctrl+X

# And make it executable:
# chmod +x /root/wireguard-manager.sh

# You can use it:
# bash /root/wireguard-manager.sh

# The menu contains:
# 1) Добавить клиента - add client
# 2) Добавить N клиентов - add N clients
# 3) Удалить клиента - delete client
# 4) Показать список - show list
# 5) Показать конфиг - show config
# 6) Выход - exit

#!/bin/bash
# WireGuard User Manager (совместим с Nyr)
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
CLIENT_DIR="$WG_DIR/clients"
WG_INTERFACE="wg0"

mkdir -p $CLIENT_DIR
umask 077

function add_client() {
    local NAME=$1
    local IP=$2

    wg genkey | tee $CLIENT_DIR/${NAME}_private.key | wg pubkey > $CLIENT_DIR/${NAME}_public.key
    CLIENT_PRIVATE_KEY=$(cat $CLIENT_DIR/${NAME}_private.key)
    CLIENT_PUBLIC_KEY=$(cat $CLIENT_DIR/${NAME}_public.key)
    SERVER_PUBLIC_KEY=$(cat $WG_DIR/server_public.key)
    SERVER_IP=$(curl -s ifconfig.me)
    WG_PORT=$(grep ListenPort $WG_CONF | awk '{print $3}')

    cat > $CLIENT_DIR/${NAME}.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

    echo -e "\n[Peer]\nPublicKey = $CLIENT_PUBLIC_KEY\nAllowedIPs = $IP/32" >> $WG_CONF
    systemctl restart wg-quick@$WG_INTERFACE
    echo "✅ Клиент $NAME ($IP) создан"
}

function add_bulk() {
    read -p "Введите количество клиентов: " COUNT
    LAST_IP=$(grep AllowedIPs $WG_CONF | tail -n 1 | awk -F'[ ./]' '{print $4}')
    [ -z "$LAST_IP" ] && LAST_IP=1

    for ((i=1; i<=$COUNT; i++)); do
        NEXT_IP=$((LAST_IP + i))
        NAME="user$NEXT_IP"
        add_client $NAME "10.8.0.$NEXT_IP"
    done
}

function remove_client() {
    read -p "Имя клиента: " NAME
    PUB=$(cat $CLIENT_DIR/${NAME}_public.key)
    sed -i "/$PUB/,+1d" $WG_CONF
    rm -f $CLIENT_DIR/${NAME}_*
    systemctl restart wg-quick@$WG_INTERFACE
    echo "🗑 Клиент $NAME удалён"
}

function list_clients() {
    echo "Список клиентов:"
    grep -E "PublicKey|AllowedIPs" $WG_CONF
}

function show_config() {
    read -p "Имя клиента: " NAME
    cat $CLIENT_DIR/${NAME}.conf
    echo "QR-код:"
    qrencode -t ansiutf8 < $CLIENT_DIR/${NAME}.conf
}

PS3="Выберите действие: "
select opt in "Добавить клиента" "Добавить N клиентов" "Удалить клиента" "Показать список" "Показать конфиг" "Выход"; do
    case $REPLY in
        1) read -p "Имя клиента: " NAME; read -p "IP (например 10.8.0.10): " IP; add_client $NAME $IP ;;
        2) add_bulk ;;
        3) remove_client ;;
        4) list_clients ;;
        5) show_config ;;
        6) exit 0 ;;
        *) echo "Неверный выбор" ;;
    esac
done
