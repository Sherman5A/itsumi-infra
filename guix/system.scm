(use-modules (gnu)
             (gnu machine)
             (gnu machine hetzner)
             (services oci-service)
             (services create-dir-service)
             (gnu system accounts))
(use-service-modules networking ssh sysctl security dbus containers desktop)
(use-package-modules bootloaders ssh)

(define server-type "cx23")

(define %new-base-services
  (modify-services %base-services
    (guix-service-type config =>
      (guix-configuration (inherit config)
        (substitute-urls (append (list
          "https://cache-test.guix.moe"
          "https://cache-fi.guix.moe/"
          "https://nonguix-proxy.ditigal.xyz"
          )
          %default-substitute-urls))
        (authorized-keys (append (list
          (plain-file
            "non-guix.pub"
            "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))")
            (plain-file "guix-moe.pub" "(public-key (ecc (curve Ed25519) (q #552F670D5005D7EB6ACF05284A1066E52156B51D75DE3EBD3030CD046675D543#)))"))
          %default-authorized-guix-keys))))
    (sysctl-service-type config =>
     (sysctl-configuration
        (settings (append '(("net.ipv4.ip_forward" . "1"))
          %default-sysctl-settings))))
    ))

(define %system
  (operating-system
   (inherit (make-hetzner-os server-type))
   (host-name "myuri")
   (users (append (list (user-account
                (name "kraft")
                (comment "")
                (group "users")
                (supplementary-groups '("wheel" "cgroup"
                                        "audio" "video")))
                (user-account
                (name "podman-runner")
                (comment "")
		(group "users")
                (supplementary-groups '("cgroup"))))
               %base-user-accounts))
   (services
    (cons* (service dhcpcd-service-type
	     (dhcpcd-configuration))
           (service ntp-service-type)
	   (service dbus-root-service-type)
           (service elogind-service-type)
                  (service openssh-service-type
                      (openssh-configuration
                          (openssh openssh-sans-x)
                          (permit-root-login #t)
                          (password-authentication? #f)
                          (port-number 22)
                          (authorized-keys
                            `(("kraft", (local-file "/home/jake/.ssh/hetzner.pub"))))))
                  ;;(service fail2ban-service-type
                  ;;  (fail2ban-configuration
                  ;;    (extra-jails
                  ;;     (list
                  ;;      (fail2ban-jail-configuration
                  ;;        (name "sshd")
                  ;;        (enabled? #t))))))
                  (service nftables-service-type
                    (nftables-configuration
                      (ruleset (plain-file "nftables.rules" "
table inet filter {
    chain input {
        type filter hook input priority 0;

        # Allow established/related
        ct state established,related accept

        # Allow loopback
        iif lo accept

        # Allow incoming SSH on port 22
        tcp dport 22 accept

        # Allow HTTP and HTTPS
        tcp dport 8080 accept
        tcp dport 8443 accept

        # Allow Minecraft
        tcp dport 25565 accept

        # Drop everything else
        drop
    }
}

table inet nat {
    chain prerouting {
        type nat hook prerouting priority -100;

        # Forward 80 to 8080
        tcp dport 80 redirect to 8080

        # Forward 443 to 8443
        tcp dport 443 redirect to 8443
    }
}
"))))
    ;; (service iptables-service-type)
    (service rootless-podman-service-type
      (rootless-podman-configuration
        (subgids
          (list (subid-range (name "oci-runner"))))
        (subuids
         (list (subid-range (name "oci-runner"))))))
    (service iptables-service-type)
    (service create-directories-service-type
      (list
        (create-directory
           (directory "/var/lib/forgejo")
           (user "oci-runner")
           (mode #o755))
          (create-directory
           (directory "/var/lib/minecraft")
           (user "oci-runner")
           (mode #o755))
          (create-directory
           (directory "/var/lib/shiori")
           (user "oci-runner")
           (mode #o755))
          (create-directory
           (directory "/var/lib/caddy")
           (user "oci-runner")
           (mode #o755))))
    (service oci-service-type
      oci-podman-configuration
    )
    oci-provisioning-service
    %new-base-services))))
  
(list (machine
       (operating-system %system)
       (environment hetzner-environment-type)
       (configuration (hetzner-configuration
                       (server-type server-type)
                       (ssh-key "/home/jake/.ssh/hetzner-test")
                       (ssh-public-key "/home/jake/.ssh/hetnzer-test.pub")
                       (location "fsn1")))))
