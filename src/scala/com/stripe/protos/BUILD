load("@io_bazel_rules_scala//scala_proto:scala_proto.bzl", "scala_proto_library")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
    visibility = ["//visibility:public"],
    deps = [
        "@com_google_protobuf//:wrappers_proto",
    ],
)

scala_proto_library(
    name = "foo",
    visibility = ["//visibility:public"],
    deps = [":foo_proto"],
)