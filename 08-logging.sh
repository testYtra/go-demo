cd cloud-provisioning

git pull

scripts/dm-swarm.sh

eval $(docker-machine env swarm-1)

docker network create --driver overlay elk

docker service create \
    --name elasticsearch \
    --network elk \
    --reserve-memory 500m \
    elasticsearch:2.4

docker service ps elasticsearch

mkdir -p docker/logstash

cp conf/logstash.conf \
    docker/logstash/logstash.conf

cat docker/logstash/logstash.conf

docker service create --name logstash \
    --mount "type=bind,source=$PWD/docker/logstash,target=/conf" \
    --network elk \
    -e LOGSPOUT=ignore \
    --reserve-memory 100m \
    logstash:2.4 logstash -f /conf/logstash.conf

docker service ps logstash

LOGSTASH_NODE=$(docker service ps logstash | tail -n +2 | awk '{print $4}')

eval $(docker-machine env $LOGSTASH_NODE)

LOGSTASH_ID=$(docker ps -q \
    --filter label=com.docker.swarm.service.name=logstash)

docker logs $LOGSTASH_ID

eval $(docker-machine env swarm-1)

docker service create \
    --name logger-test \
    --network elk \
    --restart-condition none \
    debian \
    bash -c "sleep 10; \
    logger -n logstash -P 51415 hello world"

eval $(docker-machine env $LOGSTASH_NODE)

docker logs $LOGSTASH_ID

eval $(docker-machine env swarm-1)

docker service rm logger-test

docker service create --name logspout \
    --network elk \
    --mode global \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e SYSLOG_FORMAT=rfc3164 \
    gliderlabs/logspout syslog://logstash:51415

docker service ps logspout

docker service create --name registry \
    -p 5000:5000 \
    --reserve-memory 100m \
    registry

docker service ps registry

eval $(docker-machine env $LOGSTASH_NODE)

docker logs $LOGSTASH_ID

docker network create --driver overlay proxy

docker network create --driver overlay proxy

curl -o docker-compose-stack.yml \
    https://raw.githubusercontent.com/\
vfarcic/docker-flow-proxy/master/docker-compose-stack.yml

docker stack deploy \
    -c docker-compose-stack.yml proxy

docker service create --name kibana \
    --network elk \
    --network proxy \
    -e ELASTICSEARCH_URL=http://elasticsearch:9200 \
    --reserve-memory 50m \
    --label com.df.notify=true \
    --label com.df.distribute=true \
    --label com.df.servicePath=/app/kibana,/bundles,/elasticsearch \
    --label com.df.port=5601 \
    kibana:4.6

docker service ps kibana

open "http://$(docker-machine ip swarm-1)/app/kibana"

docker-machine rm -f swarm-1 swarm-2 swarm-3
