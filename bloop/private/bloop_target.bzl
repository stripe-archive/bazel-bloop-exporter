load("//bloop/private:json_helper.bzl", "make_provider_json")
load("//bloop/private:bloop_aspect.bzl", "bloop_aspect", "BloopInfo")
load("//bloop/private:string_utils.bzl", "smash_label_to_basename")

_SCRIPT_TEMPLATE = """#!/usr/bin/env bash
set -e

RUNFILES_ROOT=$PWD
cd $BUILD_WORKSPACE_DIRECTORY
WORKSPACE_ROOT=$PWD
WORKSPACE_NAME="$(basename $PWD)"
mkdir -p .bloop/providers

# Copying bloop files...
{COPY_FILES}
"""

def _bloop_target_impl(ctx):
    all_files = []
    json_files = []
    caller_basename = smash_label_to_basename(ctx.attr.target.label)
    for (label, bloopy) in ctx.attr.target[BloopInfo].deps.to_list():
        (json_file, all_jar_files) = make_provider_json(ctx, caller_basename, label, bloopy)
        json_files.append(json_file)
        all_files.extend(all_jar_files)

    all_files.extend(ctx.files.bazelbuild_rules_scala_compiler_jars)
    all_files.extend(json_files)

    script = ctx.actions.declare_file(ctx.label.name)
    script_content = _SCRIPT_TEMPLATE.format(
        COPY_FILES = "\n".join([
            'sed -e "s?@@WORKSPACE_ROOT@@?$WORKSPACE_ROOT/?g" -e "s?@@WORKSPACE_NAME@@?$WORKSPACE_NAME/?g" -e "s?@@RUNFILES_ROOT@@?$RUNFILES_ROOT/?g" %s > .bloop/providers/%s' % (f.path, f.basename.replace(caller_basename + "_", "", 1))
            for f in json_files
        ]),
    )

    ctx.actions.write(script, script_content, is_executable = True)
    runfiles = ctx.runfiles(files = all_files)

    return [
      DefaultInfo(
          files = depset(all_files),
          executable = script,
          runfiles = runfiles,
      ),
    ]

bloop_target_test = rule(
    implementation = _bloop_target_impl,
    attrs = {
        "target": attr.label(
            providers = [],
            aspects = [bloop_aspect],
        ),
        "bazelbuild_rules_scala_compiler_jars": attr.label_list(
            default = [
                "@io_bazel_rules_scala_scala_compiler//jar:jar",
                "@io_bazel_rules_scala_scala_library//jar:jar",
                "@io_bazel_rules_scala_scala_reflect//jar:jar",
            ],
            mandatory = False,
            allow_files = True,
        ),
    },
    test = True,
)
