scala_library(
    name = "useless_lib",
    srcs = ["Useless.scala"],
    visibility = ["//visibility:public"],
)

scala_library(
    name = "dummy_lib",
    srcs = ["Dummy.scala"],
    visibility = ["//visibility:public"],
    exports = [":useless_lib"],
)

scala_test(
    name = "unit_test",
    srcs = ["UnitTest.scala"],
    deps = ["//src/thrift:shop"],
)