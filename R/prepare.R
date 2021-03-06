
#' Get package data
#'
#' Parse and evaluate code from a package, and store it in an
#' environment, so that we can access it later without parsing it again.
#'
#' We need to evaluate code to get the functions, which might require
#' loading some packages, so we perform all this in a separate R process,
#' using the `callr` package.
#'
#' While we are at it, we also check the imports of the package,
#' and return where each function was imported from.
#'
#' @param path package root
#' @param targets character vector, function call targets to find
#' @return Named list with components:
#'   - `name` is the package name.
#'   - `version` is the vesion of the package.
#'   - `targets` is a character vector, the names of the environments where
#'     each target was found.
#'   - `functions` is a list of functions, with source references.
#'   - `exports` is a character vector of exported objects.
#'   - `s3_methods` is a character vector of declared S3 methods.
#'   - `imports` is a named list of environment names, one for each import.
#'
#' @keywords internal
#' @importFrom callr r_vanilla
#' @export

extract_api <- function(path = ".", targets = character()) {

  r_vanilla(
    function(path, targets, sort_c) {
      options(keep.source = TRUE)
      pkgload::load_all(path, export_all = FALSE, helpers = FALSE)
      name <- pkgload::pkg_name(path)
      env <- pkgload::ns_env(name)

      all_names <- ls(env, all.names = TRUE)
      objects <- mget(all_names, env)

      functions <- Filter(is.function, objects)
      data <- Filter(Negate(is.function), objects)

      exports <- ls(env$.__NAMESPACE__.$exports, all.names = TRUE)

      s3_methods <- env$.__NAMESPACE__.$S3methods[, 3]

      imports <- eapply(
        pkgload::imports_env(name),
        function(x) environmentName(environment(x))
      )

      target_funcs <- mget(
        targets,
        envir = env,
        mode = "function",
        inherits = TRUE,
        ifnotfound = NA_character_
      )

      target_envs <- lapply(
        target_funcs,
        function(x) {
          if (identical(x, NA_character_)) {
            x
          } else if (is.primitive(x)) {
            "base"
          } else {
            environmentName(environment(x))
          }
        }
      )

      structure(
        list(
          name = name,
          version = pkgload::pkg_version(path),
          targets = target_envs,
          functions = functions,
          data = data,
          exports = sort_c(exports),
          s3_methods = sort_c(s3_methods),
          imports = imports
        ),
        class = "pkgapi"
      )
    },
    libpath = .libPaths(),
    repos = getOption("repos"),
    args = list(path = path, targets = targets, sort_c = sort_c)
  )
}
