git clone https://github.com/vfarcic/cloud-provisioning.git

cd cloud-provisioning

scripts/dm-swarm.sh

eval $(docker-machine env swarm-1)

docker node ls

curl -o docker-compose-proxy.yml \
    https://raw.githubusercontent.com/\
vfarcic/docker-flow-proxy/master/docker-compose.yml

cat docker-compose-proxy.yml

export DOCKER_IP=$(docker-machine ip swarm-1)

docker-compose -f docker-compose-proxy.yml \
    up -d consul-server

curl -X PUT -d 'this is a test' \
    "http://$(docker-machine ip swarm-1):8500/v1/kv/msg1"

curl "http://$(docker-machine ip swarm-1):8500/v1/kv/msg1"

curl "http://$(docker-machine ip swarm-1):8500/v1/kv/msg1?raw"

cat docker-compose-proxy.yml

export CONSUL_SERVER_IP=$(docker-machine ip swarm-1)

for i in 2 3; do
    eval $(docker-machine env swarm-$i)

    export DOCKER_IP=$(docker-machine ip swarm-$i)

    docker-compose -f docker-compose-proxy.yml \
        up -d consul-agent
done

curl "http://$(docker-machine ip swarm-2):8500/v1/kv/msg1"

curl -X PUT -d 'this is another test' \
    "http://$(docker-machine ip swarm-2):8500/v1/kv/messages/msg2"

curl -X PUT -d 'this is a test with flags' \
    "http://$(docker-machine ip swarm-3):8500/v1/kv/messages/msg3?flags=1234"

curl "http://$(docker-machine ip swarm-1):8500/v1/kv/?recurse"

curl -X DELETE "http://$(docker-machine ip swarm-2):8500/v1/kv/?recurse"

curl "http://$(docker-machine ip swarm-3):8500/v1/kv/?recurse"

docker-machine rm -f swarm-1 swarm-2 swarm-3
