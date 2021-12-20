# targets integrations

    Code
      target_yaml
    Output
      ==cloudRunnerYaml==
      steps:
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: bash
        args:
        - -c
        - mkdir /workspace/_targets && mkdir /workspace/_targets/meta && gsutil -m cp -r
          ${_TARGET_BUCKET}/_targets/meta /workspace/_targets || exit 0
        id: get previous _targets metadata
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          list.files(recursive=TRUE)
          targets::tar_make(script = 'targets/_targets.R')
        id: target pipeline
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: bash
        args:
        - -c
        - date > buildtime.txt && gsutil cp buildtime.txt ${_TARGET_BUCKET}/_targets/buildtime.txt
        id: Ensure bucket/_targets/ always exists
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: bash
        args:
        - -c
        - gsutil -m cp -r /workspace/_targets ${_TARGET_BUCKET} && gsutil ls -r ${_TARGET_BUCKET}
        id: Upload Artifacts
      timeout: 3600s
      substitutions:
        _TARGET_BUCKET: gs://mark-edmondson-public-files/cr_build_target_tests

---

    Code
      result
    Output
      [1] 642.9

---

    Code
      target_source
    Output
      ==CloudBuildSource==
      ==CloudBuildStorageSource==
      bucket:  mark-edmondson-public-files 
      object:  cr_build_target_test_source.tar.gz 

---

    Code
      target_source2
    Output
      ==CloudBuildSource==
      ==CloudBuildStorageSource==
      bucket:  mark-edmondson-public-files 
      object:  cr_build_target_test_source.tar.gz 

---

