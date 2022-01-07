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
        - mkdir -p /workspace/_targets && mkdir -p /workspace/_targets/meta && gsutil -m
          cp -r gs://mark-edmondson-public-files/cr_build_target_tests/_targets/meta /workspace/_targets
          || exit 0
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
        - date > buildtime.txt && gsutil cp buildtime.txt gs://mark-edmondson-public-files/cr_build_target_tests/_targets/buildtime.txt
          && gsutil -m cp -r /workspace/_targets gs://mark-edmondson-public-files/cr_build_target_tests
          && gsutil ls -r gs://mark-edmondson-public-files/cr_build_target_tests
        id: Upload Artifacts

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

# targets integrations - parallel builds

    Code
      result
    Output
      [1] "642.9 20.090625 33.9 10.4"

---

    Code
      bs
    Output
      [[1]]
      ==cloudRunnerBuildStep==
      name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
      entrypoint: bash
      args:
      - -c
      - mkdir -p /workspace/_targets && mkdir -p /workspace/_targets/meta && gsutil -m cp
        -r gs://mark-edmondson-public-files/cr_build_target_tests_multi/_targets/meta /workspace/_targets
        || exit 0
      id: get previous _targets metadata
      
      [[2]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('file1')
      id: file1
      waitFor:
      - get previous _targets metadata
      
      [[3]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('input1')
      id: input1
      waitFor:
      - file1
      
      [[4]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result1')
      id: result1
      waitFor:
      - input1
      
      [[5]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result2')
      id: result2
      waitFor:
      - input1
      
      [[6]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result3')
      id: result3
      waitFor:
      - input1
      
      [[7]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result4')
      id: result4
      waitFor:
      - input1
      
      [[8]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('merge1')
      id: merge1
      waitFor:
      - result1
      - result2
      - result3
      - result4
      
      [[9]]
      ==cloudRunnerBuildStep==
      name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
      entrypoint: bash
      args:
      - -c
      - date > buildtime.txt && gsutil cp buildtime.txt gs://mark-edmondson-public-files/cr_build_target_tests_multi/_targets/buildtime.txt
        && gsutil -m cp -r /workspace/_targets gs://mark-edmondson-public-files/cr_build_target_tests_multi
        && gsutil ls -r gs://mark-edmondson-public-files/cr_build_target_tests_multi
      id: Upload Artifacts
      waitFor:
      - merge1
      

---

    Code
      par_yaml
    Output
      ==cloudRunnerYaml==
      steps:
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: bash
        args:
        - -c
        - mkdir -p /workspace/_targets && mkdir -p /workspace/_targets/meta && gsutil -m
          cp -r gs://mark-edmondson-public-files/cr_build_target_tests_multi/_targets/meta
          /workspace/_targets || exit 0
        id: get previous _targets metadata
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('file1')
        id: file1
        waitFor:
        - get previous _targets metadata
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('input1')
        id: input1
        waitFor:
        - file1
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('result1')
        id: result1
        waitFor:
        - input1
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('result2')
        id: result2
        waitFor:
        - input1
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('result3')
        id: result3
        waitFor:
        - input1
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('result4')
        id: result4
        waitFor:
        - input1
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - |-
          targets::tar_config_set(script = 'targets/_targets.R')
          targets::tar_make('merge1')
        id: merge1
        waitFor:
        - result1
        - result2
        - result3
        - result4
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: bash
        args:
        - -c
        - date > buildtime.txt && gsutil cp buildtime.txt gs://mark-edmondson-public-files/cr_build_target_tests_multi/_targets/buildtime.txt
          && gsutil -m cp -r /workspace/_targets gs://mark-edmondson-public-files/cr_build_target_tests_multi
          && gsutil ls -r gs://mark-edmondson-public-files/cr_build_target_tests_multi
        id: Upload Artifacts
        waitFor:
        - merge1

---

    Code
      target_source
    Output
      ==CloudBuildSource==
      ==CloudBuildStorageSource==
      bucket:  mark-edmondson-public-files 
      object:  cr_build_target_test_source_multi.tar.gz 

---

    Code
      result2
    Output
      [1] "642.9 20.090625 33.9 10.4"

# targets integrations - selected deployments

    Code
      result
    Output
      [1] "642.9 20.090625 33.9 10.4"

---

    Code
      bs
    Output
      [[1]]
      ==cloudRunnerBuildStep==
      name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
      entrypoint: bash
      args:
      - -c
      - mkdir -p /workspace/_targets && mkdir -p /workspace/_targets/meta && gsutil -m cp
        -r gs://mark-edmondson-public-files/cr_build_target_tests_deployments/_targets/meta
        /workspace/_targets || exit 0
      id: get previous _targets metadata
      
      [[2]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('file1')
      id: file1
      waitFor:
      - get previous _targets metadata
      
      [[3]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('input1')
      id: input1
      waitFor:
      - file1
      
      [[4]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result1')
      id: result1
      waitFor:
      - input1
      
      [[5]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result2')
      id: result2
      waitFor:
      - input1
      
      [[6]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result3')
      id: result3
      waitFor:
      - input1
      
      [[7]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('result4')
      id: result4
      waitFor:
      - input1
      
      [[8]]
      ==cloudRunnerBuildStep==
      name: gcr.io/gcer-public/targets
      args:
      - Rscript
      - -e
      - |-
        targets::tar_config_set(script = 'targets/_targets.R')
        targets::tar_make('merge1')
      id: merge1
      waitFor:
      - result1
      - result2
      - result3
      - result4
      
      [[9]]
      ==cloudRunnerBuildStep==
      name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
      entrypoint: bash
      args:
      - -c
      - date > buildtime.txt && gsutil cp buildtime.txt gs://mark-edmondson-public-files/cr_build_target_tests_deployments/_targets/buildtime.txt
        && gsutil -m cp -r /workspace/_targets gs://mark-edmondson-public-files/cr_build_target_tests_deployments
        && gsutil ls -r gs://mark-edmondson-public-files/cr_build_target_tests_deployments
      id: Upload Artifacts
      waitFor:
      - merge1
      

---

    Code
      result2
    Output
      [1] "642.9 20.090625 33.9 10.4"

