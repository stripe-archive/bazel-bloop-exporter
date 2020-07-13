import json
import os
import subprocess
import sys

from optparse import OptionParser


def export_file_to_bloop(filename):
    # get the name of the file according to bazel
    command = [BAZEL_CMD, "query", filename]
    bazel_name = run_command(command)

    for i in iter(bazel_name.splitlines()):
        targets = query_all_targets_containing_file(i)

        # generate the provider files for all these targets
        provider_export_output = [
            run_command([BAZEL_CMD, "run", f"{t}.bloop"]) for t in targets.splitlines()
        ]
        if options.verbose:
            print(provider_export_output)
        # generate the bloop configuration files for all these targets
        generate_bloop_files_bfs(targets.splitlines())


def export_target_to_bloop(target):
    bloop_target_name = target + ".bloop"
    # generate the provider files for all these targets
    provider_export_output = run_command([BAZEL_CMD, "run", bloop_target_name])

    if options.verbose:
        print(provider_export_output)
        # generate the bloop configuration files for all these targets
        generate_bloop_files_bfs([target])


def generate_bloop_files_bfs(targets):
    queue = [get_provider_json_data(j[2:].replace("/", "_").replace(":", "_")) for j in targets]

    global CURR_NUM_OF_SOURCE_FILES
    visited = {}

    minimum_num_src_files = sum([len(data["srcs"]) for data in queue])

    if minimum_num_src_files > options.max_number_of_files:
        print(
            "ERROR: It is not possible to create the bloop configuration file for %s without exceeding the maximum number of source files allowed."
            % options.filename,
            file=sys.stderr,
        )
        print("Increase the limit using the --max_number_of_files flag.", file=sys.stderr)
        sys.exit(1)

    CURR_NUM_OF_SOURCE_FILES = minimum_num_src_files

    while len(queue) != 0:
        curr = queue.pop(0)

        if curr["label"] in visited:
            continue
        visited[curr["label"]] = True

        provider_filename = curr["label"] + ".json"

        if not options.override and os.path.exists(".bloop/" + provider_filename):
            print(
                "WARNING: .bloop/%s already exists. Skipping file creation for this target and all its dependencies."
                % provider_filename
            )
            print("Rerun script with --override option to force file generation.")
            continue

        with open(".bloop/" + provider_filename, "w") as outfile:
            project, deps_to_build = make_project_from_provider(curr)

            bloop_config = {
                "version": "1.4.0",
                "project": project,
            }
            json.dump(bloop_config, outfile, indent=4)

            for dep in deps_to_build:
                dep_json = get_provider_json_data(dep)
                CURR_NUM_OF_SOURCE_FILES += len(dep_json["srcs"])
                queue.append(dep_json)


def get_provider_json_data(label):
    provider_filename = label + ".json"

    data = None
    with open(".bloop/providers/" + provider_filename) as provider_file:
        data = json.load(provider_file)

    return data


def make_project_from_provider(data):
    deps_to_build, deps_classpath = select_deps_to_build(data["deps"])

    project = {
        "name": data["label"],
        "sources": data["srcs"],
        "directory": WORKSPACE_DIR
        + "/bazel-%s" % os.path.basename(WORKSPACE_DIR)
        + "/"
        + data["package"],
        "dependencies": deps_to_build,
        "classpath": data["class_jars"] + deps_classpath,
        "out": WORKSPACE_DIR + "/.bloop/" + data["label"],
        "classesDir": WORKSPACE_DIR + "/.bloop/" + data["label"] + "/classes",
        "resolution": {"modules": data["src_jars"],},
    }

    if data["scala"]:
        project["scala"] = data["scala"]

    if data["test"]:
        project["test"] = data["test"]

    return project, deps_to_build


def query_all_targets_containing_file(i):
    # find all targets containing this file in its srcs
    query_cmd = [BAZEL_CMD, "query", f'attr(\'srcs\', {i}, {i.partition(":")[0]}:*)"']
    targets = run_command(query_cmd)
    return targets


def run_command(cmd):
    proc = subprocess.run([" ".join(cmd)], shell=True, capture_output=True, check=True)
    return f"{proc.stdout.decode('utf-8')}\n{proc.stderr.decode('utf-8')}"


def select_deps_to_build(deps):
    # Subset Sum is a NP-complete problem. So we'll use the following strategy instead:
    # Generate the bloop configuration file for targets dependencies with the smallest number of source files,
    # until we reach our MAXNUM limit.
    deps_sorted_by_num_src_files = sorted(deps, key=lambda item: item["num_src_files"])
    deps_to_build = []
    deps_classpath = []
    NUM_SRC_FILES_AFTER_CALL = CURR_NUM_OF_SOURCE_FILES
    for dep in deps_sorted_by_num_src_files:
        if dep["num_src_files"] + NUM_SRC_FILES_AFTER_CALL <= options.max_number_of_files:
            NUM_SRC_FILES_AFTER_CALL += dep["num_src_files"]
            deps_to_build.append(dep["name"])
            deps_classpath.append(WORKSPACE_DIR + "/.bloop/%s/classes" % dep["name"])
        else:
            deps_classpath += dep["class_jars"]

    return deps_to_build, deps_classpath


parser = OptionParser()
parser.add_option(
    "-f", "--file", dest="filename", help="Export this FILE to Bloop", metavar="FILE"
)
parser.add_option(
    "-t", "--target", dest="target", help="Export this TARGET to Bloop", metavar="TARGET"
)
parser.add_option(
    "-b",
    "--bazel",
    metavar="BAZEL PATH",
    dest="bazel_path",
    default="bazel",
    help="Path to bazel binary. Defaults to bazel on the system path.",
)
parser.add_option(
    "-v",
    "--verbose",
    action="store_true",
    dest="verbose",
    default=False,
    help="Enable verbose logging.",
)
parser.add_option(
    "-o",
    "--override",
    action="store_true",
    dest="override",
    default=False,
    help="Override existing files",
)
parser.add_option(
    "-m",
    "--max_number_of_files",
    dest="max_number_of_files",
    help="MAXNUM of source files to export to Bloop in this command. Default is 5000.",
    metavar="MAXNUM",
    type=int,
    default=5000,
)

(options, args) = parser.parse_args()

if os.path.isfile("WORKSPACE"):
    WORKSPACE_DIR = os.getcwd()
else:
    print("ERROR: Please run command from WORKSPACE directory", file=sys.stderr)
    sys.exit(1)

BAZEL_CMD = options.bazel_path
CURR_NUM_OF_SOURCE_FILES = 0

if options.filename:
    export_file_to_bloop(options.filename)
elif options.target:
    export_target_to_bloop(options.target)
