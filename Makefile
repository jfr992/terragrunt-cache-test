.PHONY: up bench-graphs clean-caches

# Standard POC targets
up:
	docker compose up -d

bench-graphs:
	bash scripts/bench-with-graphs.sh

clean-caches:
	rm -rf ./.cache/tofu-providers/* ./.cache/tg-modules/* ./.data/minio/tofu-mirror/* || true
