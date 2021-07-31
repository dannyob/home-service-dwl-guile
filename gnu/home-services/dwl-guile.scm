; Defines the configuration records for dwl,
; as well as procedures for transforming the configuration
; into a format that can easily be parsed in C.
(define-module (gnu home-services dwl-guile)
               #:use-module (guix gexp)
               #:use-module (guix packages)
               #:use-module (srfi srfi-1)
               #:use-module (ice-9 match)
               #:use-module (gnu packages wm)
               #:use-module (gnu home-services)
               #:use-module (gnu packages admin) ; shepherd
               #:use-module (gnu home-services shells)
               #:use-module (gnu home-services shepherd)
               #:use-module (gnu services configuration)
               #:use-module (dwl-guile utils)
               #:use-module (dwl-guile patches)
               #:use-module (dwl-guile package)
               #:use-module (dwl-guile defaults)
               #:use-module (dwl-guile transforms)
               #:use-module (dwl-guile configuration)
               #:export (home-dwl-guile-service-type
                          home-dwl-guile-configuration)

               ; re-export configurations so that they are
               ; available in the home environment without
               ; having to manually import them.
               #:re-export (
                            dwl-key
                            dwl-button
                            dwl-config
                            dwl-rule
                            dwl-colors
                            dwl-layout
                            dwl-tag-keys
                            dwl-xkb-rule
                            dwl-monitor-rule

                            %patch-base
                            %patch-alpha
                            %patch-xwayland
                            %patch-smartborders

                            %layout-default
                            %layout-monocle
                            %layout-floating

                            %base-config-keys
                            %base-config-colors
                            %base-config-buttons
                            %base-config-layouts
                            %base-config-tag-keys
                            %base-config-rules
                            %base-config-xkb-rules
                            %base-config-monitor-rules))

; dwl service type configuration
(define-configuration
  home-dwl-guile-configuration
  (package
    (package dwl)
    "The dwl package to use. By default, this package will be
    automatically patches using the dwl-guile patch. You can
    find the base package definition for dwl in gnu/packages/wm.scm.

    If you want to use a custom dwl package where the dwl-guile patch
    has already been defined, set (guile-patch? #f) in dwl-guile configuration.")
  (tty-number
    (number 2)
    "Launch dwl on specified tty upon user login. Defaults to 2")
  (patches
    (list-of-local-files '())
    "Additional patch files to apply to dwl-guile")
  (guile-patch?
    (boolean #t)
    "If the dwl-guile patch should be applied to package. Defaults to #t")
  (config
    (dwl-config (dwl-config))
    "Custom dwl-guile configuration. Replaces config.h")
  (no-serialization))

(define (config->dwl-package config)
  (make-dwl-package (home-dwl-guile-configuration-package config)
                    (home-dwl-guile-configuration-patches config)
                    (home-dwl-guile-configuration-guile-patch? config)))

(define (home-dwl-guile-profile-service config)
  (list
    (config->dwl-package config)))

(define (home-dwl-guile-shepherd-service config)
  "Return a <shepherd-service> for the dwl-guile service"
  (list
    (shepherd-service
      (documentation "Run dwl-guile")
      (provision '(dwl-guile))
      ; No need to auto start. Enabling this option means that
      ; dwl will start every time you run `guix home reconfigure`.
      ; Instead, we start it manually whenever we login to the
      ; chosen tty.
      (auto-start? #f)
      (start
        #~(make-forkexec-constructor
            (list
              #$(file-append (config->dwl-package config) "/bin/dwl-guile")
              "-c"
              (string-append (getenv "HOME") "/.config/dwl/config.scm"))))
      (stop #~(make-kill-destructor)))))

(define (home-dwl-guile-run-on-tty-service config)
  (list
    (format #f "[ $(tty) = /dev/tty~a ] && herd start dwl-guile"
            (home-dwl-guile-configuration-tty-number config))))

(define (home-dwl-guile-on-change-service config)
  `(("files/config/dwl/config.scm"
     ,#~(system* #$(file-append shepherd "/bin/herd") "restart" "dwl-guile"))))

; TODO: Respect XDG configuration?
(define (home-dwl-guile-files-service config)
  `(("config/dwl/config.scm"
     ,(scheme-file
        "dwl-config.scm"
        #~(define config
            `(#$@(dwl-config->alist (home-dwl-guile-configuration-config config))))))))

(define home-dwl-guile-service-type
  (service-type
    (name 'home-dwl)
    (extensions
      (list
        (service-extension
          home-profile-service-type
          home-dwl-guile-profile-service)
        (service-extension
          home-files-service-type
          home-dwl-guile-files-service)
        (service-extension
          home-shepherd-service-type
          home-dwl-guile-shepherd-service)
        (service-extension
          home-shell-profile-service-type
          home-dwl-guile-run-on-tty-service)
        (service-extension
          home-run-on-change-service-type
          home-dwl-guile-on-change-service)))
    (compose concatenate)
    (default-value (home-dwl-guile-configuration))
    (description "Configure and install dwl guile")))
