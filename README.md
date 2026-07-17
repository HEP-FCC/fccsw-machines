# fccsw-machines

Code for managing the FCC software group's servers.

## Layout

- [`web/`](web/) — PHP status page for the FCC Ironic and GPU machines, served at
  [https://fccsw.web.cern.ch/fccsw-machines](https://fccsw.web.cern.ch/fccsw-machines).
- [`scripts/`](scripts/) — operational scripts for the machines (e.g. `excubitor.sh`,
  a cooperative GPU lock manager for shared multi-GPU nodes, named after the
  *excubitores*, the Byzantine imperial palace guard — fitting for a script
  that stands watch over who holds which GPU).

See the README in each directory for details.
