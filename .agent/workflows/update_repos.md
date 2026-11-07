---
description: Update all repositories (root and sub-repos)
---

1. Clone anything missing + pull everything (jj-first)
   - `just jj::sync` (= `jj::bootstrap` + `jj::pull-all`)

2. Review the result
   - `just jj::status-all`
