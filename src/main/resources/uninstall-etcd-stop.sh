    echo "__LOG__ stopping etcd server"
    docker exec -it clusterlite-etcd /run-etcd-remove.sh
    docker stop clusterlite-etcd
    docker rm clusterlite-etcd
    rm -Rf __VOLUME__/clusterlite-etcd
