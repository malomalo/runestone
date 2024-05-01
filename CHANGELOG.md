## Edge

New Features:
  - Or support! Queries like `"2 | two"` will now match both `"2"` and `"two"`

  - Only update indexes when necessary. If Runestone can't figure out if an index will change it will always be updated. You can define when an index should be updated when describing the attribute with an `on:` argument.

	 ```ruby
	 runestone do
		 attribute(:name_en, on: :name_changed?) { translate(name, to: :english)}
	 end
	 ```

Major Changes:

  - When delayed indexing runs it will only update the indexes that need updated

  - `reindex!` renamed to `reindex_runestones!` to prevent naming collisons and `reindex_runestones!` was added as a instance function on Models

Minor Changes:

  - New parser for queries

Bugfixes:

  - Fixed issue where delayed indexing wasn't updating the indexes
