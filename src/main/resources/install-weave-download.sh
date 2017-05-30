    echo "__LOG__ downloading weave script"
    docker_location="$(which docker)"
    weave_destination="${docker_location/docker/weave}"
    curl -L git.io/weave -o ${weave_destination}
    chmod u+x ${weave_destination}

