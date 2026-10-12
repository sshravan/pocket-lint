sudo systemctl stop ollama; sudo systemctl disable ollama; sudo rm -f /usr/local/bin/ollama; sudo rm -f /etc/systemd/system/ollama.service; sudo systemctl daemon-reload; sudo rm -rf /usr/share/ollama; sudo userdel -r ollama 2>/dev/null; 
sudo groupdel ollama 2>/dev/null
