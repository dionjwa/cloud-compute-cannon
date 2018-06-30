locals {
  # [server | gpu | cpu]
  # Basically, which stack should we use as the request server
  # Workers can also be servers
  server_suffix = "${var.servers_max > 0 ? "server" : "${var.workers_gpu_max > 0 ? "gpu" : "cpu" }" }"
}
