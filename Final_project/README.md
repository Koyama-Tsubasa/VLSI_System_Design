# Convolutional Neural Network Accelerator for Image Denoising

In this final project, we apply DNN accelerator on one of the fundamental challenges in the field of image processing and computer vision, image denoising on MNIST.
Image denoising is the technique which to estimate the original image by suppressing noise from a noise-contaminated version of the image.
This technique plays an important role in a wide range of applications such as image restoration, visual tracking, image registration, image segmentation, where obtaining the original image content is crucial for strong performance.

---
* There are four directories, 
**model_python**, 
[**DnCNN_Accelerator**](https://github.com/Koyama-Tsubasa/VLSI_System_Design/tree/main/Final_project/DnCNN_Accelerator), 
**ESP**, 
[**patterns**](https://github.com/Koyama-Tsubasa/VLSI_System_Design/tree/main/Final_project/patterns), 
and [**specs**](https://github.com/Koyama-Tsubasa/VLSI_System_Design/tree/main/Final_project/specs).  
* The folder **patterns** includes the pattern used in **DnCNN_Accelerator** and **ESP**.
* The folder **specs** includes some specs from the previous works.
* If you want to run the whole process from training model to ESP integration, please run in the following order.
* **model_Python** -> **DnCNN_Accelerator** -> **ESP**
