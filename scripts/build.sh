#!/bin/bash

docker run \
    --rm \
    --volume "$(pwd)/:/src" \
    --workdir "/src/" \
    swift:5.9.1-amazonlinux2 \
    swift build --product OnlineRadioBoxToSpotify -c release -Xswiftc -static-stdlib 
