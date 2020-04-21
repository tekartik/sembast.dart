# Some implementation details

## Cooperator

Sembast uses what I call a cooperator. It will pause (awaiting) for 100 microseconds every 4 ms
for every heavy algorithm (sorting, filtering).

This was done when testing on flutter with 10K+ records. On some devices, the UI
was blocked when sorting and filtering was done.

It is not perfect but running in a separate isolate would have impacted performance
a lot so it is partial solution for cooperating in a single-thread world.