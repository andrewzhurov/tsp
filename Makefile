pq:
	lsof -t -i tcp:3001 | xargs kill -9 || true
	lsof -t -i tcp:3002 | xargs kill -9 || true
	lsof -t -i tcp:3011 | xargs kill -9 || true
	lsof -t -i tcp:3012 | xargs kill -9 || true
	cd ~/gits/tsp/examples/test && npx local-ssl-proxy --config ./ssl-proxy.json &
	INTERMEDIARY_NAME=P cargo run --features use_local_certificate --bin demo-intermediary -- --port 3011 localhost:3001 &
	INTERMEDIARY_NAME=Q cargo run --features use_local_certificate --bin demo-intermediary -- --port 3012 localhost:3002 &

pq_demo: pq
	cd examples && ./cli-demo-routed-local.sh
