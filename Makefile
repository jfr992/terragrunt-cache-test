.PHONY: help gen-certs up restart bench-graphs clean-caches

help:
	@echo "Available commands:"
	@echo "  make gen-certs    - Generate self-signed certificates for boring-registry"
	@echo "  make up           - Start cache infrastructure (MinIO + boring-registry)"
	@echo "  make restart      - Restart all services (use after gen-certs)"
	@echo "  make bench-graphs - Run complete benchmark with visualizations"
	@echo "  make clean-caches - Clear all cached data for fresh test"

gen-certs:
	@echo "Generating self-signed certificates for boring-registry with SANs..."
	@mkdir -p certs
	@echo "Creating OpenSSL configuration with Subject Alternative Names..."
	@printf '[req]\ndefault_bits = 2048\nprompt = no\ndefault_md = sha256\ndistinguished_name = dn\nreq_extensions = v3_req\nx509_extensions = v3_ca\n\n[dn]\nC=US\nST=State\nL=City\nO=Test\nCN=boring-registry\n\n[v3_req]\nsubjectAltName = @alt_names\n\n[v3_ca]\nsubjectAltName = @alt_names\nbasicConstraints = CA:TRUE\n\n[alt_names]\nDNS.1 = boring-registry\nDNS.2 = localhost\nIP.1 = 127.0.0.1\n' > certs/openssl.cnf
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout certs/boring-registry.key \
		-out certs/boring-registry.crt \
		-config certs/openssl.cnf
	@rm certs/openssl.cnf
	@echo ""
	@echo "Certificate generated"
	@openssl x509 -in certs/boring-registry.crt -noout -text | grep -A 3 "Subject Alternative Name" || echo "  (SANs are included in the certificate)"
	@echo ""
	@echo "Certificate expires:"
	@openssl x509 -in certs/boring-registry.crt -noout -dates
	@echo ""
	@echo "NOTE: Run 'make restart' to apply new certificates to running services"

up:
	docker compose up -d

restart:
	@echo "Restarting services to apply certificate changes..."
	docker compose down
	docker compose up -d
	@echo "Services restarted!"

bench-graphs:
	bash scripts/bench-with-graphs.sh

clean-caches:
	@echo "Clearing all caches (Layer 1 + Layer 2)..."
	@rm -rf ./.cache/tofu-providers/* ./.cache/tg-modules/* ./.data/minio/tofu-mirror/* 2>/dev/null || true
	@echo "Caches cleared!"
