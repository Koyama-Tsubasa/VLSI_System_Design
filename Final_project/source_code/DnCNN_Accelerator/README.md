# DnCNN_Accelerator

* The DnCNN accelerators for different versions are in /hdl.
* The srams are in /sim/sram_model.
* You can do simulation and synthesis by the following steps as same as [hw3_spec](https://github.com/Koyama-Tsubasa/VLSI_System_Design/blob/main/Final_project/specs/hw3_spec_v5.pdf).  
> 1. cd sim/  
>    make sim  
> 2. cd syn/  
>    dc_shell -f synthesis.tcl  
> 3. cd sim/  
>    make syn  
* The reports will be generated as same as [hw3_spec](https://github.com/Koyama-Tsubasa/VLSI_System_Design/blob/main/Final_project/specs/hw3_spec_v5.pdf).
* If you don't want to run, you can just look at the [report](https://github.com/Koyama-Tsubasa/VLSI_System_Design/tree/main/Final_project/source_code/DnCNN_Accelerator/syn/report) already generated.
