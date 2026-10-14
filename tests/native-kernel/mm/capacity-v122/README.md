# Native PDP-6 MM descriptor capacity boundary v122

Runs production `mm_pdp6.s` using p10run PDP-6 emulation. Includes v120
pressure/reclaim cases, then checks a complete, sorted 32-descriptor table
rejects additional allocation without mutation; reduction to 31 descriptors
permits an interior one-word no-reclaim insertion (count 32), and freeing
that inserted descriptor restores count 31 with no external callbacks.

This is a synthetic capacity boundary regression, not a measured occupancy
profile or a complete boot. Loadable modules are excluded until KA10/v1.1.
