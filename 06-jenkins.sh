cd cloud-provisioning

git pull

scripts/dm-swarm.sh

eval $(docker-machine env swarm-1)

docker node ls

mkdir -p docker/jenkins

docker service create --name jenkins \
    -p 8082:8080 \
    -p 50000:50000 \
    -e JENKINS_OPTS="--prefix=/jenkins" \
    --mount "type=bind,source=$PWD/docker/jenkins,target=/var/jenkins_home" \
    --reserve-memory 300m \
    jenkinsci/jenkins

docker service ps jenkins

open "http://$(docker-machine ip swarm-1):8082/jenkins"

cat docker/jenkins/secrets/initialAdminPassword

NODE=$(docker service ps \
    -f desired-state=running jenkins \
    | tail -n +2 | awk '{print $4}')

eval $(docker-machine env $NODE)

docker rm -f $(docker ps -qa \
    -f label=com.docker.swarm.service.name=jenkins)

docker service ps jenkins

open "http://$(docker-machine ip swarm-1):8082/jenkins"

open "http://$(docker-machine ip swarm-1):8082/jenkins/pluginManager/available"

scripts/dm-test-swarm-2.sh

eval $(docker-machine env swarm-test-1)

docker node ls

eval $(docker-machine env swarm-test-1)

docker node inspect swarm-test-1 --pretty

docker-machine ssh swarm-test-1

sudo mkdir /workspace && sudo chmod 777 /workspace && exit

export USER=siebe

export PASSWORD=password

docker service create --name jenkins-agent \
    -e COMMAND_OPTIONS="-master \
    http://$(docker-machine ip swarm-1):8082/jenkins \
    -username $USER -password $PASSWORD \
    -labels 'docker' -executors 5" \
    --mode global \
    --constraint 'node.labels.env == jenkins-agent' \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    --mount "type=bind,source=$HOME/.docker/machine/machines,target=/machines" \
    --mount "type=bind,source=/workspace,target=/workspace" \
    vfarcic/jenkins-swarm-agent

docker service ps jenkins-agent

open "http://$(docker-machine ip swarm-1):8082/jenkins/computer/"

docker-machine create -d virtualbox swarm-test-4

docker-machine ssh swarm-test-4

sudo mkdir /workspace && sudo chmod 777 /workspace && exit

TOKEN=$(docker swarm join-token -q worker)

eval $(docker-machine env swarm-test-4)

docker swarm join \
    --token $TOKEN \
    --advertise-addr $(docker-machine ip swarm-test-4) \
    $(docker-machine ip swarm-test-1):2377

eval $(docker-machine env swarm-test-1)

docker node ls

docker service ps jenkins-agent

docker node update \
    --label-add env=jenkins-agent \
    swarm-test-4

docker service ps jenkins-agent

open http://$(docker-machine ip swarm-1):8082/jenkins/computer

scripts/dm-swarm-services-2.sh

eval $(docker-machine env swarm-1)

docker service ls

scripts/dm-test-swarm-services-2.sh

eval $(docker-machine env swarm-test-1)

docker service ls

open http://$(docker-machine ip swarm-1):8082/jenkins/configure

docker-machine ip swarm-1

eval $(docker-machine env swarm-1)

docker service ps go-demo

docker-machine rm -f \
    swarm-1 swarm-2 swarm-3 \
    swarm-test-1 swarm-test-2 \
    swarm-test-3 swarm-test-4
