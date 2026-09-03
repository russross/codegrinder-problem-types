all: .proxy-c .proxy-go .proxy-javascript .proxy-prolog .proxy-python .proxy-riscv .proxy-rust .proxy-sqlite

.proxy-c: c/Dockerfile
	docker build --network=host --pull -t codegrinder/c c
	touch .proxy-c

.proxy-go: go/Dockerfile
	docker build --network=host --pull -t codegrinder/go go
	touch .proxy-go

.proxy-javascript: javascript/Dockerfile
	docker build --network=host --pull -t codegrinder/javascript javascript
	touch .proxy-javascript

.proxy-prolog: prolog/Dockerfile
	docker build --network=host --pull -t codegrinder/prolog prolog
	touch .proxy-prolog

.proxy-python: python/Dockerfile
	docker build --network=host --pull -t codegrinder/python python
	touch .proxy-python

.proxy-riscv: riscv/Dockerfile
	docker build --network=host --pull -t codegrinder/riscv riscv
	touch .proxy-riscv

.proxy-rust: rust/Dockerfile
	docker build --network=host --pull -t codegrinder/rust rust
	touch .proxy-rust

.proxy-sqlite: sqlite/Dockerfile
	docker build --network=host --pull -t codegrinder/sqlite sqlite
	touch .proxy-sqlite
