# Multi-node Home Server Analysis

## Current State
- Inventory (`ansible/inventory/hosts`) lists `nas`, `pi5-1`, `pi5-2`, but the playbook (`ansible/site.yml`) targets only `nas` and applies every role there.
- Roles are tuned for a single NAS host: Consul config (`ansible/roles/consul/templates/consul.hcl.j2`) hardcodes `node_name = "nas"` and `server = true`; Nomad config (`ansible/roles/nomad/templates/nomad.hcl.j2`) also enables a server with `bootstrap_expect = 1` and defines many NAS-specific host volumes from `ansible/roles/nomad/defaults/main.yml`.
- Docker/HashiCorp apt repositories are pinned to `arch=amd64` (roles `docker`, `consul`, `nomad`), which will fail on the Pi 5 (arm64).
- Base role (`ansible/roles/base/tasks/main.yml`) creates NAS mount points (/fast, /bulk*, /archive, /data, /sys) and enables UFW; roles like `dnsmasq` and `samba` are only appropriate on the NAS.
- Nomad jobs (`nomad/jobs/*.nomad.hcl`) all use `datacenters = ["dc1"]`, have no constraints, and many assume the NAS IP/volumes (hardcoded 192.168.1.119 for Prometheus scrape targets, Immich Redis, Caddy upstreams, etc.). They can accidentally schedule onto Pi clients and would fail without the NAS volumes.

## Gaps/Risks for Pi Nodes
- No play to provision `pi5-*`; Docker and Nomad clients are missing.
- Consul/Nomad configurations are server-only and tied to the NAS hostname; clients cannot join cleanly.
- NAS-only volumes are baked into Ansible (directory creation, chowns) and Nomad host volumes; Pi nodes will not share this layout.
- UFW rules only open Nomad UI (4646) and Consul ports; multi-node Nomad requires 4647/4648 and clear client/server rules. Pi nodes should not expose dnsmasq/samba.
- Jobs default to NAS by assumption but lack constraints; service discovery addresses should replace hardcoded IPs where possible.

## Implementation Plan
1) Inventory & Variables  
   - Introduce groups such as `[nomad_server]` (nas) and `[nomad_clients]` (pi5-1, pi5-2) in `ansible/inventory/hosts`.  
   - Add `group_vars`/`host_vars` to define per-host volume roots, node names, and whether a node is a Nomad/Consul server or client. Keep NAS paths in `host_vars/nas.yml`; give Pi nodes lightweight defaults (only what's needed for Nomad client + Docker).  
   - Align datacenter naming (e.g., `home`) and reuse it in Nomad job specs to avoid `dc1`/`home` drift.

2) Role Adjustments  
   - Docker role: compute repo arch dynamically (`arm64` vs `amd64`) and use the correct Docker repo stanza for Pi.  
   - Consul role: parameterize `node_name`, `datacenter`, and server/client mode; add `retry_join` to point clients to the NAS server; keep UI only on the server. Ensure systemd override fits both modes.  
   - Nomad role: split server/client settings (server block only on NAS, clients join via `server_join`/`retry_join`); set `node_class` or `meta` for scheduling; make host volumes templated from per-node vars so Pi nodes do not create NAS-specific dirs.  
   - UFW rules: open Nomad RPC/Serf ports (4647/4648, plus 4646 as needed) between cluster members; keep dnsmasq/samba roles restricted to NAS and skip them for Pi groups.  
   - Base role: gate NAS-specific mount creation behind variables so Pi nodes are not forced to create unused paths.

3) Nomad Job Specs  
   - Add constraints/affinities to pin stateful jobs to the NAS (e.g., `constraint { attribute = "${node.class}" value = "nas" }`). Decide which system jobs (node-exporter, cadvisor, filebeat) should run on all nodes and adapt volumes accordingly.  
   - Replace hardcoded NAS IPs with Consul lookups or Nomad variables where feasible (Prometheus targets, Immich Redis/ML URLs, Caddy upstreams pointing to local services).  
   - Ensure `datacenters` match the configured Nomad datacenter (rename to `home` if that becomes the cluster setting).

4) Playbook & Tooling  
   - Update `ansible/site.yml` with separate plays: NAS (full stack) vs Nomad clients (base + docker + consul client + nomad client).  
   - Optionally add Make targets or documentation for running client-only provisioning (`ansible-playbook -l nomad_clients ...`) and for deploying jobs after the cluster converges.

5) Validation  
   - Run Ansible against NAS, then Pi group; confirm Nomad/Consul membership (`nomad node status`, `consul members`).  
   - Redeploy jobs and verify they land on NAS as intended; check exporters/log shippers where scheduled on Pi nodes.
