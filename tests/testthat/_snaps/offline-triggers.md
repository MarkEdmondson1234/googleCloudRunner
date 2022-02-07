# Render BuildStep objects

    [[1]]
    ==cloudRunnerBuildStep==
    name: alpine
    entrypoint: bash
    args:
    - -c
    - ls -la
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
    args:
    - gcloud
    - kms
    - decrypt
    - --ciphertext-file
    - secret.json.enc
    - --plaintext-file
    - secret.json
    - --location
    - global
    - --keyring
    - my_keyring
    - --key
    - my_key
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/docker
    args:
    - build
    - -f
    - Dockerfile
    - --tag
    - gcr.io/mark-edmondson-gde/my-image:$BRANCH_NAME
    - '.'
    id: building image
    
    [[2]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/docker
    args:
    - push
    - gcr.io/mark-edmondson-gde/my-image
    id: pushing image
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/docker
    args:
    - version
    id: Docker Version
    
    [[2]]
    ==cloudRunnerBuildStep==
    name: alpine
    args:
    - echo
    - Hello Cloud Build
    id: Hello Cloud Build
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/gcer-public/packagetools:latest
    args:
    - Rscript
    - -e
    - |
      message("cran mirror: ", getOption("repos"))
      remotes::install_deps(dependencies = TRUE)
      remotes::install_local()
      rcmdcheck::rcmdcheck(args = '--no-manual', error_on = 'warning')
    id: Devtools checks
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/gcer-public/packagetools:latest
    args:
    - Rscript
    - -e
    - |
      library(goodpractice)
      gp(checks = grep('(rcmdcheck|covr)', all_checks(), invert=TRUE, value=TRUE))
    id: Good Practices
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/blah
    args:
    - Rscript
    - -e
    - |
      library(goodpractice)
      gp(checks = grep('(rcmdcheck|covr)', all_checks(), invert=TRUE, value=TRUE))
    id: Good Practices
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/gcer-public/packagetools:latest
    args:
    - blah
    id: Good Practices
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/blah
    args:
    - Rscript
    - -e
    - |
      library(goodpractice)
      gp(checks = grep('(rcmdcheck|covr)', all_checks(), invert=TRUE, value=TRUE))
    id: Good Practices
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/gcer-public/packagetools:latest
    args:
    - Rscript
    - -e
    - |
      library(goodpractice)
      gp(checks = grep('(rcmdcheck|covr)', all_checks(), invert=TRUE, value=TRUE))
    id: Good Practices
    dir: blah
    

---

    ==cloudRunnerYaml==
    steps:
    - name: gcr.io/cloud-builders/gcloud
      entrypoint: bash
      args:
      - -c
      - gcloud secrets versions access latest --secret=github-ssh --format='get(payload.data)'
        | tr '_-' '/+' | base64 -d > /root/.ssh/id_rsa
      id: git secret
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      entrypoint: bash
      args:
      - -c
      - |-
        chmod 600 /root/.ssh/id_rsa
        cat <<EOF >known_hosts
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
        EOF
        cat <<EOF >/root/.ssh/config
        Hostname github.com
        IdentityFile /root/.ssh/id_rsa
        EOF
        mv known_hosts /root/.ssh/known_hosts
        git config --global user.name "googleCloudRunner"
        git config --global user.email "cr_buildstep_gitsetup@googleCloudRunner.com"
      id: git setup script
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      args:
      - clone
      - git@github.com:github_name/repo_name
      volumes:
      - name: ssh
        path: /root/.ssh

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/gcloud
    entrypoint: bash
    args:
    - -c
    - gcloud secrets versions access latest --secret=my_secret --format='get(payload.data)'
      | tr '_-' '/+' | base64 -d > /root/.ssh/id_rsa
    id: git secret
    volumes:
    - name: ssh
      path: /root/.ssh
    
    [[2]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/git
    entrypoint: bash
    args:
    - -c
    - |-
      chmod 600 /root/.ssh/id_rsa
      cat <<EOF >known_hosts
      github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
      EOF
      cat <<EOF >/root/.ssh/config
      Hostname github.com
      IdentityFile /root/.ssh/id_rsa
      EOF
      mv known_hosts /root/.ssh/known_hosts
      git config --global user.name "googleCloudRunner"
      git config --global user.email "cr_buildstep_gitsetup@googleCloudRunner.com"
    id: git setup script
    volumes:
    - name: ssh
      path: /root/.ssh
    
    [[3]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/git
    args:
    - clone
    - git@github.com:$_GITHUB_REPO
    - repo
    id: clone to repo dir
    volumes:
    - name: ssh
      path: /root/.ssh
    
    [[4]]
    ==cloudRunnerBuildStep==
    name: gcr.io/gcer-public/packagetools:latest
    args:
    - Rscript
    - -e
    - |-
      devtools::install_deps(dependencies=TRUE)
      devtools::install_local()
      pkgdown::build_site()
    id: build pkgdown
    dir: repo
    
    [[5]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/git
    args:
    - add
    - --all
    dir: repo
    volumes:
    - name: ssh
      path: /root/.ssh
    
    [[6]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/git
    args:
    - commit
    - -a
    - -m
    - "[skip ci] Build website from commit ${COMMIT_SHA}: \n$(date +\"%Y%m%dT%H:%M:%S\")"
    dir: repo
    volumes:
    - name: ssh
      path: /root/.ssh
    
    [[7]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/git
    args:
    - status
    dir: repo
    volumes:
    - name: ssh
      path: /root/.ssh
    
    [[8]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/git
    args:
    - push
    dir: repo
    volumes:
    - name: ssh
      path: /root/.ssh
    

---

    $push
    $push$branch
    [1] ".*"
    
    
    $owner
    [1] "mark"
    
    $name
    [1] "repo"
    
    attr(,"class")
    [1] "GitHubEventsConfig" "list"              

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/gcer-public/packagetools:latest
    args:
    - Rscript
    - -e
    - |-
      devtools::install()
      pkgdown::build_site()
    

---

    ==cloudRunnerYaml==
    steps:
    - name: gcr.io/gcer-public/packagetools:master
      args:
      - Rscript
      - -e
      - |-
        httr::POST(paste0("$$_MAILGUN_URL","/messages"),
                   httr::authenticate("api", "$$_MAILGUN_KEY"),
                   encode = "form",
                   body = list(
                     from="googleCloudRunner@example.com",
                     to="x@x.me",
                     subject="Hello",
                     text="Hello from Cloud Build"
                   ))
      id: send mailgun
    substitutions:
      _MAILGUN_URL: blah
      _MAILGUN_KEY: poo

---

    ==cloudRunnerYaml==
    steps:
    - name: gcr.io/cloud-builders/gcloud
      entrypoint: bash
      args:
      - -c
      - gcloud secrets versions access latest --secret=my_github --format='get(payload.data)'
        | tr '_-' '/+' | base64 -d > /root/.ssh/id_rsa
      id: git secret
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      entrypoint: bash
      args:
      - -c
      - |-
        chmod 600 /root/.ssh/id_rsa
        cat <<EOF >known_hosts
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
        EOF
        cat <<EOF >/root/.ssh/config
        Hostname github.com
        IdentityFile /root/.ssh/id_rsa
        EOF
        mv known_hosts /root/.ssh/known_hosts
        git config --global user.name "googleCloudRunner"
        git config --global user.email "cr_buildstep_gitsetup@googleCloudRunner.com"
      id: git setup script
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      args:
      - clone
      - git@github.com:MarkEdmondson1234/googleCloudRunner
      - repo
      id: clone to repo dir
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/gcer-public/packagetools:latest
      args:
      - Rscript
      - -e
      - |-
        devtools::install_deps(dependencies=TRUE)
        devtools::install_local()
        pkgdown::build_site()
      id: build pkgdown
      dir: repo
    - name: gcr.io/cloud-builders/git
      args:
      - add
      - --all
      dir: repo
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      args:
      - commit
      - -a
      - -m
      - "[skip ci] Build website from commit ${COMMIT_SHA}: \n$(date +\"%Y%m%dT%H:%M:%S\")"
      dir: repo
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      args:
      - status
      dir: repo
      volumes:
      - name: ssh
        path: /root/.ssh
    - name: gcr.io/cloud-builders/git
      args:
      - push
      dir: repo
      volumes:
      - name: ssh
        path: /root/.ssh

---

    ==cloudRunnerYaml==
    steps:
    - name: gcr.io/gcer-public/packagetools:latest
      args:
      - Rscript
      - -e
      - |-
        message("cran mirror: ", getOption("repos"))
        remotes::install_deps(dependencies = TRUE)
        rcmdcheck::rcmdcheck(args = "--no-manual", error_on = "warning")
      env:
      - NOT_CRAN=true
    - name: gcr.io/gcer-public/packagetools:latest
      args:
      - Rscript
      - -e
      - |-
        remotes::install_deps(dependencies = TRUE)
        remotes::install_local()
        cv <- covr::package_coverage()
        up <- covr::codecov(coverage = cv,
                      commit = "$COMMIT_SHA", branch = "$BRANCH_NAME",
                      quiet = FALSE)
        up
        if (!up$uploaded) stop("Error uploading codecov reports")
      env:
      - NOT_CRAN=true
      - CODECOV_TOKEN=$_CODECOV_TOKEN
      - CI=true
      - GCB_PROJECT_ID=$PROJECT_ID
      - GCB_BUILD_ID=$BUILD_ID
      - GCB_COMMIT_SHA=$COMMIT_SHA
      - GCB_REPO_NAME=$REPO_NAME
      - GCB_BRANCH_NAME=$BRANCH_NAME
      - GCB_TAG_NAME=$TAG_NAME
      - GCB_HEAD_BRANCH=$_HEAD_BRANCH
      - GCB_BASE_BRANCH=$_BASE_BRANCH
      - GCB_HEAD_REPO_URL=$_HEAD_REPO_URL
      - GCB_PR_NUMBER=$_PR_NUMBER

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: technosophos/slack-notify
    env:
    - SLACK_WEBHOOK=$_SLACK_WEBHOOK
    - SLACK_MESSAGE='hello'
    - SLACK_TITLE='CloudBuild - $BUILD_ID'
    - SLACK_COLOR='#efefef'
    - SLACK_USERNAME='googleCloudRunnerBot'
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/cloud-builders/gcloud
    entrypoint: bash
    args:
    - -c
    - gcloud secrets versions access latest --secret=my_secret  > secret.json
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/kaniko-project/executor:v1.6.0-debug
    args:
    - -f
    - Dockerfile
    - --destination
    - gcr.io/test-project/my-image:latest
    - --context=dir:///workspace/
    - --cache=true
    
    [[2]]
    ==cloudRunnerBuildStep==
    name: gcr.io/kaniko-project/executor:v1.6.0-debug
    args:
    - -f
    - Dockerfile
    - --destination
    - gcr.io/test-project/my-image:$BUILD_ID
    - --context=dir:///workspace/
    - --cache=true
    

---

    ==BuildTriggerRepo==
    GitHub Repo:    MarkEdmondson1234/googleCloudRunner 
    --Push trigger
    Branch:  .* 

---

    ==BuildTriggerRepo==
    Source Repository:  github_markedmondson1234_googlecloudrunner 
    Project:            my-project 
    Branch:             .* 

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
    args:
    - ls
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
    entrypoint: bq
    args:
    - ls
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:latest
    entrypoint: kubectl
    args:
    - ls
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
    entrypoint: gsutil
    args:
    - cp
    - gs://my-bucket/script.R
    - /workspace/script.R
    id: download r script
    
    [[2]]
    ==cloudRunnerBuildStep==
    name: rocker/r-base
    args:
    - Rscript
    - /workspace/script.R
    

---

    [[1]]
    ==cloudRunnerBuildStep==
    name: ubuntu
    args:
    - bash
    - -c
    - |-
      echo "
      server {
          listen       \$$$${PORT};
          server_name  localhost;
          location / {
              root   /usr/share/nginx/html;
              index  index.html index.htm;
          }
      }" > default.template
    
      cat <<EOF >Dockerfile
      FROM nginx
      COPY . /usr/share/nginx/html
      COPY default.template /etc/nginx/conf.d/default.template
      CMD envsubst < /etc/nginx/conf.d/default.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'
      EOF
    
      cat default.template
      cat Dockerfile
    id: setup nginx
    dir: folder
    

---

    ==CloudSchedulerPubSubTarget==
    topicName:  projects/mark-edmondson-gde/topics/test-topic 
    data:  InByb2plY3RzL21hcmstZWRtb25kc29uLWdkZS90b3BpY3MvdGVzdC10b3BpYyI= 

---

    ==CloudBuildTriggerPubSubConfig==
    topic:  projects/mark-edmondson-gde/topics/test-topic 

