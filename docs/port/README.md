# Port history

These two documents are a record of how CADSys 4.2 became CADSysFNC. They are not
a user guide — for that, start at the [README](../../README.md), the
[migration guide](../migrating.md) and the [document format](../json-format.md).

They are kept, and kept in the repository rather than in a wiki, for one reason:
a good part of what is in them is still true of the code, and several of the
traps described are traps you can still fall into.

| | |
|---|---|
| [port-log.md](port-log.md) | The port itself, step by step: what each step changed, what it broke, and what only running the thing could find. The sections on the FNC backend's differences from GDI, on the overlay that replaced XOR rubber-banding, and on what FMX punishes that the VCL forgives, are the ones worth reading before you modify the drawing path. |
| [optimization-review.md](optimization-review.md) | A correctness and performance review of the **original** CADSys 4.2 sources, made before the port started. Many of its findings are fixed and pinned by `CADSys4.Tests.Regressions`; some are deliberately still open. Line numbers refer to the pre-port tree and no longer resolve. |
