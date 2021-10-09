# Inspired from https://github.com/CarletonComputerScienceSociety/cloud-native/blob/main/nomad/traefik/traefik.hcl
job "traefik" {
  region      = "global"
  datacenters = ["cwdc"]
  type        = "service"
  #Ingress traffic is on this node
  constraint {    
    attribute = "${node.unique.name}"    
    value     = "nc-1"    
  }
  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      
      port "https" {
        static = 443
      }

      port "internal-secure" {
        static = 4443
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"
      
      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }
   #Hold the certs
   ephemeral_disk {
      migrate = true
      size    = 200
      sticky  = true
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.5.2"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/dynamic/:/etc/traefik/config/dynamic/"
        ]
      }

      template {
        data = <<EOF
# Allow backends to use self signed ssl certs (Needed for waypoint)
[serversTransport]
  insecureSkipVerify = true
[entryPoints]
    [entryPoints.http]
    address = ":80"
    [entryPoints.https]
    address = ":443"
    [entryPoints.internal-secure]
    address = ":4443"
    [entryPoints.traefik]
    address = ":8081"

[api]
    dashboard = true
    insecure  = true

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
      token   = "2aee6018-a15a-dfb8-faf0-dde87a7ce132"

[providers.file]
  directory = "/etc/traefik/config/dynamic"
  watch = true

[certificatesresolvers.letsencrypt.acme]
  email = "clarkbains@gmail.com"
  storage = "/alloc/data/acme.json"
  [certificatesresolvers.letsencrypt.acme.httpchallenge]
    entrypoint = "http"
EOF

        destination = "local/traefik.toml"
      }
     
      template {
        data = <<EOF
[http]
  [http.routers]
    [http.routers.redirecttohttps]
      entryPoints = ["http"]
      middlewares = ["httpsredirect"]
      rule = "HostRegexp(`{host:.+}`)"
      service = "noop"
    [http.routers.cephrouter]
      entryPoints = ["internal-secure"]
      rule = "Host(`ceph.cwdc.cbains.ca`)"
      service = "cephdash"
      [http.routers.cephrouter.tls]
        certresolver= "letsencrypt"
[tcp]
  [tcp.routers]
    [tcp.routers.waypoint-backend]
      entryPoints = ["https"]
      rule = "HostSNI(`waypoint3.cwdc.cbains.ca`)"
      service = "waypoint-backend"
      middlewares = ["test-auth"]
      [tcp.routers.waypoint-backend.tls]
        certresolver= "letsencrypt"
        #insecureSkipVerify = true
        [[tcp.routers.waypoint-backend.tls.domains]]
        main = "waypoint3.cwdc.cbains.ca"
        #passthrough=true

  [http.services]
    # noop service, the URL will be never called
    [http.services.noop.loadBalancer]
      [[http.services.noop.loadBalancer.servers]]
        url = "http://127.0.0.1"
    [http.services.cephdash.loadBalancer]
      [[http.services.cephdash.loadBalancer.servers]]
        url = "https://cm-1:8443"
  [tcp.services]      
    [tcp.services.waypoint-backend.loadBalancer]
      [[tcp.services.waypoint-backend.loadBalancer.servers]]
        address = "192.168.25.22:12345"
  [http.middlewares]
    [http.middlewares.httpsredirect.redirectScheme]
      scheme = "https"
  [tcp.middlewares]
    [tcp.middlewares.test-auth.forwardAuth]
    address = "https://auth-proxy.cbains.ca/"
EOF

        destination = "local/dynamic/dynamic.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
