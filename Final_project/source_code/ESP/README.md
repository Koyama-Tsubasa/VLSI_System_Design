# ESP

* You have to first follow the steps mentioned in [lab_0](https://github.com/Koyama-Tsubasa/VLSI_System_Design/blob/main/Final_project/specs/lab0_spec_v2.pdf) and [midterm_project](https://github.com/Koyama-Tsubasa/VLSI_System_Design/blob/main/Final_project/specs/midterm_spec_v2.pdf) to set up the working folder, but do the following changes in step 5 in midterm.  
> * accelerator name: DnCNN  
> * unique accelerator id: 0AC  
> * accelerator register names:
> > -Conv1_scale  
> > -Conv2_scale  
> > -Conv3_scale  
> > -Conv4_scale  
> > -Conv5_scale  
> > -Conv6_scale  
> > -Conv7_scale  
* After setting up the working folder, you can replace the following directories to what we provided.
> * esp/accelerators/rtl/dncnn_rtl/hw/src/dncnn_rtl_basic_dma64 &rarr; [hw/](https://github.com/Koyama-Tsubasa/VLSI_System_Design/tree/main/Final_project/source_code/ESP/hw)
> * esp/accelerators/rtl/dncnn_rtl/sw/baremetal/dncnn.c &rarr; [sw/dncnn.c](https://github.com/Koyama-Tsubasa/VLSI_System_Design/blob/main/Final_project/source_code/ESP/sw/dncnn.c)
* At last, you have to put [patterns](https://github.com/Koyama-Tsubasa/VLSI_System_Design/tree/main/Final_project/source_code/patterns/esp) into esp/accelerators/rtl/dncnn_rtl/sw/baremetal/patterns/.
* After finishing these process, you can finally run the esp integration as same as the [midterm project](https://github.com/Koyama-Tsubasa/VLSI_System_Design/blob/main/Final_project/specs/midterm_spec_v2.pdf).

---
*  SW part in the sw_hw_cycle_comparrison, we already run the estimated_computaion_time outside the esp.
*  We run the estimated_model which the computation is same but the value is randomized ten times and calculate the average computation_time of this model.
*  After that, we calculate the pico second per cycle in ESP from the computation_time shows in ESP and the cycles calculated in simulation step.
*  From these values, we can estimate the total cycles of the model in software level.
