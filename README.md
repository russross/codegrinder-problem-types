# CodeGrinder Problem Types

This checkout is the installation-local source of truth for problem type
metadata, canonical files, and container builds.

Layout:

- `types/TYPE/type.conf` defines the container, default resource limits, and
  action list for one problem type.
- `types/TYPE/files/` contains the canonical file tree uploaded for that type.
- `common/` contains shared files used through symlinks from type file trees.
- `containers/NAME/Dockerfile` contains container build definitions.
- `bin/` contains BusyBox-compatible deployment scripts.

Deploy actions and files:

```sh
bin/sync-actions
bin/sync-files
```

Deploy one type:

```sh
bin/sync-actions python3unittest
bin/sync-files python3unittest
```

Build containers:

```sh
bin/build-containers
bin/build-containers python rust
```

`types/cunittest/files/` was present in the old file tree without a matching
problem type/action definition in `setup/problemtypes.sql`, so it is preserved
as source material but skipped by the sync scripts until it gets a `type.conf`.
