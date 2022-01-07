job "waypoint-runner" {
  datacenters = ["cwdc"]

  group "runner" {
    count = 1
    volume "jobspecs" {
      type      = "csi"
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
      source    = "waypoint-js-data"
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }


    task "waypoint-runner" {
      driver = "docker"
      
      volume_mount {
        volume      = "jobspecs"
        destination = "/data"
        read_only   = false
      }
      resources {
        cpu    = 500
        memory = 1000
      }

      config {
        image = "hashicorp/waypoint:latest"
        args = ["runner",
			            "agent",
			            "-vv"
                ]
        network_mode = "host"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

 vault {        
      vault {        
 vault {        
        policies = ["waypoint-env"]
        change_mode   = "signal"        
        change_signal = "SIGUSR1"      
      }

      template {
        data = <<EOH
{{ with secret "kv/projects/system/waypoint" }}
{{ range $key, $pairs := .Data.data | explodeMap }}
{{ $key }}="{{ $pairs }}"
{{- end }}
{{ end}}

{{ range service "nomad" }}NOMAD_ADDR ="http://{{ .Address }}:{{ .Port }}"
{{ end }}
{{ range service "waypoint-api" }}WAYPOINT_SERVER_ADDR="{{ .Address }}:{{ .Port }}"
{{ end }}
WAYPOINT_SERVER_TLS="TRUE"
WAYPOINT_SERVER_TLS_SKIP_VERIFY="TRUE"
        EOH
        destination = "local/file.env"
        change_mode   = "restart"
        env         = true
        }
     


      }
  }
}
