""" Rules for organizing and compiling Metal. """

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")

MetalFilesInfo = provider(
    "Collects Metal files",
    fields = ["transitive_sources", "transitive_headers"],
)

def get_transitive_srcs(srcs, deps):
    """Obtain the source files for a target and its transitive dependencies.

    Args:
      srcs: a list of source files
      deps: a list of targets that are direct dependencies
    Returns:
      a collection of the transitive sources
    """
    return depset(
        srcs,
        transitive = [dep[MetalFilesInfo].transitive_sources for dep in deps],
    )

def get_transitive_hdrs(hdrs, deps):
    """Obtain the source files for a target and its transitive dependencies.

    Args:
      hdrs: a list of header files
      deps: a list of targets that are direct dependencies
    Returns:
      a collection of the transitive headers
    """
    return depset(
        hdrs,
        transitive = [dep[MetalFilesInfo].transitive_headers for dep in deps],
    )

def _metal_library_impl(ctx):
    trans_srcs = get_transitive_srcs(ctx.files.srcs, ctx.attr.deps)
    trans_hdrs = get_transitive_hdrs(ctx.files.hdrs, ctx.attr.deps)
    return [MetalFilesInfo(transitive_sources = trans_srcs, transitive_headers = trans_hdrs)]

metal_library = rule(
    implementation = _metal_library_impl,
    fragments = ["apple"],
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        {
            "srcs": attr.label_list(allow_files = [".metal", ".h", ".hpp"]),
            "hdrs": attr.label_list(allow_files = [".h", ".hpp"]),
            "deps": attr.label_list(),
        },
    ),
)

def _metal_binary_impl(ctx):
    metallib_file = ctx.actions.declare_file(ctx.label.name + ".metallib")
    trans_srcs = get_transitive_srcs(ctx.files.srcs, ctx.attr.deps)
    trans_hdrs = get_transitive_hdrs([], ctx.attr.deps)
    srcs_list = trans_srcs.to_list() + trans_hdrs.to_list()

    srcs_metal_list = [x for x in srcs_list if x.extension == "metal"]

    srcs_hdrs_list = [x for x in srcs_list if x.extension == "h" or x.extension == "hpp"]

    air_files = []

    for src_metal in srcs_metal_list:
        air_file = ctx.actions.declare_file(paths.replace_extension(src_metal.basename, ".air"))
        air_files.append(air_file)
        input_files = [src_metal] + [src_hdr for src_hdr in srcs_hdrs_list]

        args = ctx.actions.args()
        args.add("metal")
        args.add("-c")

        args.add("-o", air_file)
        args.add("-I./")  # Enable absolute paths
        args.add(src_metal.path)
        if ctx.var["COMPILATION_MODE"] == "dbg":
            args.add("-frecord-sources=flat")

        apple_support.run(
            actions = ctx.actions,
            xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
            apple_fragment = ctx.fragments.apple,
            inputs = input_files,
            outputs = [air_file],
            executable = "/usr/bin/xcrun",
            arguments = [args],
            mnemonic = "MetalCompile",
        )

    args = ctx.actions.args()
    args.add("metallib")
    args.add("-o", metallib_file)
    args.add_all(air_files)

    apple_support.run(
        actions = ctx.actions,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        apple_fragment = ctx.fragments.apple,
        inputs = air_files,
        outputs = [metallib_file],
        executable = "/usr/bin/xcrun",
        arguments = [args],
        mnemonic = "MetallibCompile",
    )

    return [DefaultInfo(files = depset([metallib_file]))]

metal_binary = rule(
    implementation = _metal_binary_impl,
    fragments = ["apple"],
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        {
            "srcs": attr.label_list(allow_files = [".metal", ".h", ".hpp"]),
            "deps": attr.label_list(),
        },
    ),
)
