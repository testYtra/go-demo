
aws --version

export AWS_ACCESS_KEY_ID=AKIAIMO3GA7HKKFJJORA

export AWS_SECRET_ACCESS_KEY=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

export AWS_DEFAULT_REGION=eu-west-1

aws ec2 describe-availability-zones \
    --region $AWS_DEFAULT_REGION

AWS_ZONE[1]=a

AWS_ZONE[2]=b

AWS_ZONE[3]=c

AWS_ZONE[4]=a

AWS_ZONE[5]=b

cd cloud-provisioning

git pull

docker-machine create \
    --driver amazonec2 \
    --amazonec2-zone ${AWS_ZONE[1]} \
    --amazonec2-tags "type,manager" \
    swarm-1

aws ec2 describe-instances \
    --filter Name=tag:Name,Values=swarm-1

MANAGER_IP=$(aws ec2 describe-instances \
    --filter Name=tag:Name,Values=swarm-1 \
    | jq -r ".Reservations[0].Instances[0].PrivateIpAddress")

echo $MANAGER_IP

eval $(docker-machine env swarm-1)

docker swarm init \
    --advertise-addr $MANAGER_IP

docker node ls

aws ec2 describe-security-groups \
    --filter "Name=group-name,Values=docker-machine"

SECURITY_GROUP_ID=$(aws ec2 \
    describe-security-groups \
    --filter \
    "Name=group-name,Values=docker-machine" | \
    jq -r '.SecurityGroups[0].GroupId')

for p in 2377 7946 4789; do
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port $p \
        --source-group $SECURITY_GROUP_ID
done

for p in 7946 4789; do
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol udp \
        --port $p \
        --source-group $SECURITY_GROUP_ID
done

aws ec2 describe-security-groups \
    --filter \
    "Name=group-name,Values=docker-machine"

MANAGER_TOKEN=$(docker swarm join-token -q manager)

for i in 2 3; do
    docker-machine create \
        --driver amazonec2 \
        --amazonec2-zone ${AWS_ZONE[$i]} \
        --amazonec2-tags "type,manager" \
        swarm-$i

    IP=$(aws ec2 describe-instances \
        --filter Name=tag:Name,Values=swarm-$i \
        | jq -r ".Reservations[0].Instances[0].PrivateIpAddress")

    eval $(docker-machine env swarm-$i)

    docker swarm join \
        --token $MANAGER_TOKEN \
        --advertise-addr $IP \
        $MANAGER_IP:2377
done

WORKER_TOKEN=$(docker swarm join-token -q worker)

for i in 4 5; do
  docker-machine create \
    --driver amazonec2 \
    --amazonec2-zone ${AWS_ZONE[$i]} \
    --amazonec2-tags "type,worker" \
    swarm-$i

  IP=$(aws ec2 describe-instances \
    --filter Name=tag:Name,Values=swarm-$i \
    | jq -r ".Reservations[0].Instances[0].PrivateIpAddress")

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

curl "$(docker-machine ip swarm-1)/demo/hello"

for p in 80 443; do
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port $p \
        --cidr "0.0.0.0/0"
done

curl "$(docker-machine ip swarm-1)/demo/hello"

for i in 1 2 3 4 5; do
    docker-machine rm -f swarm-$i
done

aws ec2 delete-security-group \
    --group-id $SECURITY_GROUP_ID

aws ec2 create-key-pair \
    --key-name devops21 \
    | jq -r '.KeyMaterial' >devops21.pem

mv devops21.pem $HOME/.ssh/devops21.pem

chmod 400 $HOME/.ssh/devops21.pem

export KEY_PATH=$HOME/.ssh/devops21.pem

DNS=[...]

MANAGER_IP=[...]

ssh -i $KEY_PATH docker@$MANAGER_IP

docker node ls

sudo docker network create --driver overlay proxy

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

docker service ls

exit

curl $DNS/demo/hello

ssh -i $KEY_PATH docker@$MANAGER_IP

docker node ls

docker node ls

docker node ls

export AWS_DEFAULT_REGION=us-east-1

export AWS_ACCESS_KEY_ID=[...]

export AWS_SECRET_ACCESS_KEY=[...]

curl https://editions-us-east-1.s3.amazonaws.com/aws/stable/Docker.tmpl

curl https://editions-us-east-1.s3.amazonaws.com/aws/stable/Docker.tmpl \
    | jq '.Metadata'

aws cloudformation create-stack \
    --template-url https://editions-us-east-1.s3.amazonaws.com/aws/stable/Docker.tmpl \
    --stack-name swarm \
    --capabilities CAPABILITY_IAM \
    --parameters \
    ParameterKey=KeyName,ParameterValue=devops21 \
    ParameterKey=InstanceType,ParameterValue=t2.micro \
    ParameterKey=ManagerInstanceType,ParameterValue=t2.micro \
    ParameterKey=ManagerSize,ParameterValue=3 \
    ParameterKey=ClusterSize,ParameterValue=1

aws cloudformation describe-stack-resources \
    --stack-name swarm

aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=swarm-Manager"

aws cloudformation delete-stack \
    --stack-name swarm

cd terraform/aws

export AWS_ACCESS_KEY_ID=[...]

export AWS_SECRET_ACCESS_KEY=[...]

export AWS_DEFAULT_REGION=us-east-1

cat packer-ubuntu-docker.json

packer build -machine-readable \
    packer-ubuntu-docker.json \
    | tee packer-ubuntu-docker.log

cd terraform/aws

export AWS_ACCESS_KEY_ID=[...]

export AWS_SECRET_ACCESS_KEY=[...]

export AWS_DEFAULT_REGION=us-east-1

export TF_VAR_swarm_ami_id=$(\
    grep 'artifact,0,id' \
    packer-ubuntu-docker.log \
    | cut -d, -f6 | cut -d: -f2)

terraform plan

terraform graph

terraform graph | dot -Tpng > graph.png

terraform plan \
    -target aws_instance.swarm-manager \
    -var swarm_init=true \
    -var swarm_managers=1

export KEY_PATH=$HOME/.ssh/devops21.pem

cp $KEY_PATH devops21.pem

terraform apply \
    -target aws_instance.swarm-manager \
    -var swarm_init=true \
    -var swarm_managers=1

terraform output swarm_manager_1_public_ip

ssh -i devops21.pem \
    ubuntu@$(terraform output \
    swarm_manager_1_public_ip) \
    docker node ls

export TF_VAR_swarm_manager_token=$(ssh \
    -i devops21.pem \
    ubuntu@$(terraform output \
    swarm_manager_1_public_ip) \
    docker swarm join-token -q manager)

export TF_VAR_swarm_worker_token=$(ssh \
    -i devops21.pem \
    ubuntu@$(terraform output \
    swarm_manager_1_public_ip) \
    docker swarm join-token -q worker)

export TF_VAR_swarm_manager_ip=$(terraform \
    output swarm_manager_1_private_ip)

terraform plan

terraform apply

ssh -i devops21.pem \
    ubuntu@$(terraform \
    output swarm_manager_1_public_ip)

docker node ls

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

docker service ls

curl localhost/demo/hello

exit

curl $(terraform output \
    swarm_manager_1_public_ip)/demo/hello

terraform state show "aws_instance.swarm-worker[1]"

aws ec2 terminate-instances \
    --instance-ids i-6a3a1964

terraform plan

terraform apply

terraform destroy -force
