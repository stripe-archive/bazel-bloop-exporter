load("//bloop/private:string_utils.bzl", "smash_label_to_basename")

BloopInfo = provider(fields = [
    "deps",
    "exports",
    "generatedjars",
    "needs_bloop_config",
    "num_src_files",
])

def _is_same_workspace(label, ctx):
    return label.workspace_name == "" or label.workspace_name == ctx.workspace_name

def _get_scala_version(target, ctx):
    return "2.12.11" # A hack :) FIXME by making this configurable.

_ignore_rule_srcs = {
    "proto_library": True,
    "thrift_library": True,
}

def generalized_bloop_info(target, ctx, parent_exports, parent_generatedjars):
    jars = []
    if JavaInfo in target:
        java_info = target[JavaInfo]
        jars = [dep for dep in java_info.transitive_runtime_deps.to_list() if dep.is_source]

    deps = parent_exports
    if hasattr(ctx.rule.attr, "deps"):
        deps += ctx.rule.attr.deps

    srcs = []
    if hasattr(ctx.rule.attr, "srcs") and not ctx.rule.kind in _ignore_rule_srcs:
        srcs = ctx.rule.attr.srcs

    scala = None
    if ctx.rule.kind.find("scala") != -1:
        version = _get_scala_version(target, ctx)

        scalacopts = []
        if hasattr(ctx.rule.attr, "scalacopts"):
            scalacopts = ctx.rule.attr.scalacopts

        plugins = []
        if hasattr(ctx.rule.attr, "plugins"):
            plugins = ctx.rule.attr.plugins

        scala = struct(
            version = version,
            scalacopts = depset(scalacopts),
            plugins = depset(plugins),
        )

    test = None
    if ctx.rule.attr.testonly:
        if ctx.rule.kind.find("java") != -1:
            test = "junit"
        else:
            test = ctx.rule.attr._scalatest.label.name

    return struct(
        jars = depset(jars),
        deps = depset([
            struct(
                name = smash_label_to_basename(t.label),
                num_src_files = t[BloopInfo].num_src_files,
                class_jars = t.files,
            )
            for t in deps
            if t[BloopInfo].needs_bloop_config
        ]),
        srcs = depset(srcs),
        scala = scala,
        test = test,
        generatedjars = parent_generatedjars,
    )

def _bloop_aspect_impl(target, ctx):
    parents = []
    exports = []

    if hasattr(ctx.rule.attr, "exports"):
        exports = ctx.rule.attr.exports + [
            t
            for export in ctx.rule.attr.exports
            if BloopInfo in export
            for t in export[BloopInfo].exports
        ]
        parents.extend(exports)
    if hasattr(ctx.rule.attr, "deps"):
        parents.extend(ctx.rule.attr.deps)
    if hasattr(ctx.rule.attr, "runtime_deps"):
        parents.extend(ctx.rule.attr.runtime_deps)

    parent_exports = [
        t
        for parent in parents
        if BloopInfo in parent
        for t in parent[BloopInfo].exports
    ]

    parents.extend(parent_exports)

    parentBloopInfo = [
        parent[BloopInfo].deps
        for parent in parents
        if BloopInfo in parent and parent[BloopInfo].needs_bloop_config
    ]

    parent_generatedjars_sourcejars = [
        t
        for parent in parents
        if BloopInfo in parent
        for t in parent[BloopInfo].generatedjars.sourcejars.to_list()
    ]

    parent_generatedjars_classjars = [
        t
        for parent in parents
        if BloopInfo in parent
        for t in parent[BloopInfo].generatedjars.classjars.to_list()
    ]
    parent_generatedjars = struct(
        sourcejars = depset(parent_generatedjars_sourcejars),
        classjars = depset(parent_generatedjars_classjars),
    )

    bloopy = generalized_bloop_info(target, ctx, parent_exports, parent_generatedjars)
    bloopies_depset_items = [(ctx.label, bloopy)]

    # We only want to index the target with source files in the current workspace
    needs_bloop_config = len(bloopy.srcs.to_list()) > 0 and _is_same_workspace(target.label, ctx)

    sourcejars = []
    classjars = []
    if not needs_bloop_config and JavaInfo in target:
        sourcejars = target[JavaInfo].transitive_source_jars.to_list()
        classjars = target[JavaInfo].transitive_runtime_deps.to_list()

    return [
        BloopInfo(
            deps = depset(
                direct = bloopies_depset_items,
                transitive = parentBloopInfo,
            ),
            exports = exports,
            generatedjars = struct(
                sourcejars = depset(sourcejars),
                classjars  = depset(classjars),
            ),
            needs_bloop_config = needs_bloop_config,
            num_src_files = len(bloopy.srcs.to_list()),
        )
    ]

bloop_aspect = aspect(
    implementation = _bloop_aspect_impl,
    attr_aspects = ["exports", "deps", "runtime_deps"],
)
