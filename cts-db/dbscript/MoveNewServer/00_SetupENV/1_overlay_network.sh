# RUN on each server what you want to join into the swarm network
# setup overlay network

#ufw
sudo ufw allow 2377/tcp
sudo ufw allow 7946/tcp
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp
sudo ufw allow 3306/tcp
sudo ufw allow ssh
sudo ufw enable
sudo ufw status verbose

#iptables
sudo iptables -A INPUT -p tcp --dport 7946 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 7946 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4789 -j ACCEPT