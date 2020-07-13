load("//bloop/private:bloop_target.bzl", "bloop_target_test")

def bloop_target(**kwargs):
    bloop_target_test(
        name = "%s.bloop" % kwargs["name"],
        target = kwargs["name"],
        tags = ["manual"],
    )
