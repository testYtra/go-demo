cd cloud-provisioning

scripts/dm-swarm.sh

eval $(docker-machine env swarm-1)

docker node ls

scripts/dm-test-swarm.sh

eval $(docker-machine env swarm-test-1)

docker node ls

eval $(docker-machine env swarm-1)

docker service create --name registry \
    -p 5000:5000 \
    --reserve-memory 100m \
    --mount "type=bind,source=$PWD,target=/var/lib/registry" \
    registry:2.5.0

eval $(docker-machine env swarm-test-1)

docker service create --name registry \
    -p 5000:5000 \
    --reserve-memory 100m \
    --mount "type=bind,source=$PWD,target=/var/lib/registry" \
    registry:2.5.0

docker node update \
    --label-add env=prod-like \
    swarm-test-2

docker node inspect --pretty swarm-test-2

docker node update \
    --label-add env=prod-like \
    swarm-test-3

docker service create --name util \
    --constraint 'node.labels.env == prod-like' \
    alpine sleep 1000000000

docker service ps util

docker service scale util=6

docker service ps util

docker service create --name util-2 \
    --mode global \
    --constraint 'node.labels.env == prod-like' \
    alpine sleep 1000000000

docker service ps util-2

docker service rm util util-2

scripts/dm-test-swarm-services.sh

eval $(docker-machine env swarm-test-1)

docker service ls

curl -i "$(docker-machine ip swarm-test-1)/demo/hello"

scripts/dm-swarm-services.sh

eval $(docker-machine env swarm-1)

docker service ls

git clone https://github.com/vfarcic/go-demo.git

cd go-demo

eval $(docker-machine env swarm-test-1)

docker-compose \
    -f docker-compose-test-local.yml \
    run --rm unit

docker-compose \
    -f docker-compose-test-local.yml \
    build app

docker-compose \
    -f docker-compose-test-local.yml \
    up -d staging-dep

docker-compose \
    -f docker-compose-test-local.yml \
    run --rm staging

docker-compose \
    -f docker-compose-test-local.yml \
    down

docker tag go-demo localhost:5000/go-demo:1.1

docker push localhost:5000/go-demo:1.1

docker service ps go-demo -f desired-state=running

docker service update \
    --image=localhost:5000/go-demo:1.1 \
    go-demo

docker service ps go-demo -f desired-state=running

export HOST_IP=localhost

docker-compose \
    -f docker-compose-test-local.yml \
    run --rm production

eval $(docker-machine env swarm-1)

docker service update \
    --image=localhost:5000/go-demo:1.1 \
    go-demo

eval $(docker-machine env swarm-test-1)

export HOST_IP=$(docker-machine ip swarm-1)

docker-compose \
    -f docker-compose-test-local.yml \
    run --rm production

docker-machine rm -f \
    swarm-1 swarm-2 swarm-3 \
    swarm-test-1 swarm-test-2 swarm-test-3
