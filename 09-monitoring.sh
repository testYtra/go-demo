cd cloud-provisioning

git pull

scripts/dm-swarm-5.sh

eval $(docker-machine env swarm-1)

docker node ls

docker-machine ssh swarm-1

docker network create --driver overlay proxy

curl -o proxy-stack.yml \
    https://raw.githubusercontent.com/\
vfarcic/docker-flow-proxy/master/docker-compose-stack.yml

docker stack deploy \
    -c proxy-stack.yml proxy

curl -o go-demo-stack.yml \
    https://raw.githubusercontent.com/\
vfarcic/go-demo/master/docker-compose-stack.yml

docker stack deploy \
    -c go-demo-stack.yml go-demo

docker service create --name util \
    --network proxy \
    --mode global \
    alpine sleep 1000000000

docker service ls

docker service create \
    --name node-exporter \
    --mode global \
    --network proxy \
    --mount "type=bind,source=/proc,target=/host/proc" \
    --mount "type=bind,source=/sys,target=/host/sys" \
    --mount "type=bind,source=/,target=/rootfs" \
    prom/node-exporter:v0.14.0 \
    -collector.procfs /host/proc \
    -collector.sysfs /host/proc \
    -collector.filesystem.ignored-mount-points \
    "^/(sys|proc|dev|host|etc)($|/)"

docker service ps node-exporter

UTIL_ID=$(docker ps -q --filter \
    label=com.docker.swarm.service.name=util)

docker exec -it $UTIL_ID \
    apk add --update curl drill

docker exec -it $UTIL_ID \
    curl http://node-exporter:9100/metrics

docker service create --name cadvisor \
    -p 8080:8080 \
    --mode global \
    --network proxy \
    --mount "type=bind,source=/,target=/rootfs" \
    --mount "type=bind,source=/var/run,target=/var/run" \
    --mount "type=bind,source=/sys,target=/sys" \
    --mount "type=bind,source=/var/lib/docker,target=/var/lib/docker" \
    google/cadvisor:v0.24.1

docker service ps cadvisor

exit

open "http://$(docker-machine ip swarm-1):8080"

docker-machine ssh swarm-1

docker service update \
    --publish-rm 8080 cadvisor

docker service inspect cadvisor --pretty

UTIL_ID=$(docker ps -q --filter \
    label=com.docker.swarm.service.name=util)

docker exec -it $UTIL_ID \
    apk add --update curl drill

docker exec -it $UTIL_ID \
    curl http://cadvisor:8080/metrics

UTIL_ID=$(docker ps -q --filter \
    label=com.docker.swarm.service.name=util)

docker exec -it $UTIL_ID \
    drill tasks.node-exporter

exit

cat conf/prometheus.yml

mkdir -p docker/prometheus

eval $(docker-machine env swarm-1)

docker service create \
    --name prometheus \
    --network proxy \
    -p 9090:9090 \
    --mount "type=bind,source=$PWD/conf/prometheus.yml,target=/etc/prometheus/prometheus.yml" \
    --mount "type=bind,source=$PWD/docker/prometheus,target=/prometheus" \
    prom/prometheus:v1.2.1

container_memory_usage_bytes

container_memory_usage_bytes{id!="/"}

container_memory_usage_bytes{container_label_com_docker_swarm_service_name="cadvisor"}

docker service create \
    --name grafana \
    --network proxy \
    -p 3000:3000 \
    grafana/grafana:3.1.1

docker service ps grafana

open "http://$(docker-machine ip swarm-1):3000"

open "http://$(docker-machine ip swarm-1):3000"

docker service create \
    --name elasticsearch \
    --network proxy \
    --reserve-memory 300m \
    -p 9200:9200 \
    elasticsearch:2.4

docker service ps elasticsearch

docker service create \
    --name logstash \
    --mount "type=bind,source=$PWD/conf,target=/conf" \
    --network proxy \
    -e LOGSPOUT=ignore \
    logstash:2.4 \
    logstash -f /conf/logstash.conf

docker service ps logstash

docker-machine ssh swarm-1

docker service create \
    --name logspout \
    --network proxy \
    --mode global \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e SYSLOG_FORMAT=rfc3164 \
    gliderlabs/logspout \
    syslog://logstash:51415

exit

docker service ps logspout

open "http://$(docker-machine ip swarm-1):3000"

docker-machine ssh swarm-1

docker service rm node-exporter

docker service create \
    --name node-exporter \
    --mode global \
    --network proxy \
    --mount "type=bind,source=/proc,target=/host/proc" \
    --mount "type=bind,source=/sys,target=/host/sys" \
    --mount "type=bind,source=/,target=/rootfs" \
    --mount "type=bind,source=/etc/hostname,target=/etc/host_hostname" \
    -e HOST_HOSTNAME=/etc/host_hostname \
    basi/node-exporter:v0.1.1 \
    -collector.procfs /host/proc \
    -collector.sysfs /host/proc \
    -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)" \
    -collector.textfile.directory /etc/node-exporter/ \
    -collectors.enabled="conntrack,diskstats,entropy,filefd,filesystem,loadavg,mdadm,meminfo,netdev,netstat,stat,textfile,time,vmstat,ipvs"

docker service update \
    --container-label-add \
    com.docker.stack.namespace=db \
    go-demo_db

docker service inspect go-demo_db \
    --format \
    "{{.Spec.TaskTemplate.ContainerSpec.Labels}}"

docker service update \
    --container-label-add \
    com.docker.stack.namespace=backend \
    go-demo_main

for s in \
    proxy_proxy \
    logspout \
    logstash \
    util \
    prometheus \
    elasticsearch
do
    docker service update \
        --container-label-add \
        com.docker.stack.namespace=infra \
        $s
done

exit

for i in {1..100}
do
    curl "$(docker-machine ip swarm-1)/demo/hello"
done

for i in {1..100}
do
    curl "$(docker-machine ip swarm-1)/demo/random-error"
done

docker service update \
    --reserve-memory 200m \
    prometheus

docker service ps prometheus

docker service inspect prometheus --pretty

docker service update \
    --reserve-memory 250m logstash

docker service update \
    --reserve-memory 10m go-demo_main

docker service update \
    --reserve-memory 100m go-demo_db

docker service update \
    --reserve-memory 300m elasticsearch

docker service update \
    --reserve-memory 10m proxy_proxy

docker-machine rm -f swarm-1 \
    swarm-2 swarm-3 swarm-4 swarm-5
