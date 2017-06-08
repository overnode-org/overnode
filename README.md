# clusterlite
Simple but powerful alternative to Kubernetes and Docker Swarm

sbt "universal:packageBin"
publish.sh
publish.sh --no-push
vagrant up


docker run -it --rm webintrinsics/clusterlite:0.1.0 cat /clusterlite > /usr/bin/clusterlite