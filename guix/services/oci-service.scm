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
      (oci-network-configuration (name "rimgo") (internal? #t))
      (oci-network-configuration (name "minecraft"))))

    (containers
     (list
      ;; caddy-reverse-proxy
      (oci-container-configuration
       (image "docker.io/shermankw/itsumi-proxy:latest")
       (network "public,static,rimgo,minecraft")
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
       (ports '(("3000". "3000")))
       (environment
        '(("PRIVACY_NOT_COLLECTED" . "1")
          ("PRIVACY_COUNTRY" . "Germany")
          ("PRIVACY_PROVIDER" . "Hetzner")
          ("PRIVACY_CLOUDFLARE" . "0"))))

      ;; minecraft-server
      (oci-container-configuration
       (image "itzg/minecraft-server:stable-java25-alpine")
       (network "minecraft")
       (ports '(("25565" . "25565")))
       (environment
        '(("EULA" . "TRUE")
          ("VERSION" . "1.20.4")
          ("TYPE" . "PAPER")
          ("ONLINE_MODE" . "true")
          ("USE_AIKAR_FLAGS" . "true")
          ("USE_MEOWICE_FLAGS" . "true")
          ("DIFFICULTY" . "2")
          ("ENFORCE_SECURE_PROFILE" . "false")
          ("ANNOUNCE_PLAYER_ACHIEVEMENTS" . "true")))
       (volumes
        '("/var/lib/minecraft:/data")))

      ;; caddy-static
      (oci-container-configuration
       (image "shermankw/itsumi:main")
       (network "static")
       (ports '(("3001" . "30001")))))))))
