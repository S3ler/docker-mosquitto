DOCKER=docker
REPOSITORY?=s3ler/mosquitto
TAG?=v1.4.10

all:
	@echo "Mosquitto version: ${TAG}"
	@echo ""
	@echo "Commands:"
	@echo "  make create-mosqnet : creates the mosqnet network"
	@echo "  make run-db : run the mysql container"
	@echo "  make create-db : creates the database in mysql/"
	@echo "  make image-mosq : build the mosquitto image"
	@echo "  make run-mosq : run the mosquitto container"

create-mosqnet:
	@echo "Creating network mosqnet"
	docker network create mosqnet

create-db:
	@echo "Creating database in mysql/"
	./init_mosq_db.sh

run-db:
	@echo "Running the mysql container"
	docker run --detach --name=mysql-mosq \
	     --env="MYSQL_ROOT_PASSWORD=mypassword" \
	     -v ${CURDIR}/mysql:/var/lib/mysql \
	     --net=mosqnet hypriot/rpi-mysql

image-mosq:
	@echo "Building mosquitto image"
	${DOCKER} build --no-cache -t ${REPOSITORY}:${TAG} .

run-mosq:
	@echo "Building mosquitto image"
	docker run --detach --name=auth-mosq \
	     -p 1883:1883 -p 9883:9883 \
	     -v ${CURDIR}/auth-plugin.conf:/etc/mosquitto.d/auth-plugin.conf \
	     --net=mosqnet ${REPOSITORY}:${TAG}
