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
      (oci-network-configuration (name "rimgo"))
      (oci-network-configuration (name "minecraft"))))

    (containers
     (list
      ;; caddy-reverse-proxy
      (oci-container-configuration
       (image "docker.io/shermankw/itsumi-proxy:latest")
       (network "public,static,shiori,rimgo,minecraft")
       (ports
        (list '("8080" . "80")
          '("8443" . "443")
          '("25565" . "25565")
          '("25565" . "25565/udp")))
       (volumes
        '("/var/lib/caddy:/data")))

      ;; rimgo
      (oci-container-configuration
       (image "codeberg.org/rimgo/rimgo:1.4.2")
       (network "rimgo")
       (environment
        '(("PRIVACY_NOT_COLLECTED" . "1")
          ("PRIVACY_COUNTRY" . "Germany")
          ("PRIVACY_PROVIDER" . "Hetzner")
          ("PRIVACY_CLOUDFLARE" . "0"))))

      ;; minecraft-server
      (oci-container-configuration
       (image "itzg/minecraft-server:stable-java25-alpine")
       (network "minecraft")
       (environment
        '(("EULA" . "TRUE")
          ("VERSION" . "26.1")
          ("TYPE" . "PAPER")
          ("ONLINE_MODE" . "true")
          ("USE_AIKAR_FLAGS" . "true")
          ("USE_MEOWICE_FLAGS" . "true")
          ("DIFFICULTY" . "2")
          ("ENFORCE_SECURE_PROFILE" . "false")
          ("ANNOUNCE_PLAYER_ACHIEVEMENTS" . "true")))
       (volumes
        '("/var/lib/minecraft:/data")))

      (oci-container-configuration
       (image "ghcr.io/go-shiori/shiori:v1.8.0-2-g585ea34")
       (network "shiori")
       (environment
	`(("SHIORI_HTTP_PORT" . "3001")
	  ("SHIORI_DIR". "/data")))
       (volumes
	`("/var/lib/shiori:/data")
	 ("tmp:/tmp"))

      ;; caddy-static
      (oci-container-configuration
       (image "shermankw/itsumi:main")
       (network "static"))))))
