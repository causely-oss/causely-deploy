# config.hcl
datacenters = ["dc1"]

# token is preferably provided by $CAUSELY_GATEWAY_TOKEN
gateway_token = "your-gateway-token-here"

mediator_image   = "docker.io/causelyai/mediator:latest"
mediator_cpu    = 2000
mediator_memory = 1024

ml_image   = "docker.io/causelyai/ml:latest"
ml_cpu    = 4000
ml_memory = 8192

nfs_server = "nfs.example.com"
nfs_path = "/exported/path"
