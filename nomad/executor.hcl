# config.hcl
datacenters = ["dc1"]

executor_image = "docker.io/causelyai/executor:latest"
executor__cpu    = 4000
executor__memory = 8192
