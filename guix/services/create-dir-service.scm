(define-module (services create-dir-service)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix build utils)
  #:export (create-directory
            create-directory?
            create-directory-directory
            create-directory-user
            create-directory-mode
            create-directories-service-type))
            
(define-record-type* <create-directory>
  create-directory make-create-directory
  create-directory?
  (directory create-directory-directory)
  (user      create-directory-user)
  (mode      create-directory-mode))

(define (create-directories-activation config)
  ;; 1. Convert the list of records into a simple, raw list of lists
  (let ((raw-data (map (lambda (entry)
                         (list (create-directory-directory entry)
                               (create-directory-user entry)
                               (create-directory-mode entry)))
                       config)))
    ;; 2. Pass only the raw strings/integers into the G-expression
    (with-imported-modules '((guix build utils))
      #~(begin
          (use-modules (guix build utils))
          (for-each
           (lambda (entry)
             (let* ((dir  (car entry))
                    (user (cadr entry))
                    (mode (caddr entry))
                    (pw   (getpwnam user)))
               (mkdir-p dir)
               (chown dir (passwd:uid pw) (passwd:gid pw))
               (chmod dir mode)))
           '#$raw-data)))))

(define create-directories-service-type
  (service-type
   (name 'create-directories)
   (extensions
    (list (service-extension activation-service-type
                             create-directories-activation)))
   (default-value '())
   (description "Create directories with ownership and permissions.")))
