.PHONY: build clean test install

build: bin/chesscli

bin/chesscli: $(shell find src priv -type f) gleam.toml bundle_entry.mjs
	gleam build --target javascript
	mkdir -p bin
	bun build --compile --bytecode --outfile bin/chesscli bundle_entry.mjs

test:
	gleam test --target javascript

install: bin/chesscli
	mkdir -p ~/.local/bin
	cp bin/chesscli ~/.local/bin/chesscli

clean:
	rm -rf bin build
