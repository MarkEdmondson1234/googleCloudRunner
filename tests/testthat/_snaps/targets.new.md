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
        - list.files(recursive=TRUE);targets::tar_make(script = 'targets/_targets.R')
        id: target pipeline
      - name: gcr.io/google.com/cloudsdktool/cloud-sdk:alpine
        entrypoint: gsutil
        args:
        - -m cp -r /workspace/_targets ${_TARGET_BUCKET}
        id: Upload Artifacts this way as artifacts doesn't support folders
      timeout: 3600s
      substitutions:
        _TARGET_BUCKET: gs://mark-edmondson-public-files/cr_build_target_tests/_targets

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
       [2] "Step #2 - \"target pipeline\": [1] \"callr-client--dc4cc5e.so\" \"callr-env-505d2a671a51\"  "
       [3] "Step #2 - \"target pipeline\": [3] \"file505d3910ac70\"         \"file505d56f0d196\"        "
       [4] "Step #2 - \"target pipeline\": [5] \"targets/_targets.R\"       \"targets/mtcars.csv\"      "
       [5] "Step #2 - \"target pipeline\": • start target file1"                                         
       [6] "Step #2 - \"target pipeline\": • built target file1"                                         
       [7] "Step #2 - \"target pipeline\": • start target input1"                                        
       [8] "Step #2 - \"target pipeline\": • built target input1"                                        
       [9] "Step #2 - \"target pipeline\": • start target result1"                                       
      [10] "Step #2 - \"target pipeline\": • built target result1"                                       
      [11] "Step #2 - \"target pipeline\": • end pipeline"                                               
      [12] "Finished Step #2 - \"target pipeline\""                                                      

---

    Code
      logs_of_interest2
    Output
       [1] "Step #2 - \"target pipeline\": gcr.io/gcer-public/targets:latest"                            
       [2] "Step #2 - \"target pipeline\": [1] \"callr-client--dc4cc5e.so\" \"callr-env-505d2a671a51\"  "
       [3] "Step #2 - \"target pipeline\": [3] \"file505d3910ac70\"         \"file505d56f0d196\"        "
       [4] "Step #2 - \"target pipeline\": [5] \"targets/_targets.R\"       \"targets/mtcars.csv\"      "
       [5] "Step #2 - \"target pipeline\": • start target file1"                                         
       [6] "Step #2 - \"target pipeline\": • built target file1"                                         
       [7] "Step #2 - \"target pipeline\": • start target input1"                                        
       [8] "Step #2 - \"target pipeline\": • built target input1"                                        
       [9] "Step #2 - \"target pipeline\": • start target result1"                                       
      [10] "Step #2 - \"target pipeline\": • built target result1"                                       
      [11] "Step #2 - \"target pipeline\": • end pipeline"                                               
      [12] "Finished Step #2 - \"target pipeline\""                                                      

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
       [2] "Step #2 - \"target pipeline\": [1] \"callr-client--dc4cc5e.so\" \"callr-env-505d2a671a51\"  "
       [3] "Step #2 - \"target pipeline\": [3] \"file505d22bcf2a\"          \"file505d2ce54d25\"        "
       [4] "Step #2 - \"target pipeline\": [5] \"file505d3910ac70\"         \"file505d56f0d196\"        "
       [5] "Step #2 - \"target pipeline\": [7] \"file505d75a90a54\"         \"targets/_targets.R\"      "
       [6] "Step #2 - \"target pipeline\": [9] \"targets/mtcars.csv\"      "                             
       [7] "Step #2 - \"target pipeline\": • start target file1"                                         
       [8] "Step #2 - \"target pipeline\": • built target file1"                                         
       [9] "Step #2 - \"target pipeline\": • start target input1"                                        
      [10] "Step #2 - \"target pipeline\": • built target input1"                                        
      [11] "Step #2 - \"target pipeline\": • start target result1"                                       
      [12] "Step #2 - \"target pipeline\": • built target result1"                                       
      [13] "Step #2 - \"target pipeline\": • end pipeline"                                               
      [14] "Finished Step #2 - \"target pipeline\""                                                      

