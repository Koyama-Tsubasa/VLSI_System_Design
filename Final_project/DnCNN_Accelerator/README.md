# DnCNN_Accelerator

* The DnCNN accelerators for different versions are in /hdl.
* The srams are in /sim/sram_model.
* You can do simulation and synthesis by the following steps.
1 cd sim/
  make sim
2 cd syn/
  dc_shell -f synthesis.tcl
3 cd sim/
  make syn
