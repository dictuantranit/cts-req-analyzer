# RUN on the server that you want to be the leader node
docker network create -d overlay --attachable cts_network_swarm

# docker swarm manager
docker swarm init
# list all current nodes in the swarm
docker node ls
# get token to join as a manager
docker swarm join
# get token to join as a worker
docker swarm join-token