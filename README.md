docker-mosquitto
================

Mosquitto MQTT Broker on Docker Image.

This is a fork from [jllopis/docker-mosquitto](https://github.com/jllopis/docker-mosquitto) instead of using `Redis` and `http` it is compiled with the `MySQL` backend.

# Version

**mosquitto** v1.4.10

This version implement MQTT over WebSocket. You can use an MQTT JavaScript library to connect, like Paho: https://github.com/eclipse/paho.mqtt.javascript

It has the auth plugin `https://github.com/jpmens/mosquitto-auth-plug` included. It uses (and is compiled with) support for a `MySQL` backend. The additional config for this plugin (sample `auth-plugin.conf` included) can be bind mounted in the extended configuration directory: `/etc/mosquitto.d`. Any file with a `.conf` extension will be loaded by `mosquitto` on startup.

For details on the auth plugin configuration, refer to the author repository. A little quick&dirty example its included at the end.

The docker images builds with Official Alpine Linux 3.4.


# Build

Use the provide _Makefile_ to build the image.

Alternatively you can start it by means of [docker-compose](https://docs.docker.com/compose): `docker-compose up`. This is useful when testing. It start up _mysql_ and link it to _mosquitto_ so you can test the _auth-plugin_ easily.

## Build the Mosquitto docker image

    $ sudo make image-mosq

You can specify your repository and tag by

    $ sudo make REPOSITORY=my_own_repo/mqtt TAG=v1.4.10

Default for **REPOSITORY** is **s3ler/mosquitto** (should change this) and for **TAG** is **mosquitto version (1.4.10 now)**.

Actually the command executed by make is

    docker build --no-cache -t s3ler/mosquitto:v1.4.10 .

# Persistence and Configuration

If you want to use persistence for the container or just use a custom config file you must use **VOLUMES** from your host or better, data only containers.

The container has three directories that you can use:

- **/etc/mosquitto** to store _mosquitto_ configuration files

- **/etc/mosquitto.d** to store additional configuration files that will be loaded after _/etc/mosquitto/mosquitto.conf_

- **/var/lib/mosquitto** to persist the database

The logger outputs to **stderr** by default.

See the following examples for some guidance:

## Mapping host directories

    $ sudo docker run -ti \
      -v /tmp/mosquitto/etc/mosquitto:/etc/mosquitto \
      -v /tmp/mosquitto/etc/mosquitto.d:/etc/mosquitto.d \
      -v /tmp/mosquitto/var/lib/mosquitto:/var/lib/mosquitto
      -v /tmp/mosquitto/auth-plug.conf:/etc/mosquitto.d/auth-plugin.conf
      --name mqtt \
      -p 1883:1883 \
      -p 9883:9883 \
      s3ler/mosquitto:v1.4.10

## Data Only Containers

You must create a container to hold the directories first:

    $ sudo docker run -d -v /etc/mosquitto -v /etc/mosquitto.d -v /var/lib/mosquitto --name mqtt_data busybox /bin/true

and then just use **VOLUMES_FROM** in your container:

    $ sudo docker run -ti \
      --volumes-from mqtt_data \
      --name mqtt \
      -p 1883:1883 \
      -p 9883:9883 \
      s3ler/mosquitto:v1.4.10

The image will save its auth data (if configured) to _mysql_. You can start and link a _mysql_ container or use an existing _mysql_ instance (remember to reconfigure the _auth-plugin.conf_ file, especially change the example logins).

The included `docker-compose.yml` file is a good example of how to do it.

# Example of authenticated access

By default, there is an `root` superuser added to `auth-plugin.conf` with `mypassword` as root-password.
For further configuration of the mysql container take a look at the [MySQL Docker Container Basics](http://severalnines.com/blog/mysql-docker-containers-understanding-basics) and/or the [MySQL Official Docker Hub Repository](https://hub.docker.com/_/mysql/).
The database schema layout is taken from the [mosquitto-aut-plug example](https://github.com/jpmens/mosquitto-auth-plug/blob/master/examples/mosquitto-mysql.conf).

These steps are automated in the `make` file.

We will use it as an example.

## 1. Create the [container network](https://docs.docker.com/engine/userguide/networking/)

    $ docker network create mosqnet

or

    $ make create-mosqnet

## 2. Start a [MySQL instance](https://hub.docker.com/_/mysql/)

    $ docker run --detach \
      --name=mysql-mosq \
      --env="MYSQL_ROOT_PASSWORD=mypassword" \
      -v ${PWD}/mysql:/var/lib/mysql \
      --net=mosqnet \
      mysql:latest

or

    $ make run-db

## 3. Create database and schema

    $ IPAddress=$(sudo docker inspect mysql-mosq | grep -m3 IPAddress | tail -n1 | cut -d '"' -f 4)
    $ mysql -uroot -pmypassword -h${IPAddress} -P3306 < mosq_db.conf

or

    $ make create-db

## 4. Build Mosquitto image with MySQL backend

    $ docker build --noch-cache -t s3ler/mosquitto:v1.4.10 .

or

    $ make image-mosq

## 5. Start Mosquitto container with the linked MySQL

    $ docker run --detach \
      --name=auth-mosq \
      -p 1883:1883 -p 9883:9883 \
      -v ${PWD}/auth-plugin.conf:/etc/mosquitto.d/auth-plugin.conf \
      --net=mosqnet \
      s3ler/mosquitto:v1.4.10

or

    $ make run-mosq

## 6. Add users to database

Password hashes are generated via `np`.
When you change the passwords in the users_example.conf `bash` file you need to escape $ by using \$ instead.

    $ IPAddress=$(sudo docker inspect mysql-mosq | grep -m3 IPAddress | tail -n1 | cut -d '"' -f 4)
    $ mysql -uroot -pmypassword -h$IPAddress -P3306
    $ USE mosq;
    $ # insert users
    $ INSERT INTO users (username, pw) VALUES ('jjolie', 'PBKDF2$sha256$901$YR1fzF00XJvYlWhJ$qJMliJ/cOCfGJrDWG7ZigFw5XlJ6822D');
    $ INSERT INTO users (username, pw, super) VALUES ('S1', 'PBKDF2$sha256$901$EggwHLVb+LGQD3ZO$9+lT7hh7LcO62ESVfqTacZQUf2Crz9Oi', 1);
    $ # insert acls for jjolie
    $ INSERT INTO acls (username, topic, rw) VALUES ('jjolie', 'loc/lastloc/jjolie', 0);
    $ INSERT INTO acls (username, topic, rw) VALUES ('jjolie', 'loc/jjolie', 1);
    $ exit

or

    $ ./users_example.conf

## 7. Subscribe to a test channel

In a new terminal:

    $ mosquitto_sub -h localhost -t loc/jjolie

## 8. Publish to test channel

In a new terminal:

    $ sudo docker logs auth-mosq -f

Publish in another terminal:

    $ mosquitto_pub -h localhost -t test -m "sample pub"

And... nothing happens because our `anonymous` user has no permission on that channel.

Check the _mosquitto_ log terminal:

    1477671741: New connection from 172.18.0.1 on port 1883.
    1477671741: New client connected from 172.18.0.1 as mosqpub/14725-user-desk (c1, k60).
    1477671741: Sending CONNACK to mosqpub/14725-user-desk (0, 0)
    1477671741: |-- mosquitto_auth_acl_check(..., mosqpub/14725-user-desk, anonymous, test, MOSQ_ACL_WRITE)
    1477671741: |-- aclcheck(anonymous, test, 2) AUTHORIZED=0 by (null)
    1477671741: |--  Cached  [1C72B44ABD3A0F812672FE82CC15AE56FEFE1D97] for (mosqpub/14725-user-desk,anonymous,2)
    1477671741: Denied PUBLISH from mosqpub/14725-use-desk (d0, q0, r0, m0, 'test', ... (10 bytes))
    1477671741: Received DISCONNECT from mosqpub/14725-user-desk
    1477671741: Client mosqpub/14725-user-desk disconnected.


Cool!! Lets try again:

    $ mosquitto_pub -h localhost -t loc/jjolie -m "earth" -u jjolie -P secret


Check the _mosquitto_ log terminal again:

    1477672780: New connection from 172.18.0.1 on port 1883.
    1477672780: |-- mosquitto_auth_unpwd_check(jjolie)
    1477672780: |-- ** checking backend mysql
    1477672780: |-- getuser(jjolie) AUTHENTICATED=1 by mysql
    1477672780: New client connected from 172.18.0.1 as mosqpub/15067-user-desk (c1, k60, u'jjolie').
    1477672780: Sending CONNACK to mosqpub/15067-user-desk (0, 0)
    1477672780: |-- mosquitto_auth_acl_check(..., mosqpub/15067-user-desk, jjolie, loc/jjolie, MOSQ_ACL_WRITE)
    1477672780: |--   mysql: topic_matches(loc/jjolie, loc/jjolie) == 1
    1477672780: |-- aclcheck(jjolie, loc/jjolie, 2) trying to acl with mysql
    1477672780: |-- aclcheck(jjolie, loc/jjolie, 2) AUTHORIZED=1 by mysql
    1477672780: |--  Cached  [95B96203B13DB3E4B5554C56D229A9E10ABA7F7C] for (mosqpub/15067-user-desk,jjolie,2)
    1477672780: |--  Cleanup [760CE6A777DF565A9BB1CAF9CED687567CBCF8D0]
    1477672780: |--  Cleanup [1C72B44ABD3A0F812672FE82CC15AE56FEFE1D97]
    1477672780: Received PUBLISH from mosqpub/15067-user-desk (d0, q0, r0, m0, 'loc/jjolie', ... (5 bytes))
    1477672780: Received DISCONNECT from mosqpub/15067-user-desk


Much better... But, did you get any output in the first `mosquitto_sub` terminal? None. Try this and replay:

    $ mosquitto_sub -h localhost -t loc/jjolie -u S1 -P supersecret

And now everything *should* work! ;)

## Contributors

- See [contributors page](https://github.com/jllopis/docker-mosquitto/graphs/contributors) for a list of contributors (including s3ler).
