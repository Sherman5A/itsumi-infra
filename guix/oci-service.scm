(define-module (oci-service)
  #:use-module (gnu services)
  #:use-module (gnu services docker)
  #:use-module (gnu services oci)
  #:use-module (gnu packages)
  #:use-module (guix))

(define oci-provisioning-service)
(simple-service 'oci-provisioning
  oci-service-type
  (oci-configuration
    (runtime "podman")
    (user "run")
    (runtime-extra-arguments `("--userns=auto")))
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
       (name "caddy-reverse-proxy")
       (build
        (oci-build-configuration
         (context "reverse-proxy")
         (dockerfile "Containerfile")))
       (restart-policy 'unless-stopped)
       (networks '("public" "static" "rimgo" "minecraft"))
       (ports
        '(("8080" . "80")
          ("8443" . "443")
          ("25565" . "25565")
          ("25565/udp" . "25565/udp")))
       (volumes
        '("/var/lib/caddy:/data")))

      ;; rimgo
      (oci-container-configuration
       (name "rimgo")
       (image "codeberg.org/rimgo/rimgo:1.4.2")
       (network "rimgo")
       (expose '("3000"))
       (environment
        '(("PRIVACY_NOT_COLLECTED" . "1")
          ("PRIVACY_COUNTRY" . "Germany")
          ("PRIVACY_PROVIDER" . "Hetzner")
          ("PRIVACY_CLOUDFLARE" . "0"))))

      ;; minecraft-server
      (oci-container-configuration
       (name "minecraft-server")
       (image "itzg/minecraft-server:stable-java25-alpine")
       (tty? #t)
       (stdin-open? #t)
       (network "minecraft")
       (expose '("25565"))
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
       (name "caddy-static")
       (image "shermankw/itsumi:main")
       (restart-policy 'unless-stopped)
       (network "static")
       (expose '("80")))))))
