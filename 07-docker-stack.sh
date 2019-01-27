cd cloud-provisioning

git pull

scripts/dm-swarm.sh

docker-machine ssh swarm-1

docker network create --driver overlay proxy

curl -o docker-compose-stack.yml \
    https://raw.githubusercontent.com/\
vfarcic/docker-flow-proxy/master/docker-compose-stack.yml

docker stack deploy \
    -c docker-compose-stack.yml proxy

docker stack ps proxy

curl -o docker-compose-go-demo.yml \
    https://raw.githubusercontent.com/\
vfarcic/go-demo/master/docker-compose-stack.yml

docker stack deploy \
    -c docker-compose-go-demo.yml go-demo

docker stack ps go-demo

curl -i "localhost/demo/hello"
