for i in 1 2 3; do
    docker-machine create -d virtualbox node-$i
done

eval $(docker-machine env node-1)

docker swarm init \
    --advertise-addr $(docker-machine ip node-1)

docker swarm join-token -q manager

TOKEN=$(docker swarm join-token -q worker)

for i in 2 3; do
  eval $(docker-machine env node-$i)

  docker swarm join \
    --token $TOKEN \
    --advertise-addr $(docker-machine ip node-$i) \
    $(docker-machine ip node-1):2377
done

eval $(docker-machine env node-1)

docker node ls

docker network create --driver overlay go-demo

docker network ls

docker service create --name go-demo-db \
  --network go-demo \
  mongo:3.2.10

docker service ls

docker service inspect go-demo-db

exit 1

docker service create -d --name go-demo \
  -e DB=go-demo-db \
  --network go-demo \
  vfarcic/go-demo:1.0

docker service ls

docker service scale go-demo=5

docker service ls

docker service ps go-demo

docker-machine rm -f node-3

docker service ps go-demo

docker-machine rm -f node-1 node-2
