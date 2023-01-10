#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

forge create ./src/Bridge.sol:Bridge -i --rpc-url process.env.Goerli_RPC_URL --private-key process.env.PRIVATE_KEY