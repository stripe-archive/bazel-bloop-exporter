load(
    "@rules_java//java:defs.bzl",
    upstream_java_binary = "java_binary",
    upstream_java_library = "java_library",
    upstream_java_test = "java_test",
)
load(
    "//bloop:bloop.bzl",
    "bloop_target",
)

def java_library(**kwargs):
    bloop_target(**kwargs)
    upstream_java_library(**kwargs)

def java_binary(**kwargs):
    bloop_target(**kwargs)
    upstream_java_binary(**kwargs)

def java_test(**kwargs):
    bloop_target(**kwargs)
    upstream_java_test(**kwargs)
