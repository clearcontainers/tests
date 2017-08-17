# NGINX image for Intel® Clear Containers swarm tests

To build the nginx image used in our swarm tests, 
follow these steps:

1. Build the nginx image:

```
$ docker build -t $name -f Dockerfile.nginx .
```

2. Verify the nginx image:

```
$ docker run -ti $name bash

```
