.PHONY: default help ssh ping run check run-samba run-postgres run-grafana run-caddy run-node-exporter run-cadvisor run-prometheus check-env check-envsubst run-postgres-exporter run-elasticsearch run-kibana run-filebeat run-snmp-exporter run-qbittorrent

SHELL := /bin/bash

ENV_FILE ?= .env
ANSIBLE_PLAYBOOK := ansible/site.yml
INVENTORY := ansible/inventory/hosts

default: help

# Helpers
check-env:
	@[ -f $(ENV_FILE) ] || (echo "Error: $(ENV_FILE) not found!" && exit 1)

check-envsubst:
	@command -v envsubst >/dev/null 2>&1 || { \
		echo "Error: envsubst not found. macOS: brew install gettext && brew link --force gettext"; exit 1; }

ssh: check-env
	@bash -lc 'set -a; source $(ENV_FILE); set +a; \
		ssh -i $$KEY $$USER@$$HOST'

# Ansible
ping: check-env
	@bash -lc 'set -a; source $(ENV_FILE); set +a; \
		ansible -i $(INVENTORY) nas -m ping -u $$USER --private-key $$KEY'

run: check-env
	@bash -lc 'set -a; source $(ENV_FILE); set +a; \
		ANSIBLE_PRIVATE_KEY_FILE=$$KEY ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK)'

run-samba: check-env
	@bash -lc 'set -a; source $(ENV_FILE); set +a; \
		ANSIBLE_PRIVATE_KEY_FILE=$$KEY ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --tags samba'

check: check-env
	@bash -lc 'set -a; source $(ENV_FILE); set +a; \
		ANSIBLE_PRIVATE_KEY_FILE=$$KEY ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --check --diff'

# Nomad
run-postgres:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/postgres.nomad.hcl | nomad job run -'

run-grafana:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/grafana.nomad.hcl | nomad job run -'

run-caddy:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/caddy.nomad.hcl | nomad job run -'

run-node-exporter:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/node-exporter.nomad.hcl | nomad job run -'

run-cadvisor:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/cadvisor.nomad.hcl | nomad job run -'

run-prometheus:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/prometheus.nomad.hcl | nomad job run -'

run-postgres-exporter:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/postgres-exporter.nomad.hcl | nomad job run -'

run-snmp-exporter:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/snmp-exporter.nomad.hcl | nomad job run -'

run-elasticsearch:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/elasticsearch.nomad.hcl | nomad job run -'

run-kibana:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/kibana.nomad.hcl | nomad job run -'

run-filebeat:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/filebeat.nomad.hcl | nomad job run -'

run-qbittorrent:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/qbittorrent.nomad.hcl | nomad job run -'

run-plex:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/plex.nomad.hcl | nomad job run -'

run-redis:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/redis.nomad.hcl | nomad job run -'

run-immich:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/immich.nomad.hcl | nomad job run -'

run-docker-registry:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/docker-registry.nomad.hcl | nomad job run -'

run-filebeat:
	@bash -c 'set -a && source .env && set +a && \
	envsubst < nomad/jobs/filebeat.nomad.hcl | nomad job run -'

help:
	@echo "Makefile commands:"
	@echo "  ping            - Ping the NAS server using Ansible"
	@echo "  check           - Check what changes would be made by the Ansible playbook"
	@echo "  check-env       - Check if the .env file exists"
	@echo "  check-envsubst  - Check if envsubst is installed"
	@echo "  run             - Run the Ansible playbook to configure the NAS server"
	@echo "  run-samba       - Run only the Samba configuration part of the Ansible playbook"
	@echo "  run-postgres    - Deploy or update the PostgreSQL Nomad job"
	@echo "  run-grafana     - Deploy or update the Grafana Nomad job"
	@echo "  run-caddy       - Deploy or update the Caddy Nomad job"
	@echo "  run-node-exporter - Deploy or update the Node Exporter Nomad job"
	@echo "  run-cadvisor    - Deploy or update the cAdvisor Nomad job"
	@echo "  run-prometheus  - Deploy or update the Prometheus Nomad job"
	@echo "  run-postgres-exporter - Deploy or update the PostgreSQL Exporter Nomad job"
	@echo "  run-snmp-exporter - Deploy or update the SNMP Exporter Nomad job"
	@echo "  run-elasticsearch - Deploy or update the Elasticsearch Nomad job"
	@echo "  run-kibana      - Deploy or update the Kibana Nomad job"
	@echo "  run-filebeat    - Deploy or update the Filebeat Nomad job"
	@echo "  run-qbittorrent - Deploy or update the qBittorrent Nomad job"
	@echo "  run-plex        - Deploy or update the Plex Nomad job"
	@echo "  run-redis       - Deploy or update the Redis Nomad job"
	@echo "  run-immich      - Deploy or update the Immich Nomad job"
	@echo "  run-docker-registry - Deploy or update the Docker Registry Nomad job"
	@echo "  run-filebeat    - Deploy or update the Filebeat Nomad job"
	@echo "  ssh             - SSH into the NAS server"
	@echo "  help            - Show this help message"
