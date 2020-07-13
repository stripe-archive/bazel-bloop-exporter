load(
    "@io_bazel_rules_scala//scala:scala.bzl",
    upstream_scala_binary = "scala_binary",
    upstream_scala_doc = "scala_doc",
    upstream_scala_library = "scala_library",
    upstream_scala_library_suite = "scala_library_suite",
    upstream_scala_macro_library = "scala_macro_library",
    upstream_scala_repl = "scala_repl",
    upstream_scala_test = "scala_test",
    upstream_scala_test_suite = "scala_test_suite",
)

load("//bloop:bloop.bzl", "bloop_target")

_fatal_errors = ["-Xfatal-warnings"]
def _init_scalac_options_pair():
    loose = [
        "-deprecation",  # Emit warning and location for usages of deprecated APIs.
        "-encoding",
        "utf-8",  # Specify character encoding used by source files.
        "-explaintypes",  # Explain type errors in more detail.
        "-feature",  # Emit warning and location for usages of features that should be imported explicitly.
        "-language:existentials",  # Existential types (besides wildcard types) can be written and inferred
        "-language:experimental.macros",  # Allow macro definition (besides implementation and application)
        "-language:higherKinds",  # Allow higher-kinded types
        "-language:implicitConversions",  # Allow definition of implicit functions called views
        "-Xfuture",  # Turn on future language features.
        "-Ypartial-unification",  # Enable partial unification in type constructor inference
        "-Ywarn-extra-implicit",  # Warn when more than one implicit parameter section is defined.
    ]
    strict = loose[:]
    strict.extend([
        "-deprecation:false",  # Stops emitting deprecation warnings since they would be fatals in this mode
        "-Ywarn-value-discard",
        # Enable all the xlint options here:
        # https://docs.scala-lang.org/overviews/compiler-options/index.html#Warning_Settings
        "-Xlint:_",
        # Then disable the ones we don't want for now
        "-Xlint:-adapted-args",  # Warn if an argument list is modified to match the receiver.
        "-Xlint:-unused",
        # "-Ywarn-unused:imports",  # Warn if an import selector is not referenced.
        # "-Ywarn-unused:implicits",  # Warn if an implicit parameter is unused.
        # "-Ywarn-unused:locals",  # Warn if a local definition is unused.
        # "-Ywarn-unused:params",  # Warn if a value parameter is unused.
        # "-Ywarn-unused:patvars",  # Warn if a variable bound in a pattern is unused.
        # "-Ywarn-unused:privates",  # Warn if a private member is unused.
        "-Ywarn-numeric-widen",  # Warn when numerics are widened.
        # "-Ywarn-dead-code",  # Warn when dead code is identified.
        "-unchecked",  # Enable additional warnings where generated code depends on assumptions.
    ])
    return (loose, strict)

(_loose_scalacopts, _strict_scalacopts) = _init_scalac_options_pair()

_default_plugins = []

def _apply_default_args(kwargs):
    if "scalacopts" not in kwargs:
        kwargs["scalacopts"] = _strict_scalacopts + _fatal_errors

    if "plugins" not in kwargs:
        kwargs["plugins"] = _default_plugins

    return kwargs

def scala_binary(**kwargs):
    new_kwargs = _apply_default_args(kwargs)
    upstream_scala_binary(**new_kwargs)
    bloop_target(**new_kwargs)


def scala_library(**kwargs):
    new_kwargs = _apply_default_args(kwargs)
    upstream_scala_library(**new_kwargs)
    bloop_target(**new_kwargs)

def scala_library_suite(**kwargs):
    upstream_scala_library_suite(**kwargs)

def scala_macro_library(**kwargs):
    upstream_scala_macro_library(**kwargs)

def scala_test(**kwargs):
    new_kwargs = _apply_default_args(kwargs)
    upstream_scala_test(**new_kwargs)
    bloop_target(**new_kwargs)

def scala_test_suite(**kwargs):
    upstream_scala_test_suite(**kwargs)

def scala_repl(**kwargs):
    upstream_scala_repl(**kwargs)

def scala_doc(**kwargs):
    upstream_scala_doc(**kwargs)