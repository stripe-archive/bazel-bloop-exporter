# bazel-bloop exporter

**This is an unsupported project that we're releasing as a proof of concept.**

This proof of concept exports a [bazel](https://bazel.build/) project to [bloop](https://scalacenter.github.io/bloop/). The motivation is to allow the use of any tooling that already has a bloop integration, such as the [metals](https://scalameta.org/metals/) language server.

# Proof of concept

This repo contains a bazel project compiled with [rules_scala](https://github.com/bazelbuild/rules_scala). In `src` there are Scala, thrift, and protobuf files which can be compiled with bazel. The following command exports the `//src/scala/com/stripe/test:dummy_lib` target to bloop.

```sh
python3 bloop/scripts/gen_bloop.py -v -t //src/scala/com/stripe/test:dummy_lib
```

Which populates the `.bloop` folder with a bloop project config for the `dummy_lib` target. Now you can try opening the project with metals.

## Using in another project

The bazel rules that export this information can be imported into other bazel projects by adding something like this to the project's `WORKSPACE` file:

```python
git_repository(
    name = "bloop",
    commit = "710cdd154641bcfeeaf4a3a568a71b1cd82e43a2", //update as necessary 
    remote = "git@github.com:stripe-archive/bazel-bloop-exporter.git",
)
```

You can then create a `bloop_target` rule for each target that you want to export. It's recommended that you use the `tools/prelude` file to do this automatically by creating a set of macros like the ones below:

```python
load(
    "@io_bazel_rules_scala//scala:scala.bzl",
    upstream_scala_library = "scala_library",
    upstream_scala_binary = "scala_binary",
    upstream_scala_test = "scala_test"
)

load(
    "@bloop//bloop:bloop.bzl",
    "bloop_target",
)

def scala_library(**kwargs):
    bloop_target(**kwargs)
    upstream_scala_library(**kwargs)

def scala_binary(**kwargs):
    bloop_target(**kwargs)
    upstream_scala_binary(**kwargs)

def scala_test(**kwargs):
    bloop_target(**kwargs)
    upstream_scala_test(**kwargs)
```

You can now copy the `bloop/scripts/gen_bloop.py` script into your project and use it to generate bloop configs.

# Contributors
- Carmen Kwan
- Alex Beal
- Andy Scott
