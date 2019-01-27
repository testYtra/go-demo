cd cloud-provisioning

git pull

scripts/dm-swarm.sh

docker-machine ssh swarm-1

tce-load -wi curl wget

wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64

sudo mv jq-linux64 /usr/local/bin/jq

sudo chmod +x /usr/local/bin/jq

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/nodes | jq '.'

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/nodes/swarm-1 | jq '.'

curl -XPOST \
    -d '{
  "Name": "go-demo-db",
  "TaskTemplate": {
    "ContainerSpec": {
      "Image": "mongo:3.2.10"
    }
  }
}' \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services/create | jq '.'

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services | jq '.'

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services/go-demo-db | jq '.'

VERSION=$(curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services/go-demo-db | \
    jq '.Version.Index')

echo $VERSION

ID=$(curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services/go-demo-db | \
    jq --raw-output '.ID')

echo $ID

curl -XPOST \
    -d '{
  "Name": "go-demo-db",
  "TaskTemplate": {
    "ContainerSpec": {
      "Image": "mongo:3.2.10"
    }
  },
  "Mode": {
    "Replicated": {
      "Replicas": 3
    }
  }
}' \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services/$ID/update?version=$VERSION

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/tasks | jq '.'

exit

eval $(docker-machine env swarm-1)

NODE=$(docker service ps \
    -f desired-state=running \
    go-demo-db \
    | tail -n 1 \
    | awk '{print $4}')

echo $NODE

docker-machine ssh $NODE

ID=$(docker ps -qa | tail -n 1)

echo $ID

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/containers/$ID/stats

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/containers/$ID/stats?stream=false

curl -XDELETE \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services/go-demo-db

curl \
    --unix-socket /var/run/docker.sock \
    http:/localhost/services

exit

eval $(docker-machine env swarm-1)

docker network create --driver overlay proxy

docker network create --driver overlay go-demo

docker service create --name swarm-listener \
    --network proxy \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e DF_NOTIF_CREATE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/reconfigure \
    -e DF_NOTIF_REMOVE_SERVICE_URL=http://proxy:8080/v1/docker-flow-proxy/remove \
    --constraint 'node.role==manager' \
    vfarcic/docker-flow-swarm-listener

docker service create --name proxy \
    -p 80:80 \
    -p 443:443 \
    --network proxy \
    -e MODE=swarm \
    -e LISTENER_ADDRESS=swarm-listener \
    vfarcic/docker-flow-proxy

docker service create --name go-demo-db \
  --network go-demo \
  mongo:3.2.10

docker service create --name go-demo \
  -e DB=go-demo-db \
  --network go-demo \
  --network proxy \
  --label com.df.notify=true \
  --label com.df.distribute=true \
  --label com.df.servicePath=/demo \
  --label com.df.port=8080 \
  vfarcic/go-demo:1.0

docker service ls

curl -i "$(docker-machine ip swarm-1)/demo/hello"

docker service rm go-demo

docker-machine rm -f swarm-1 swarm-2 swarm-3
