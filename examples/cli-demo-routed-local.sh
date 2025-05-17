#!/bin/bash

# this scripts sends a routed message from a -> p -> q -> q2 -> b
# where p and q run using the intermediary server

# here the intermediaries also need to use the feature "use_local_certificate":
#
#    cargo run --features use_local_certificate --bin demo-intermediary -- --port 3011 localhost:3001
#    cargo run --features use_local_certificate --bin demo-intermediary -- --port 3012 localhost:3002
#
# (you should run these in separate terminals, together with the SSL proxy)

cargo install --path . --features use_local_certificate

echo "---- cleanup the database"
rm -f a.sqlite b.sqlite

echo
echo "==== create sender and receiver"
for entity in a b;
do
    echo "------ $entity (identifier for ${entity%%[0-9]*}) uses did:peer with local transport"
    port=$((${port:-1024} + RANDOM % 1000))
    tsp --database "${entity%%[0-9]*}" create-peer --tcp localhost:$port $entity
done
DID_A=$(tsp --database a print a)
DID_P="did:web:localhost%3A3001"
DID_Q="did:web:localhost%3A3002"
DID_B=$(tsp --database b print b)

wait
sleep 2
echo
echo "==== let the nodes introduce each other"

echo "---- A: setup intermediaries"
echo "---- A: verify P"
tsp --database a verify --alias p "$DID_P"

echo "---- A: establish outer relation a<->p"
sleep 2 && tsp --database a request -s a -r p

echo "---- A: establish nested outer relation p<->a" # required for drop-off
sleep 2 && read -d '' DID_A2 DID_P2 <<< $(tsp --database a request --nested -s a -r p)
echo "DID_A2=$DID_A2"
echo "DID_P2=$DID_P2"


echo "---- B: verify Q"
tsp --database b verify --alias q "$DID_Q"

echo "---- B: establish outer relation q<->b"
sleep 2 && tsp --database b request -s b -r q

echo "---- B: establish nested outer relation q<->b" # required for drop-off
sleep 2 && read -d '' DID_B2 DID_Q2 <<< $(tsp --database b request --nested -s b -r q)
echo "DID_B2=$DID_B2"
echo "DID_Q2=$DID_Q2"


echo "==== A: learns of B and Q2, Q OOB"
echo "---- A: verify B"
tsp --database a verify --alias b "$DID_B"

echo "---- A: setup the route to B"
tsp --database a set-route b "p,$DID_Q,$DID_Q2"

wait
sleep 5
echo

echo "==== A: send a routed message to B"
sleep 2 && echo -n "---- A: sent Indirect Message from A to B via P and Q" | tsp --database a send -s a -r b &


echo "==== B: receives message from A"
tsp --yes --database b receive --one b

echo "---- B: verify A"
tsp --database b verify --alias a "$DID_A"

echo "---- B: setup the route to A"
tsp --database b set-route a "q,$DID_P,$DID_P2"

wait
sleep 5
echo

echo "==== B: send a routed message to A"
sleep 2 && echo -n "---- B: sent Indirect Message from B to A via Q and P" | tsp --database b send -s b -r a &

echo "==== A: receives message from B"
tsp --yes --database a receive --one a

echo "---- cleanup databases"
rm -f a.sqlite b.sqlite
