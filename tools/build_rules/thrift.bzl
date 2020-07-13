load("@io_bazel_rules_scala//thrift:thrift.bzl", upstream_thrift_library = "thrift_library")

_default_absolute_prefixes = [
    "src/main/thrift",
    "src/main/scala",
    "test/scala",
    "src/thrift",
    "test/thrift",
]

def thrift_library(**kwargs):
    if "absolute_prefixes" not in kwargs:
        kwargs["absolute_prefixes"] = _default_absolute_prefixes

    upstream_thrift_library(**kwargs)
