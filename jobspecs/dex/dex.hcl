# Inspired from https://github.com/CarletonComputerScienceSociety/cloud-native/blob/main/nomad/traefik/traefik.hcl
job "dex" {
  region      = "global"
  datacenters = ["cwdc"]

  group "server" {
    count = 1

    volume "dexData" {
      type      = "csi"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
      source    = "dex-data"
    }

    network {
      port "http" {
        to = 5556
      }

    }

    service {
      name = "Dex-http-service"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dex.rule=Host(`dex.cwdc.cbains.ca`)",
        "traefik.http.routers.dex.tls.certresolver=letsencrypt",
        "traefik.http.routers.dex.entrypoints=https",
      ]
      check {
        name     = "alive"
        type     = "http"
        path     = "/dex/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "dex" {
      driver = "docker"

      config {
        image        = "docker.io/dexidp/dex:latest"
        args = ["serve", "/etc/dex.yml"]
        entrypoint = ["dex"]
        volumes = [
          "local/config.yml:/etc/dex.yml"
          ]
        ports = ["http"]
      }

      volume_mount {
        volume      = "dexData"
        destination = "/data"
      }

      template {
        data = <<EOF
issuer: https://dex.cwdc.cbains.ca/dex

storage:
  type: sqlite3
  config:
    file: /data/dex1.db


# Configuration for the HTTP endpoints.
web:
  http: 0.0.0.0:5556

# Configuration for dex appearance
# frontend:
#   issuer: dex
#   logoURL: theme/logo.png
#   dir: web/
#   theme: light

# Configuration for telemetry
telemetry:
  http: 0.0.0.0:5558


# Uncomment this block to enable configuration for the expiration time durations.
# Is possible to specify units using only s, m and h suffixes.
# expiry:
#   deviceRequests: "5m"
#   signingKeys: "6h"
#   idTokens: "24h"
#   refreshTokens:
#     reuseInterval: "3s"
#     validIfNotUsedFor: "2160h" # 90 days
#     absoluteLifetime: "3960h" # 165 days

# Options for controlling the logger.
# logger:
#   level: "debug"
#   format: "text" # can also be "json"

# Default values shown below
oauth2:
    # use ["code", "token", "id_token"] to enable implicit flow for web-only clients
#   responseTypes: [ "code" ] # also allowed are "token" and "id_token"
    # By default, Dex will ask for approval to share data with application
    # (approval for sharing data from connected IdP to Dex is separate process on IdP)
   skipApprovalScreen: false
    # If only one authentication method is enabled, the default behavior is to
    # go directly to it. For connected IdPs, this redirects the browser away
    # from application to upstream provider such as the Google login page
   alwaysShowLoginScreen: false
    # Uncomment the passwordConnector to use a specific connector for password grants
#   passwordConnector: local

# Instead of reading from an external storage, use this list of clients.
#
# If this option isn't chosen clients may be added through the gRPC API.
staticClients:
- id: example-app
  redirectURIs:
  - 'http://127.0.0.1:5555/callback'
  name: 'Example App'
  secret: ZXhhbXBsZS1hcHAtc2VjcmV0


connectors:
- type: mockCallback
  id: mock
  name: Example
- type: github
  id: github
  name: Github
  config:
    clientID: 4980b56ccdd3c7323ffd
    clientSecret: b0c1e28326f7fc69f8c8d83c1c5029271a79eea8
    redirectURI: https://dex.cwdc.cbains.ca/dex/callback
    loadAllGroups: true
    useLoginAsID: true


# - type: google
#   id: google
#   name: Google
#   config:
#     issuer: https://accounts.google.com
#     # Connector config values starting with a "$" will read from the environment.
#     clientID: $GOOGLE_CLIENT_ID
#     clientSecret: $GOOGLE_CLIENT_SECRET
#     redirectURI: https://dex.cwdc.cbains.ca/dex/callback
#     hostedDomains:
#     - $GOOGLE_HOSTED_DOMAIN

# Let dex keep a list of passwords which can be used to login to dex.
enablePasswordDB: true

# A static list of passwords to login the end user. By identifying here, dex
# won't look in its underlying storage for passwords.
#
# If this option isn't chosen users may be added through the gRPC API.
staticPasswords:
- email: "admin@example.com"
  # bcrypt hash of the string "password": $(echo password | htpasswd -BinC 10 admin | cut -d: -f2)
  hash: "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"
  username: "admin"
  userID: "08a8684b-db88-4b73-90a9-3cd1661f5466"
EOF

        destination = "local/config.yml"
        change_mode   = "restart"
      }
 
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
