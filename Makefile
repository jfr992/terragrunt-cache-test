.PHONY: help gen-certs up bench-graphs clean-caches

help:
	@echo "Available commands:"
	@echo "  make gen-certs   - Generate self-signed certificates for boring-registry"
	@echo "  make up          - Start cache infrastructure (MinIO + boring-registry)"
	@echo "  make bench-graphs - Run complete benchmark with visualizations"
	@echo "  make clean-caches - Clear all cached data for fresh test"

gen-certs:
	@echo "Generating self-signed certificates for boring-registry..."
	@mkdir -p certs
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout certs/boring-registry.key \
		-out certs/boring-registry.crt \
		-subj "/C=US/ST=State/L=City/O=Test/CN=boring-registry"
	@echo "Certificates generated successfully!"
	@echo "Certificate expires:"
	@openssl x509 -in certs/boring-registry.crt -noout -dates

up:
	docker compose up -d

bench-graphs:
	bash scripts/bench-with-graphs.sh

clean-caches:
	rm -rf ./.cache/tofu-providers/* ./.cache/tg-modules/* ./.data/minio/tofu-mirror/* || true
