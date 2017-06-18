    echo "__LOG__ stopping etcd server"
    docker exec -it clusterlite-etcd /run-etcd-remove.sh || \
        echo "__LOG__ warning: failure to detach etcd server"
    docker stop clusterlite-etcd || \
        echo "__LOG__ warning: failure to stop etcd container"
    docker rm clusterlite-etcd || \
        echo "__LOG__ warning: failure to remove etcd container"
    rm -Rf __VOLUME__/clusterlite-etcd || \
        echo "__LOG__ warning: failure to remove etcd data"
