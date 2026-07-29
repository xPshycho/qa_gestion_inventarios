group "default" {
  targets = ["backend", "frontend"]
}

target "backend" {
  context    = "./backend"
  dockerfile = "Dockerfile"
}

target "frontend" {
  context    = "./frontend"
  dockerfile = "Dockerfile"
}
