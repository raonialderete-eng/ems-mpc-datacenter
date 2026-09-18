# SHA-256 of the lab bitstream (file not in git)

Intel Quartus time-limited Nios IP (OpenCore Plus) may restrict redistribution
of the compiled `.sof`. This tag therefore stores the hash, not the bitstream.

Lab platform: Terasic DE2-115, Cyclone IV E EP4CE115F29C7, Quartus Prime Lite 20.1.1.720.

If a `.sof` is present locally when hashing, record:

```
# run from the machine that holds the programmer file
sha256sum path/to/ems.sof
```

If a `.sof` is present locally, record its SHA-256 below. An empty digest means
no `.sof` was stored under `07_fpga/` when this file was written.

| File | SHA-256 | Notes |
|---|---|---|
| (none found under `07_fpga/` at 2026-09-18) | — | Rebuild with the Tcl/Verilog in this tree; do not treat SIL as the board. |
