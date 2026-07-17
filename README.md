# fccsw-machines

Code for managing the FCC software group's servers.

## Layout

- [`web/`](web/) — PHP status page for the FCC Ironic and GPU machines, served at
  [https://fccsw.web.cern.ch/fccsw-machines](https://fccsw.web.cern.ch/fccsw-machines).
- [`scripts/`](scripts/) — operational scripts for the machines, starting with a
  cooperative GPU lock manager for shared multi-GPU nodes, split into a user
  command (`excubitor`) and an admin command (`domestikos`) — named after the
  *excubitores*, the Byzantine palace guard, and the *Domestikos ton
  Exkoubiton*, the officer who commanded them.

See the README in each directory for details.
