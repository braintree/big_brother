0.6.8:

- Enable active/passive mode, an optional `backend_mode: "active_passive"` configuration directive is added to the big brother cluster config.
  - Active/Passive nodes now take a `priority` field that is used to select the active backend for the cluster. 
  - The active backend for an active/passive cluster is the backend with the lowest priority and positive health response. Should two backends have the same priority, the lowest backend IP address is selected. If none of the backends is healthy, the last active node's health is updated to weight of 0 in ipvs.
