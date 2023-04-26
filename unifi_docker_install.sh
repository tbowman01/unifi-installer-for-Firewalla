#!/bin/bash 
# v 1.4.0
path1=/data/unifi
if [ ! -d "$path1" ]; then
        sudo mkdir $path1
	sudo chown pi $path1
	sudo chmod +rw $path1
fi

path2=/home/pi/.firewalla/run/docker/unifi/
if [ ! -d "$path2" ]; then
        sudo mkdir $path2
	sudo chown pi $path2
	sudo chmod +rw $path2
fi

curl https://raw.githubusercontent.com/tbowman01/unifi-installer/main/docker-compose.yaml > $path2/docker-compose.yaml
sudo chown pi $path2/docker-compose.yaml
sudo chmod +rw $path2/docker-compose.yaml
cd $path2

sudo systemctl start docker-compose@unifi

sudo docker ps

echo -n "Starting docker (this can take ~ one minute)"
while [ -z "$(sudo docker ps | grep unifi | grep -o Up)" ]
do
        echo -n "."
        sleep 2s
done
echo "Done"

echo "configuring networks..."
sleep 10
sudo ip route add 172.16.10.0/24 dev br-$(sudo docker network ls | awk '$2 == "unifi_default" {print $1}') table lan_routable
sleep 10
sudo ip route add 172.16.10.0/24 dev br-$(sudo docker network ls | awk '$2 == "unifi_default" {print $1}') table wan_routable
echo address=/unifi/172.16.10.254 > ~/.firewalla/config/dnsmasq_local/unifi
sleep 10
sudo systemctl restart firerouter_dns
sleep 5
sudo docker restart unifi

path3=/home/pi/.firewalla/config/post_main.d
if [ ! -d "$path3" ]; then
        mkdir $path3
        sudo mkdir $path3
	sudo chown pi $path3
	sudo chmod +rw $path3
fi

echo "#!/bin/bash
sudo systemctl start docker
sudo systemctl start docker-compose@unifi
sudo ipset create -! docker_lan_routable_net_set hash:net
sudo ipset add -! docker_lan_routable_net_set 172.16.10.0/24
sudo ipset create -! docker_wan_routable_net_set hash:net
sudo ipset add -! docker_wan_routable_net_set 172.16.10.0/24" >  /home/pi/.firewalla/config/post_main.d/start_unifi.sh

chmod a+x /home/pi/.firewalla/config/post_main.d/start_unifi.sh
chown pi /home/pi/.firewalla/config/post_main.d/start_unifi.sh

echo -n "Restarting docker unifi"
sudo docker start unifi
while [ -z "$(sudo docker ps | grep unifi | grep Up)" ]
do
        echo -n "."
        sleep 2s
done
echo -e "\nStarting the container, please wait....\n"
sleep 60

echo -e "Done!\n\nYou can open https://172.16.10.254:8443 in your favorite browser and set up your UniFi Controller now. (\n\nNote it may not have a certificate so the browser may give you a security warning.)\n\n"
