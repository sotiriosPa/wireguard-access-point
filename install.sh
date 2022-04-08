#!/bin/bash
WPA_WIFI_SSID="Bel-Air"
WPA_WIFI_PWD="K!ng0fbel@!r"
HOSTAPD_WIFI_SSID="Lux-Belair"
HOSTAPD_WIFI_PWD="8120106de+50L"

echo "===> Welcome to the RouterPi installer script <==="

echo "Updating raspberry pi..."
sudo apt update && sudo apt upgrade -y
echo "Updated ✓ \n"

echo "Installing all dependencies..."
sudo apt -y install iptables wireguard wireguard-tools hostapd dnsmasq
echo "Installed ✓ \n"

echo "Setting up wpa-supplicant..."
echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=GB" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=GB
network={
        ssid="'$WPA_WIFI_SSID'"
        psk="'$WPA_WIFI_PWD'"
}' > /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
echo "Done ✓ \n"

echo "Setting static ip for wlan0 and eth0..."
echo 'interface eth0
      static ip_address=10.20.1.1/24
interface wlan0
      static ip_address=10.20.2.1/24
      nohook wpa_supplicant' >> /etc/dhcpcd.conf
echo "Done ✓ \n"

echo "Enabling IPv4 forwarding..."
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p
echo "Enabled ✓"

echo "Setting up wireguard profile..."
cp wg0.conf /etc/wireguard/wg0.conf
sudo systemctl enable wg-quick@wg0.service
sudo wg-quick up wg0
echo "Done ✓"

echo "Setting up dnsmasq..."
echo 'interface=eth0
dhcp-range=10.20.1.100,10.20.1.200,255.255.255.0,300d
domain=eth
address=/rt/wlan/10.20.1.1
interface=wlan0
dhcp-range=10.20.2.100,10.20.2.200,255.255.255.0,300d
domain=wlan
address=/rt/wlan/10.20.2.1' >> /etc/dnsmasq.conf
echo "Done ✓ \n"

echo "Setting up hostapd..."
sudo rfkill unblock wlan
sed -ir 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' /etc/default/hostapd
echo 'ssid='$HOSTAPD_WIFI_SSID'
wpa_passphrase='$HOSTAPD_WIFI_PWD'
interface=wlan0
# the interface used by the AP
hw_mode=a
# a simply means 5GHz
channel=40
# the channel to use, 0 means the AP will search for the channel with the least interferences
ieee80211d=1
# limit the frequencies used to those allowed in the country
country_code=BE
# the country code
#ieee80211n=1
# 802.11n support
ieee80211ac=1
# 802.11ac support
wmm_enabled=1
# QoS support
ht_capab=[HT40-]
#40 MHz bandwith
# the name of the AP
auth_algs=1
# 1=wpa, 2=wep, 3=both
wpa=2
# WPA2 only
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP' > /etc/hostapd/hostapd.conf
sudo systemctl unmask hostapd.service
sudo systemctl enable hostapd.service
sudo systemctl start hostapd.service
echo "Done ✓ \n"

echo "Setting up iptables..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
sudo iptables -A FORWARD -i wg0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o wg0 -j ACCEPT
echo "Done ✓"

echo "Saving iptables..."
sudo apt install iptables-persistent
echo "Done ✓ \n"
