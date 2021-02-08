# availableSecrets works ok

    Code
      s_yaml
    Output
      ==cloudRunnerYaml==
      steps:
      - name: ubuntu
        args:
        - bash
        - -c
        - echo $$SECRET $$SECRET2
        secretEnv:
        - SECRET
        - SECRET2
      logsBucket: gs://mark-edmondson-public-files
      availableSecrets:
        secretManager:
        - versionName: projects/mark-edmondson-gde/secrets/test_secret/versions/latest
          env: SECRET
        - versionName: projects/mark-edmondson-gde/secrets/test_secret_two/versions/latest
          env: SECRET2

