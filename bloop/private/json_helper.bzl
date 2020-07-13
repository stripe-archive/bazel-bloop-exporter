load(
    "//bloop/private:string_utils.bzl",
    "smash_label_to_basename",
)

def _determine_path(path):
    (prefix, sep, suffix) = path.partition("/")
    if prefix == "bazel-out":
        return "@@WORKSPACE_ROOT@@/bazel-@@WORKSPACE_NAME@@/%s" % path
    elif prefix == "external":
        return "@@RUNFILES_ROOT@@/%s" % path
    fail("Unknown path prefix %s" % prefix)

def _create_scalac_configuration(ctx, bloopy):
    if not bloopy.scala:
        return [], [], None
    plugin_sourcejars = []
    plugin_classjars = []
    for plugin in bloopy.scala.plugins.to_list():
        for p in plugin.files.to_list():
            if p.path.endswith("sources.jar") or p.path.endswith(".srcjar"):
                plugin_sourcejars.append(p)
            else:
                plugin_classjars.append(p)
    plugins = [
        "-Xplugin:%s" % _determine_path(p.path)
        for p in plugin_classjars
    ]
    scalac_configuration = struct(
        organization = "org.scala-lang",
        name = "scala-compiler",
        version = bloopy.scala.version,
        jars = [
            _determine_path(j.path)
            for j in ctx.files.bazelbuild_rules_scala_compiler_jars
        ],
        options = bloopy.scala.scalacopts.to_list() + plugins,
    )

    return plugin_sourcejars, plugin_classjars, scalac_configuration

def _create_module_configuration(bloopy, plugin_sourcejars):
    all_modules = []
    if len(bloopy.generatedjars.sourcejars.to_list()) != 0:
        generated_sources_module = struct(
            organization = "workspace",
            name = "generated_source_files",
            version = "2.12.11",
            artifacts = [
                struct(
                    name = smash_label_to_basename(j.owner),
                    path = _determine_path(j.path),
                    classifier = "sources"
                )
                for j in bloopy.generatedjars.sourcejars.to_list()
            ],
        )
        all_modules.append(generated_sources_module)
    if len(plugin_sourcejars) != 0:
        plugin_module = struct(
            organization = "workspace",
            name = "scalac_plugin_files",
            version = "2.12.11",
            artifacts = [
                struct(
                    name = smash_label_to_basename(p.owner),
                    path = _determine_path(p.path),
                    classifier = "sources"
                )
                for p in plugin_sourcejars
            ],
        )
        all_modules.append(plugin_module)

    return all_modules

name_to_framework = {
    "junit": [
        "com.novocode.junit.JUnitFramework"
    ],
    "munit" : [
        "munit.Framework"
    ],
    "scalacheck" : [
        "org.scalacheck.ScalaCheckFramework"
    ],
    "scalatest" : [
        "org.scalatest.tools.Framework",
        "org.scalatest.tools.ScalaTestFramework"
    ],
    "specs2" : [
        "org.specs.runner.SpecsFramework",
        "org.specs2.runner.Specs2Framework",
        "org.specs2.runner.SpecsFramework",
    ],
    "utest" : [
        "utest.runner.Framework"
    ],
}

def _create_test_configuration(bloopy):
    test_config = struct(
        frameworks = [
            struct(
                names = name_to_framework[bloopy.test],
            )
        ],
        options = struct(
            excludes = [],
            arguments = [
            ],
        )
    )
    return test_config

def make_provider_json(ctx, caller_basename, label, bloopy):
    plugin_sourcejars, plugin_classjars, scalac_configuration = _create_scalac_configuration(ctx, bloopy)

    label_basename = smash_label_to_basename(label)
    json_file_name = "%s_%s.json" % (caller_basename, label_basename)
    json_file = ctx.actions.declare_file(json_file_name)

    json_body = struct(
        label = label_basename,
        package = label.package,
        srcs = [
            "@@WORKSPACE_ROOT@@/%s" % f.path
            for t in bloopy.srcs.to_list()
            for f in t.files.to_list()
        ],
        deps = [
            struct(
                name = t.name,
                num_src_files = t.num_src_files,
                class_jars = [
                    _determine_path(f.path)
                    for f in t.class_jars.to_list()
                ]
            )
            for t in bloopy.deps.to_list()
        ],
        src_jars = _create_module_configuration(bloopy, plugin_sourcejars),
        class_jars = [
            _determine_path(j.path)
            for j in depset(
                items = bloopy.jars.to_list() + plugin_classjars,
                transitive = [bloopy.generatedjars.classjars],
            ).to_list()
        ],
        scala = scalac_configuration,
        test = _create_test_configuration(bloopy) if bloopy.test else None,
    ).to_json()

    ctx.actions.write(
        output = json_file,
        content = json_body,
    )

    all_jar_files = []
    all_jar_files.extend(bloopy.jars.to_list())
    all_jar_files.extend(bloopy.generatedjars.classjars.to_list())
    all_jar_files.extend(bloopy.generatedjars.sourcejars.to_list())
    all_jar_files.extend(plugin_classjars)
    all_jar_files.extend(plugin_sourcejars)

    for d in bloopy.deps.to_list():
        all_jar_files.extend(d.class_jars.to_list())

    return (json_file, all_jar_files)
