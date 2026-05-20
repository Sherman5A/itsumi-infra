(define-module (holo create-directories)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix build utils)
  #:use-module (ice-9 posix)
  #:export (create-directory
            create-directory?
            create-directory-directory
            create-directory-user
            create-directory-mode))
            

(define-record-type* <create-directory
  create-directory make-create-directory
  create-directory?
  (directory create-directory-directory)
  (user      create-directory-user)
  (mode      create-directory-mode))

(define (create-directories-activation config)
  (with-imported-modules '((guix build utils)
                           (ice-9 posix))
    #~(begin
        (use-modules (guix build utils)
                     (ice-9 posix))

        (for-each
         (lambda (entry)
           (let* ((dir  #$(create-directory-directory entry))
                  (user #$(create-directory-user entry))
                  (mode #$(create-directory-mode entry))
                  (pw   (getpwnam user)))
             (mkdir-p dir)
             (chown dir (passwd:uid pw) (passwd:gid pw))
             (chmod dir mode)))
         '#$config))))

(define create-directories-service-type
  (service-type
   (name 'create-directories)
   (extensions
    (list (service-extension activation-service-type
                             create-directories-activation)))
   (default-value '())
   (description "Create directories with ownership and permissions.")))
