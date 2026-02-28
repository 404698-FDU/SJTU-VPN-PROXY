# Readme

# Intro

This project is to establish SJTU VPN connection in docker container, furthermore, SS proxy server is running in the same container. By this, users can connect to SJTU network and utilize other proxy tool, like clash or Quantumult X, to configure traffic rules as they like. This can allow users customize network traffic, instead of forwarding all traffic to SJTU VPN after connecting to it.

Also, in case of IP protocol issues, VPN connection is forced to use IPv4.


# Prerequisite

(maybe)Able to connect Google :)

# Instruction

1. Change three fields in docker-compose.yml file.
    1. JACCOUNT
    2. JPASSWORD
    3. SS_PASSWORD
2. Run command in the root of the directory
    
    ```
    docker compose up -d --build
    ```
    
3. Configure SS proxy node and proxy tools