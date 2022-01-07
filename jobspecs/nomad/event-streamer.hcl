job "nomad-streamer" {
  datacenters = ["cwdc"]
  # 
  group "streamer" {
    count = 1

    network {
      port "nomad-auth-adder" {
        to = -1
      }
    }


    task "streamer" {
      resources {
        cpu    = 20
        memory = 50
      }
      env {
        NOMAD_ADDR = "http://${NOMAD_IP_nomad-auth-adder}:${NOMAD_PORT_nomad-auth-adder}"
      }
      driver = "docker"
      config {
        image = "ghcr.io/axsuul/nomad-event-streamer:latest"
      }

      vault {
        policies = ["nomad-event-streamer"]
      }
      template {
        #Add Discord URL
        data = <<EOF
        
{{ with secret "kv/projects/system/nomad-event-streamer" }}
{{ range $key, $pairs := .Data.data | explodeMap }}
{{ $key }}="{{ $pairs }}"
{{- end }}
{{ end}}
        EOF
        env         = true 
        destination = "vault.env"
        change_mode = "restart"
      }
    }

    task "nomad-header" {
      lifecycle {
          hook = "prestart"
          sidecar = "true"
      }
      resources {
        cpu    = 20
        memory = 10
      }
      env {
        PORT    = "${NOMAD_PORT_nomad-auth-adder}"
      }

      driver = "docker"

      config {
        image = "nginx"
        ports = ["nomad-auth-adder"]
        volumes = [
          "nomad.conf:/etc/nginx/nginx.conf"
        ]
      }

      vault {
        policies = ["nomad-event-streamer"]
      }

      template {
        data          = <<EOF
events {
    worker_connections  1024;
}

http   {
    upstream server_group   {
        {{ range service "http.nomad" }} 
        server {{ .Address }}:{{ .Port }};{{ end }}
    }

    server  {
        listen {{ env "PORT" }};
        location / {
            proxy_pass http://server_group;
            proxy_set_header X-Nomad-Token "{{ with secret "nomad/creds/mgmt"}}{{.Data.secret_id}}{{ end }}";
        }
    }
}
 
EOF
        destination   = "nomad.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
