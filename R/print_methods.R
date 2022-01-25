#' @method print cr_buildtrigger_repo
#' @export
print.cr_buildtrigger_repo <- function(x, ...) {
  cat("==BuildTriggerRepo==\n")
  if (x$type == "github") {
    cat0("GitHub Repo:   ", paste0(x$repo$owner, "/", x$repo$name))
    if (!is.null(x$repo$push)) cat("--Push trigger\n") else cat("--Pull trigger\n")
    cat0("Branch: ", x$repo$push$branch)
    cat0("Tag:    ", x$repo$push$tag)
    cat0("Branch: ", x$repo$pull$branch)
    cat0("CommentControl: ", x$repo$pull$commentControl)
  } else {
    cat0("Source Repository: ", x$repo$repoName)
    cat0("Project:           ", x$repo$projectId)
    cat0("Tag:               ", x$repo$tagName)
    cat0("commitSha:         ", x$repo$commitSha)
    cat0("Branch:            ", x$repo$branchName)
    cat0("Directory:         ", x$repo$dir)
  }
}

#' @method print BuildTriggerResponse
#' @export
print.BuildTriggerResponse <- function(x, ...) {
  cat("==CloudBuildTriggerResponse==\n")
  cat0("id: ", x$id)
  cat0("name: ", x$name)
  cat0("createdTime: ", x$createTime)
  cat0("github.owner: ", x$github$owner)
  cat0("github.name: ", x$github$name)
  cat0("github.pullrequest.branch: ", x$github$pullRequest$branch)
  cat0("github.push.branch: ", x$github$push$branch)
  cat0("triggerTemplate.repoName: ", x$triggerTemplate$repoName)
  cat0("triggerTemplate.projectId: ", x$triggerTemplate$projectId)
  cat0("triggerTemplate.tagName: ", x$triggerTemplate$tagName)
  cat0("triggerTemplate.commitSha: ", x$triggerTemplate$commitSha)
  cat0("triggerTemplate.branchName: ", x$triggerTemplate$branchName)
  cat0("filename: ", x$filename)

  if (!is.null(x$build)) {
    print(x$build)
  }

  cat0("sourceToBuild.uri: ", x$sourceToBuild$uri)
  cat0("sourceToBuild.ref: ", x$sourceToBuild$ref)
  cat0("sourceToBuild.repoType:", x$sourceToBuild$repoType)

  if (!is.null(x$pubsubConfig)){
    print(x$pubsubConfig)
  }

}


#' @method print ServiceList
#' @export
print.ServiceList <- function(x, ...) {
  print(x)
}

#' @method print BuildOperationMetadata
#' @export
print.BuildOperationMetadata <- function(x, ...) {
  cat("==CloudBuildOperationMetadata==\n")
  cat0("buildId: ", x$metadata$build$id)
  cat0("status: ", x$metadata$build$status)
  cat0("logUrl: ", x$metadata$build$logUrl)
  if (!is.null(x$metadata$build$steps)) {
    cat("\n")
    print(cr_buildstep_df(x$metadata$build$steps))
  }
}

#' @method print gar_Build
#' @export
#' @importFrom yaml as.yaml
#' @importFrom utils str
print.gar_Build <- function(x, ...) {
  cat("==CloudBuildObject==\n")
  cat0("buildId: ", x$id)
  cat0("status: ", x$status)
  cat0("logUrl: ", x$logUrl)
  cat0("timeout: ", x$timeout)
  cat0("logsBucket: ", x$logsBucket)
  cat0("secrets: ", x$secrets)
  cat0("serviceAccount: ", x$serviceAccount)

  if (!is.null(x$tags)) {
    cat("tags:\n")
    lapply(x$tags, print)
  }

  if (!is.null(x$substitutions)) {
    cat("substitutions:\n")
    lapply(names(x$substitutions), function(y) cat(y, ": ", x$substitutions[[y]], "\n"))
  }

  if (!is.null(x$steps)) {
    cat("steps:\n")
    if (is.data.frame(x$steps)) {
      print(cr_buildstep_df(x$steps))
    } else {
      cat(as.yaml(x$steps))
    }
  }

  if (!is.null(x$images)) {
    cat("images:\n")
    str(x$images)
  }

  if (!is.null(x$source)) {
    cat("source:\n")
    str(x$source)
  }

  if (!is.null(x$artifacts)) {
    cat("artifacts:\n")
    str(x$artifacts[[1]])
  }
}

#' @method print cr_yaml
#' @export
#' @importFrom yaml as.yaml
print.cr_yaml <- function(x, ...) {
  cat("==cloudRunnerYaml==\n")
  cat(as.yaml(x))
}

#' @method print cr_buildstep
#' @export
#' @importFrom yaml as.yaml
print.cr_buildstep <- function(x, ...) {
  cat("==cloudRunnerBuildStep==\n")
  cat(as.yaml(x))
}



#' @method print gar_Service
#' @export
print.gar_Service <- function(x, ...) {
  cat("==CloudRunService==\n")
  cat0("name: ", x$metadata$name)
  cat0("location: ", x$metadata$labels$`cloud.googleapis.com/location`)
  cat0("lastModifier: ", x$metadata$annotations$`serving.knative.dev/lastModifier`)
  cat0("containers: ", x$spec$template$spec$containers$image)
  cat0("creationTimestamp: ", x$metadata$creationTimestamp)
  cat0("observedGeneration: ", x$status$observedGeneration)
  cat0("url: ", x$status$url)
}


#' @method print gar_scheduleJob
#' @export
print.gar_scheduleJob <- function(x, ...) {
  cat("==CloudScheduleJob==\n")
  cat0("name: ", x$name)
  cat0("state: ", x$state)
  cat0("httpTarget.uri: ", x$httpTarget$uri)
  cat0("httpTarget.httpMethod: ", x$httpTarget$httpMethod)
  cat0("pubsubTarget.topicName: ", x$pubsubTarget$topicName)
  cat0("pubsubTarget.data: ", x$pubsubTarget$data)
  if(!is.null(x$pubsubTarget$data)){
    cat0(
      "pubsubTarget.data (unencoded): ",
      googlePubsubR::msg_decode(x$pubsubTarget$data)
    )
  }
  cat0("userUpdateTime: ", x$userUpdateTime)
  cat0("schedule: ", x$schedule)
  cat0("scheduleTime:", x$scheduleTime)
  cat0("timezone: ", x$timeZone)
}

#' @method print gar_Source
#' @export
print.gar_Source <- function(x, ...) {
  cat("==CloudBuildSource==\n")
  if (!is.null(x$repoSource)) print.gar_RepoSource(x$repoSource)
  if (!is.null(x$storageSource)) print.gar_StorageSource(x$storageSource)
}

#' @method print gar_StorageSource
#' @export
print.gar_StorageSource <- function(x, ...) {
  cat("==CloudBuildStorageSource==\n")
  cat0("bucket: ", x$bucket)
  cat0("object: ", x$object)
  cat0("generation: ", x$generation)
}

#' @method print gar_RepoSource
#' @export
print.gar_RepoSource <- function(x, ...) {
  cat("==CloudBuildRepoSource==\n")
  cat0("repoName: ", x$repoName)
  cat0("branchName: ", x$branchName)
}

#' @method print gar_pubsubTarget
#' @export
print.gar_pubsubTarget <- function(x, ...) {
  cat("==CloudSchedulerPubSubTarget==\n")
  cat0("topicName: ", x$topicName)
  cat0("data: ", x$data)
  cat0("attributes: ", x$attributes)
}

#' @method print gar_pubsubConfig
#' @export
print.gar_pubsubConfig <- function(x, ...) {
  cat("==CloudBuildTriggerPubSubConfig==\n")
  cat0("topic: ", x$topic)
  cat0("serviceAccountEmail: ", x$serviceAccountEmail)
  cat0("subscription: ", x$subscription)
}

#' @method print gar_HttpTarget
#' @export
print.gar_HttpTarget <- function(x, ...) {
  cat("==CloudSchedulerHttpTarget==\n")
  cat0("uri: ", x$uri)
  cat0("http method: ", x$httpMethod)
  cat0("oidcToken.serviceAccountEmail: ", x$oidcToken$serviceAccountEmail)
  cat0("oidcToken.audience: ", x$oidcToken$audience)
}
