(define-module (services oci-service)
  #:use-module (gnu services)
  #:use-module (gnu services containers)
  #:use-module (gnu packages)
  #:use-module (guix)
  #:export (oci-podman-configuration
      oci-provisioning-service))

(define oci-podman-configuration
  (oci-configuration
   (runtime 'podman)
   (user "oci-runner")))

(define tuwunel-registration-token
  #~(begin
      (or (getenv "GUIX_TUWUNEL_REGISTRATION_TOKEN") "")))

(define oci-provisioning-service
(simple-service
 'oci-provisioning
  oci-service-type
  (oci-extension
    (networks
     (list
      (oci-network-configuration (name "public"))
      (oci-network-configuration (name "static") (internal? #t))
      (oci-network-configuration (name "shiori"))
      (oci-network-configuration (name "linkding"))
      (oci-network-configuration (name "matrix"))
      (oci-network-configuration (name "minecraft"))))

    (containers
     (list
      ;; caddy-reverse-proxy
      (oci-container-configuration
       (image "docker.io/shermankw/itsumi-proxy:latest")
       (network "public,static,shiori,linkding,matrix,minecraft")
       (ports
        (list '("8080" . "80")
              '("8443" . "443")
	      '("8448" . "8448")
              '("25565" . "25565")
              '("25565" . "25565/udp")))
       (volumes
        '("/var/lib/caddy:/data")))

      (oci-container-configuration
       (image "docker.io/jevolk/tuwunel:v1.8.0")
       (network "matrix")
       (environment
	`(("TUWUNEL_PORT" . "8008")
	  ("TUWUNEL_DATABASE_PATH" . "/var/lib/tuwunel")
	  ("TUWUNEL_ALLOW_REGISTRATION" . "true")
	  ("TUWUNEL_REGISTRATION_TOKEN" . ,tuwunel-registration-token)
	  ("TUWUNEL_IP_SOURCE" . "rightmost_x_forwarded_for")))
       (volumes
	`("/var/lib/tuwunel:/var/lib/tuwunel")))

      ;; minecraft-server
      (oci-container-configuration
       (image "itzg/minecraft-server:stable-java25-alpine")
       (network "minecraft")
       (environment
        '(("EULA" . "TRUE")
          ("VERSION" . "26.1.2")
          ("TYPE" . "PAPER")
	  ("DIFFICULTY" . "2")
	  ("SERVER_NAME" . "DYCC - Vanilla")
          ("ONLINE_MODE" . "true")
          ("USE_AIKAR_FLAGS" . "true")
          ("USE_MEOWICE_FLAGS" . "true")
          ("DIFFICULTY" . "2")
          ("VIEW_DISTANCE" . "14")
          ("RCON_CMDS_STARTUP" . "
            gamerule fire_spread_radius_around_player 0
            scoreboard objectives add Deaths deathCount")
          ("ENFORCE_SECURE_PROFILE" . "false")
          ("ANNOUNCE_PLAYER_ACHIEVEMENTS" . "true")))
       (volumes
        '("/var/lib/minecraft:/data")))

      (oci-container-configuration
       (image "ghcr.io/go-shiori/shiori:v1.8.0-2-g585ea34")
       (network "shiori")
       (environment
        `(("SHIORI_HTTP_PORT" . "3001")
         ("SHIORI_DIR" . "/data")))
       (volumes `("/var/lib/shiori:/data")))

      (oci-container-configuration
       (image "sissbruecker/linkding:1.45.0-alpine")
       (network "linkding")
       (environment
        `(("LD_FAVICON_PROVIDER" . "https://icons.duckduckgo.com/ip3/{domain}.ico")))
       (volumes
        `("/var/lib/linkding:/etc/linkding/data")))

      ;; caddy-static
      (oci-container-configuration
       (image "shermankw/itsumi:main")
       (network "static")))))))
