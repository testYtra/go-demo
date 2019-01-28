export DIGITALOCEAN_ACCESS_TOKEN=6215a53fbbe6df914265d4e2d7f1b464b697b5d7eb0acecfd0ea1f4460997cdc

curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/regions" \
    | jq '.'

export DIGITALOCEAN_REGION=ams3

cd cloud-provisioning

git pull

docker-machine create \
    --driver digitalocean \
    --digitalocean-size 1gb \
    --digitalocean-private-networking \
    swarm-1

curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/droplets" \
    | jq '.'

MANAGER_IP=$(curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/droplets" \
    | jq -r '.droplets[]
    | select(.name=="swarm-1").networks.v4[]
    | select(.type=="private").ip_address')

echo $MANAGER_IP

eval $(docker-machine env swarm-1)

docker swarm init \
    --advertise-addr $MANAGER_IP

docker node ls

MANAGER_TOKEN=$(docker swarm join-token -q manager)

for i in 2 3; do
  docker-machine create \
    --driver digitalocean \
    --digitalocean-size 1gb \
    --digitalocean-private-networking \
    swarm-$i

  IP=$(curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/droplets" \
    | jq -r ".droplets[]
    | select(.name==\"swarm-$i\").networks.v4[]
    | select(.type==\"private\").ip_address")

  eval $(docker-machine env swarm-$i)

  docker swarm join \
    --token $MANAGER_TOKEN \
    --advertise-addr $IP \
    $MANAGER_IP:2377
done

WORKER_TOKEN=$(docker swarm join-token -q worker)

for i in 4 5; do
  docker-machine create \
    --driver digitalocean \
    --digitalocean-size 1gb \
    --digitalocean-private-networking \
    swarm-$i

  IP=$(curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/droplets" \
    | jq -r ".droplets[]
    | select(.name==\"swarm-$i\").networks.v4[]
    | select(.type==\"private\").ip_address")

  eval $(docker-machine env swarm-$i)

  docker swarm join \
    --token $WORKER_TOKEN \
    --advertise-addr $IP \
    $MANAGER_IP:2377
done

eval $(docker-machine env swarm-1)

docker node ls

docker-machine ssh swarm-1

sudo docker network create --driver overlay proxy

curl -o proxy-stack.yml \
    https://raw.githubusercontent.com/\
vfarcic/docker-flow-proxy/master/docker-compose-stack.yml

sudo docker stack deploy \
    -c proxy-stack.yml proxy

curl -o go-demo-stack.yml \
    https://raw.githubusercontent.com/\
vfarcic/go-demo/master/docker-compose-stack.yml

sudo docker stack deploy \
    -c go-demo-stack.yml go-demo

exit

docker service ls

curl -i $(docker-machine ip swarm-1)/demo/hello

for i in 1 2 3 4 5; do
    docker-machine rm -f swarm-$i
done

cd terraform/do

export DIGITALOCEAN_API_TOKEN=[...]

cat packer-ubuntu-docker.json

packer build -machine-readable \
    packer-ubuntu-docker.json \
    | tee packer-ubuntu-docker.log

export DIGITALOCEAN_TOKEN=[...]

cat packer-ubuntu-docker.log

export TF_VAR_swarm_snapshot_id=$(\
    grep 'artifact,0,id' \
    packer-ubuntu-docker.log \
    | cut -d, -f6 | cut -d: -f2)

echo $TF_VAR_swarm_snapshot_id

ssh-keygen -t rsa

terraform plan \
    -target digitalocean_droplet.swarm-manager \
    -target digitalocean_droplet.swarm-worker

terraform graph

terraform graph | dot -Tpng > graph.png

terraform plan \
    -target digitalocean_droplet.swarm-manager \
    -var swarm_init=true \
    -var swarm_managers=1

terraform apply \
    -target digitalocean_droplet.swarm-manager \
    -var swarm_init=true \
    -var swarm_managers=1

terraform output swarm_manager_1_public_ip

ssh -i devops21-do \
    root@$(terraform output \
    swarm_manager_1_public_ip) \
    docker node ls

export TF_VAR_swarm_manager_token=$(ssh \
    -i devops21-do \
    root@$(terraform output \
    swarm_manager_1_public_ip) \
    docker swarm join-token -q manager)

export TF_VAR_swarm_worker_token=$(ssh \
    -i devops21-do \
    root@$(terraform output \
    swarm_manager_1_public_ip) \
    docker swarm join-token -q worker)

export TF_VAR_swarm_manager_ip=$(terraform \
    output swarm_manager_1_private_ip)

terraform plan \
    -target digitalocean_droplet.swarm-manager \
    -target digitalocean_droplet.swarm-worker

terraform apply \
    -target digitalocean_droplet.swarm-manager \
    -target digitalocean_droplet.swarm-worker

ssh -i devops21-do \
    root@$(terraform \
    output swarm_manager_1_public_ip)

docker node ls

wget https://raw.githubusercontent.com/vfarcic/cloud-provisioning/master/scripts/swarm-services-1.sh

chmod +x swarm-services-1.sh

./swarm-services-1.sh

docker service ls

curl -i localhost/demo/hello

exit

curl -i $(terraform output \
    swarm_manager_1_public_ip)/demo/hello

terraform plan

terraform apply

curl -i $(terraform output \
    floating_ip_1)/demo/hello

terraform state show "digitalocean_droplet.swarm-worker[1]"

curl -i -X DELETE \
    -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
    "https://api.digitalocean.com/v2/droplets/33909722"

terraform plan

terraform apply

terraform destroy -force

curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/snapshots?resource_type=droplet" \
    | jq '.'

SNAPSHOT_ID=$(curl -X GET \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/snapshots?resource_type=droplet" \
    | jq -r '.snapshots[].id')

curl -X DELETE \
    -H "Authorization: Bearer $DIGITALOCEAN_ACCESS_TOKEN" \
    "https://api.digitalocean.com/v2/snapshots/$SNAPSHOT_ID"
