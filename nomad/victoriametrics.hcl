# config.hcl
datacenters = ["dc1"]

victoriametrics_image = "victoriametrics/victoria-metrics:v1.128.0"
victoriametrics_cpu    = 4000
victoriametrics_memory = 8192

nfs_server = "nfs.example.com"
nfs_path = "/exported/path"