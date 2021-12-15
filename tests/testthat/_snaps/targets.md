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
        - gsutil mv ${_TARGET_BUCKET}/meta/artifacts- ${_TARGET_BUCKET}/artifacts/artifacts-
          || exit 0
        id: move old artifact files if present
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: bash
        args:
        - -c
        - mkdir /workspace/_targets && gsutil -m cp -r ${_TARGET_BUCKET}/meta/* /workspace/_targets/meta
          || exit 0
        id: get previous _targets metadata
      - name: gcr.io/gcer-public/targets
        args:
        - Rscript
        - -e
        - targets::tar_make(script = 'tests/targets/_targets.R')
        id: target pipeline
      timeout: 3600s
      substitutions:
        _TARGET_BUCKET: gs://mark-edmondson-public-files/cr_build_target_tests/_targets
      artifacts:
        objects:
          location: gs://mark-edmondson-public-files/cr_build_target_tests/_targets
          paths:
          - /workspace/_targets/**

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
      logs_of_interest1
    Output
       [1] "Step #2 - \"target pipeline\": gcr.io/gcer-public/targets:latest"                                                                                                                                                                              
       [2] "Step #2 - \"target pipeline\": Error: could not find file tests/targets/_targets.R. Main functions like tar_make() require a target script file (default: _targets.R) to define the pipeline. Functions tar_edit() and tar_script() can help. "
       [3] "Step #2 - \"target pipeline\": Backtrace:"                                                                                                                                                                                                     
       [4] "Step #2 - \"target pipeline\":     █"                                                                                                                                                                                                          
       [5] "Step #2 - \"target pipeline\":  1. └─targets::tar_make(script = \"tests/targets/_targets.R\")"                                                                                                                                                 
       [6] "Step #2 - \"target pipeline\":  2.   └─targets:::callr_outer(...)"                                                                                                                                                                             
       [7] "Step #2 - \"target pipeline\":  3.     └─targets:::tar_assert_script(script)"                                                                                                                                                                  
       [8] "Step #2 - \"target pipeline\":  4.       └─targets::tar_assert_path(script, msg)"                                                                                                                                                              
       [9] "Step #2 - \"target pipeline\":  5.         └─targets::tar_throw_validate(...)"                                                                                                                                                                 
      [10] "Step #2 - \"target pipeline\": Execution halted"                                                                                                                                                                                               
      [11] "Finished Step #2 - \"target pipeline\""                                                                                                                                                                                                        

---

    Code
      logs_of_interest2
    Output
       [1] "Step #2 - \"target pipeline\": gcr.io/gcer-public/targets:latest"                                                                                                                                                                              
       [2] "Step #2 - \"target pipeline\": Error: could not find file tests/targets/_targets.R. Main functions like tar_make() require a target script file (default: _targets.R) to define the pipeline. Functions tar_edit() and tar_script() can help. "
       [3] "Step #2 - \"target pipeline\": Backtrace:"                                                                                                                                                                                                     
       [4] "Step #2 - \"target pipeline\":     █"                                                                                                                                                                                                          
       [5] "Step #2 - \"target pipeline\":  1. └─targets::tar_make(script = \"tests/targets/_targets.R\")"                                                                                                                                                 
       [6] "Step #2 - \"target pipeline\":  2.   └─targets:::callr_outer(...)"                                                                                                                                                                             
       [7] "Step #2 - \"target pipeline\":  3.     └─targets:::tar_assert_script(script)"                                                                                                                                                                  
       [8] "Step #2 - \"target pipeline\":  4.       └─targets::tar_assert_path(script, msg)"                                                                                                                                                              
       [9] "Step #2 - \"target pipeline\":  5.         └─targets::tar_throw_validate(...)"                                                                                                                                                                 
      [10] "Step #2 - \"target pipeline\": Execution halted"                                                                                                                                                                                               
      [11] "Finished Step #2 - \"target pipeline\""                                                                                                                                                                                                        

---

    Code
      target_source2
    Output
      ==CloudBuildSource==
      ==CloudBuildStorageSource==
      bucket:  mark-edmondson-public-files 
      object:  cr_build_target_test_source.tar.gz 

---

    Code
      logs_of_interest3
    Output
       [1] "Step #2 - \"target pipeline\": gcr.io/gcer-public/targets:latest"                                                                                                                                                                              
       [2] "Step #2 - \"target pipeline\": Error: could not find file tests/targets/_targets.R. Main functions like tar_make() require a target script file (default: _targets.R) to define the pipeline. Functions tar_edit() and tar_script() can help. "
       [3] "Step #2 - \"target pipeline\": Backtrace:"                                                                                                                                                                                                     
       [4] "Step #2 - \"target pipeline\":     █"                                                                                                                                                                                                          
       [5] "Step #2 - \"target pipeline\":  1. └─targets::tar_make(script = \"tests/targets/_targets.R\")"                                                                                                                                                 
       [6] "Step #2 - \"target pipeline\":  2.   └─targets:::callr_outer(...)"                                                                                                                                                                             
       [7] "Step #2 - \"target pipeline\":  3.     └─targets:::tar_assert_script(script)"                                                                                                                                                                  
       [8] "Step #2 - \"target pipeline\":  4.       └─targets::tar_assert_path(script, msg)"                                                                                                                                                              
       [9] "Step #2 - \"target pipeline\":  5.         └─targets::tar_throw_validate(...)"                                                                                                                                                                 
      [10] "Step #2 - \"target pipeline\": Execution halted"                                                                                                                                                                                               
      [11] "Finished Step #2 - \"target pipeline\""                                                                                                                                                                                                        

