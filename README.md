# Metal Rules for Bazel

Provides the following rules for organizing Metal builds:

  - `metal_library` for reusable targets, akin to `cc_library`. Can be depended on by `metal_binary` and `metal_library` targets. Can include `.h`, `.hpp` headers and `.metal` sources.
  - `metal_binary` for producing a final `.metallib` file to be loaded at runtime. Build structure-wise, it is  akin to `cc_binary`, the root of a Metal dependency graph. Can depend on `metal_library`. Can include `.h`, `.hpp` headers and `.metal` sources.

## Example

```python
# Produces the final executable
cc_binary(
    name = "app",
    srcs = [
        "vertex_types.h",
        "main1.cc",
    ],
    # Bundles shaders.metallib into a runfile for the executable
    data = [":shaders"],
)

# Produces shaders.metallib
metal_binary(
    name = "shaders",
    srcs = [
        "vertex_function.metal",
        "fragment_function.metal",
    ],
    deps = [":vertex_types"],
)

# A Metal library target usable by other Metal targets
metal_library(
    name = "vertex_types",
    hdrs = ["vertex_types.h"],
)
```
