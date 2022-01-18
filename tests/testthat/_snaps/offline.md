# Building Build Objects

    Code
      my_gcs_source
    Output
      ==CloudBuildSource==
      ==CloudBuildStorageSource==
      bucket:  gs://my-bucket 
      object:  my_code.tar.gz 

---

    Code
      my_repo_source
    Output
      ==CloudBuildSource==
      ==CloudBuildRepoSource==
      repoName:  https://my-repo.com 
      branchName:  master 

---

    Code
      bq
    Output
      ==CloudBuildObject==
      timeout:  10s 
      steps:
      - name: gcr.io/cloud-builders/docker
        id: Docker Version
        args: version
      - name: alpine
        id: Hello Cloud Build
        args:
        - echo
        - Hello Cloud Build
      - name: rocker/r-base
        id: Hello R
        args:
        - Rscript
        - -e
        - paste0('1 + 1 = ', 1+1)
      images:
       chr "gcr.io/my-project/demo"
      source:
      List of 1
       $ storageSource:List of 2
        ..$ bucket: chr "gs://my-bucket"
        ..$ object: chr "my_code.tar.gz"

---

    Code
      bq2
    Output
      ==CloudBuildObject==
      timeout:  11s 
      steps:
      - name: gcr.io/cloud-builders/docker
        id: Docker Version
        args: version
      - name: alpine
        id: Hello Cloud Build
        args:
        - echo
        - Hello Cloud Build
      - name: rocker/r-base
        id: Hello R
        args:
        - Rscript
        - -e
        - paste0('1 + 1 = ', 1+1)
      images:
       chr "gcr.io/my-project/demo"
      source:
      List of 1
       $ repoSource:List of 2
        ..$ repoName  : chr "https://my-repo.com"
        ..$ branchName: chr "master"

---

    Code
      run_yaml
    Output
      ==cloudRunnerYaml==
      steps:
      - name: gcr.io/cloud-builders/docker
        args:
        - build
        - -f
        - Dockerfile
        - --tag
        - gcr.io/my-project/my-image:latest
        - --tag
        - gcr.io/my-project/my-image:$BUILD_ID
        - '.'
        id: building image
        dir: deploy
      - name: gcr.io/cloud-builders/docker
        args:
        - push
        - gcr.io/my-project/my-image
        id: pushing image
        dir: deploy
      - name: gcr.io/cloud-builders/gcloud
        args:
        - beta
        - run
        - deploy
        - test1
        - --image
        - gcr.io/my-project/my-image
        dir: deploy
      images:
      - gcr.io/my-project/my-image

---

    Code
      scheduler$body
    Output
      [1] "eyJzdGVwcyI6W3sibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbImJ1aWxkIiwiLWYiLCJEb2NrZXJmaWxlIiwiLS10YWciLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZTpsYXRlc3QiLCItLXRhZyIsImdjci5pby9teS1wcm9qZWN0L215LWltYWdlOiRCVUlMRF9JRCIsIi4iXSwiaWQiOiJidWlsZGluZyBpbWFnZSIsImRpciI6ImRlcGxveSJ9LHsibmFtZSI6Imdjci5pby9jbG91ZC1idWlsZGVycy9kb2NrZXIiLCJhcmdzIjpbInB1c2giLCJnY3IuaW8vbXktcHJvamVjdC9teS1pbWFnZSJdLCJpZCI6InB1c2hpbmcgaW1hZ2UiLCJkaXIiOiJkZXBsb3kifSx7Im5hbWUiOiJnY3IuaW8vY2xvdWQtYnVpbGRlcnMvZ2Nsb3VkIiwiYXJncyI6WyJiZXRhIiwicnVuIiwiZGVwbG95IiwidGVzdDEiLCItLWltYWdlIiwiZ2NyLmlvL215LXByb2plY3QvbXktaW1hZ2UiXSwiZGlyIjoiZGVwbG95In1dLCJpbWFnZXMiOlsiZ2NyLmlvL215LXByb2plY3QvbXktaW1hZ2UiXX0="

---

    Code
      read_b
    Output
      ==CloudBuildObject==
      steps:
      - name: gcr.io/cloud-builders/docker
        args:
        - build
        - -f
        - Dockerfile
        - --tag
        - gcr.io/my-project/my-image:latest
        - --tag
        - gcr.io/my-project/my-image:$BUILD_ID
        - '.'
        id: building image
        dir: deploy
      - name: gcr.io/cloud-builders/docker
        args:
        - push
        - gcr.io/my-project/my-image
        id: pushing image
        dir: deploy
      - name: gcr.io/cloud-builders/gcloud
        args:
        - beta
        - run
        - deploy
        - test1
        - --image
        - gcr.io/my-project/my-image
        dir: deploy
      images:
       chr "gcr.io/my-project/my-image"

---

    Code
      build3
    Output
      ==CloudBuildObject==
      steps:
      - name: gcr.io/cloud-builders/docker
        id: Docker Version
        args: version
      - name: alpine
        id: Hello Cloud Build
        args:
        - echo
        - Hello Cloud Build
      - name: rocker/r-base
        id: Hello R
        args:
        - Rscript
        - -e
        - paste0('1 + 1 = ', 1+1)

---

    Code
      read_b2
    Output
      ==CloudBuildObject==
      steps:
      - name: gcr.io/cloud-builders/docker
        id: Docker Version
        args: version
      - name: alpine
        id: Hello Cloud Build
        args:
        - echo
        - Hello Cloud Build
      - name: rocker/r-base
        id: Hello R
        args:
        - Rscript
        - -e
        - paste0('1 + 1 = ', 1+1)

---

    Code
      eemail
    Output
      [1] "mmmmark-invoker@mark-edmondson-gde.iam.gserviceaccount.com"

---

    Code
      run_target
    Output
      ==CloudSchedulerHttpTarget==
      uri:  https://a-url.com 
      http method:  GET 
      oidcToken.serviceAccountEmail:  mmmark 
      oidcToken.audience:  https://a-url.com 

---

    Code
      pubsub_message
    Output
      [1] "{\"a\":[\"hello mum\"]}"

