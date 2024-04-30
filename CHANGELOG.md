## Edge

New Features:

Major Changes:
- When delayed indexing runs it will only update the indexes that need updated
- `reindex!` renamed to `reindex_runestones!` to prevent naming collisons and `reindex_runestones!` was added as a instance function on Models

Minor Changes:

Bugfixes:
- Fixed issue where delayed indexing wasn't updating the indexes
