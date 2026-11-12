## Input for aur-format

* `ascii.json`: info request, ASCII
* `utf-8.json`: info request, non-ASCII (pkgdesc)
* `search.jsonl`: JSON Lines format, one search request per line 
* `meta.json`: metadata archive, flat array of results
* `suggests.json`: suggest request, flat array of strings
* `depends.json`: dependency chain for ros-melodic-desktop
* `error.json`: request with error response
* `none.json`: search request with no results
* `empty.json`: empty JSON object (`{}`)
